from flask import Blueprint, request, jsonify, redirect
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Payment, PaymentItem, Appointment, Service, Patient
from utils import log_activity, generate_code, get_patient_id_from_user
from datetime import datetime
import hashlib
import hmac
import json
import requests
import uuid

payment_bp = Blueprint('payment', __name__)

# MOMO CONFIGURATION (SANDBOX)

MOMO_CONFIG = {
    'partner_code': 'MOMOBKUN20180529',
    'access_key': 'klm05TvNBzhg7h7j',
    'secret_key': 'at67qH6mk8w5Y1nAyMoYKMWACiEi2bsa',
    'endpoint': 'https://test-payment.momo.vn/v2/gateway/api/create',
    'redirect_url': 'http://localhost:5000/api/v1/payment/momo/callback',
    'ipn_url': 'http://localhost:5000/api/v1/payment/momo/ipn',
    'request_type': 'payWithATM'  
}

# CREATE PAYMENT

@payment_bp.route('/create', methods=['POST'])
@jwt_required()
def create_payment():
    """Tạo payment record cho appointment"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    if not patient_id:
        return jsonify({"msg": "Patient data not found"}), 403
    
    data = request.get_json()
    appointment_id = data.get('appointment_id')
    
    if not appointment_id:
        return jsonify({"msg": "appointment_id is required"}), 400
    
    # Kiểm tra appointment có thuộc patient này không
    appointment = Appointment.query.filter_by(id=appointment_id, patient_id=patient_id).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found"}), 404
    
    # Kiểm tra đã có payment chưa
    existing_payment = Payment.query.filter_by(appointment_id=appointment_id).first()
    if existing_payment and existing_payment.payment_status in ['completed', 'processing']:
        return jsonify({"msg": "Payment already exists for this appointment"}), 409
    
    # Lấy service để tính tổng tiền
    service = Service.query.get(appointment.service_id)
    if not service:
        return jsonify({"msg": "Service not found"}), 404
    
    total_amount = float(service.price)
    
    # Tạo payment record
    payment_code = generate_code(prefix='PAY', length=10)
    
    new_payment = Payment(
        payment_code=payment_code,
        appointment_id=appointment_id,
        patient_id=patient_id,
        amount=total_amount,
        payment_method=data.get('payment_method', 'momo'),
        payment_status='pending',
        description=f'Thanh toán khám bệnh - {appointment.appointment_code}'
    )
    
    try:
        db.session.add(new_payment)
        db.session.flush()
        
        # Tạo payment items
        payment_item = PaymentItem(
            payment_id=new_payment.id,
            service_id=service.id,
            description=service.name,
            quantity=1,
            unit_price=service.price,
            total_price=service.price
        )
        db.session.add(payment_item)
        
        db.session.commit()
        log_activity(user_id, "CREATE_PAYMENT", "payment", new_payment.id, 
                    f"Created payment: {payment_code}")
        
        return jsonify({
            "msg": "Payment created successfully",
            "payment_id": new_payment.id,
            "payment_code": payment_code,
            "amount": str(total_amount),
            "payment_method": new_payment.payment_method
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating payment: {str(e)}"}), 500

# =============================================
# MOMO PAYMENT INTEGRATION
# =============================================

def generate_momo_signature(raw_signature, secret_key):
    """Tạo HMAC SHA256 signature cho MoMo"""
    h = hmac.new(secret_key.encode(), raw_signature.encode(), hashlib.sha256)
    return h.hexdigest()

@payment_bp.route('/momo/create', methods=['POST'])
@jwt_required()
def create_momo_payment():
    """Khởi tạo thanh toán qua MoMo"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    data = request.get_json()
    payment_id = data.get('payment_id')
    
    if not payment_id:
        return jsonify({"msg": "payment_id is required"}), 400
    
    # Lấy thông tin payment
    payment = Payment.query.filter_by(id=payment_id, patient_id=patient_id).first()
    
    if not payment:
        return jsonify({"msg": "Payment not found"}), 404
    
    if payment.payment_status != 'pending':
        return jsonify({"msg": f"Payment status is {payment.payment_status}, cannot process"}), 400
    
    # Chuẩn bị dữ liệu cho MoMo
    order_id = payment.payment_code
    amount = str(int(float(payment.amount)))
    order_info = payment.description
    request_id = str(uuid.uuid4())
    
    # Tạo raw signature
    raw_signature = f"accessKey={MOMO_CONFIG['access_key']}&amount={amount}&extraData=&ipnUrl={MOMO_CONFIG['ipn_url']}&orderId={order_id}&orderInfo={order_info}&partnerCode={MOMO_CONFIG['partner_code']}&redirectUrl={MOMO_CONFIG['redirect_url']}&requestId={request_id}&requestType={MOMO_CONFIG['request_type']}"
    
    signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    # Dữ liệu gửi đến MoMo
    momo_data = {
        'partnerCode': MOMO_CONFIG['partner_code'],
        'accessKey': MOMO_CONFIG['access_key'],
        'requestId': request_id,
        'amount': amount,
        'orderId': order_id,
        'orderInfo': order_info,
        'redirectUrl': MOMO_CONFIG['redirect_url'],
        'ipnUrl': MOMO_CONFIG['ipn_url'],
        'extraData': '',
        'requestType': MOMO_CONFIG['request_type'],
        'signature': signature,
        'lang': 'vi'
    }
    
    try:
        # Gửi request đến MoMo
        response = requests.post(
            MOMO_CONFIG['endpoint'],
            json=momo_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        result = response.json()
        
        if result.get('resultCode') == 0:
            # Cập nhật payment status
            payment.payment_status = 'processing'
            payment.transaction_id = request_id
            db.session.commit()
            
            log_activity(user_id, "INIT_MOMO_PAYMENT", "payment", payment.id, 
                        f"Initiated MoMo payment for {order_id}")
            
            return jsonify({
                "msg": "MoMo payment initiated successfully",
                "payment_url": result.get('payUrl'),
                "qr_code_url": result.get('qrCodeUrl'),
                "deeplink": result.get('deeplink'),
                "request_id": request_id
            }), 200
        else:
            return jsonify({
                "msg": "Failed to initiate MoMo payment",
                "error": result.get('message'),
                "result_code": result.get('resultCode')
            }), 400
            
    except requests.exceptions.RequestException as e:
        return jsonify({"msg": f"Error connecting to MoMo: {str(e)}"}), 500
    except Exception as e:
        return jsonify({"msg": f"Error processing MoMo payment: {str(e)}"}), 500

@payment_bp.route('/momo/callback', methods=['GET'])
def momo_payment_callback():
    """Xử lý callback từ MoMo sau khi thanh toán"""
    # Lấy parameters từ MoMo
    partner_code = request.args.get('partnerCode')
    order_id = request.args.get('orderId')
    request_id = request.args.get('requestId')
    amount = request.args.get('amount')
    order_info = request.args.get('orderInfo')
    order_type = request.args.get('orderType')
    trans_id = request.args.get('transId')
    result_code = request.args.get('resultCode')
    message = request.args.get('message')
    pay_type = request.args.get('payType')
    response_time = request.args.get('responseTime')
    extra_data = request.args.get('extraData')
    signature = request.args.get('signature')
    
    # Tìm payment
    payment = Payment.query.filter_by(payment_code=order_id).first()
    
    if not payment:
        return redirect(f'http://localhost:3000/payment/failed?msg=Payment not found')
    
    # Verify signature
    raw_signature = f"accessKey={MOMO_CONFIG['access_key']}&amount={amount}&extraData={extra_data}&message={message}&orderId={order_id}&orderInfo={order_info}&orderType={order_type}&partnerCode={partner_code}&payType={pay_type}&requestId={request_id}&responseTime={response_time}&resultCode={result_code}&transId={trans_id}"
    
    expected_signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    if signature != expected_signature:
        return redirect(f'http://localhost:3000/payment/failed?msg=Invalid signature')
    
    # Cập nhật payment status
    if result_code == '0':
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = trans_id
        
        # Cập nhật appointment status thành confirmed
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        
        return redirect(f'http://localhost:3000/payment/success?payment_code={order_id}&trans_id={trans_id}')
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        
        return redirect(f'http://localhost:3000/payment/failed?msg={message}&code={result_code}')

@payment_bp.route('/momo/ipn', methods=['POST'])
def momo_payment_ipn():
    """Xử lý IPN (Instant Payment Notification) từ MoMo"""
    data = request.get_json()
    
    partner_code = data.get('partnerCode')
    order_id = data.get('orderId')
    request_id = data.get('requestId')
    amount = data.get('amount')
    order_info = data.get('orderInfo')
    order_type = data.get('orderType')
    trans_id = data.get('transId')
    result_code = data.get('resultCode')
    message = data.get('message')
    pay_type = data.get('payType')
    response_time = data.get('responseTime')
    extra_data = data.get('extraData', '')
    signature = data.get('signature')
    
    # Verify signature
    raw_signature = f"accessKey={MOMO_CONFIG['access_key']}&amount={amount}&extraData={extra_data}&message={message}&orderId={order_id}&orderInfo={order_info}&orderType={order_type}&partnerCode={partner_code}&payType={pay_type}&requestId={request_id}&responseTime={response_time}&resultCode={result_code}&transId={trans_id}"
    
    expected_signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    if signature != expected_signature:
        return jsonify({"resultCode": 97, "message": "Invalid signature"}), 400
    
    # Tìm payment
    payment = Payment.query.filter_by(payment_code=order_id).first()
    
    if not payment:
        return jsonify({"resultCode": 99, "message": "Payment not found"}), 404
    
    # Cập nhật payment status
    if result_code == 0:
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = trans_id
        
        # Cập nhật appointment status
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        
        return jsonify({"resultCode": 0, "message": "Success"}), 200
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        
        return jsonify({"resultCode": result_code, "message": message}), 200

# =============================================
# PAYMENT STATUS CHECK
# =============================================

@payment_bp.route('/check-status/<string:payment_code>', methods=['GET'])
@jwt_required()
def check_payment_status(payment_code):
    """Kiểm tra trạng thái thanh toán"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    payment = Payment.query.filter_by(payment_code=payment_code, patient_id=patient_id).first()
    
    if not payment:
        return jsonify({"msg": "Payment not found"}), 404
    
    return jsonify({
        "payment_code": payment.payment_code,
        "amount": str(payment.amount),
        "payment_method": payment.payment_method,
        "payment_status": payment.payment_status,
        "transaction_id": payment.transaction_id,
        "payment_date": payment.payment_date.strftime('%Y-%m-%d %H:%M:%S') if payment.payment_date else None,
        "created_at": payment.created_at.strftime('%Y-%m-%d %H:%M:%S')
    }), 200

# =============================================
# QUERY MOMO TRANSACTION STATUS
# =============================================

@payment_bp.route('/momo/query', methods=['POST'])
@jwt_required()
def query_momo_transaction():
    """Truy vấn trạng thái giao dịch MoMo"""
    user_id = get_jwt_identity()
    data = request.get_json()
    
    order_id = data.get('order_id')
    request_id = data.get('request_id')
    
    if not order_id:
        return jsonify({"msg": "order_id is required"}), 400
    
    # Tạo signature
    raw_signature = f"accessKey={MOMO_CONFIG['access_key']}&orderId={order_id}&partnerCode={MOMO_CONFIG['partner_code']}&requestId={request_id or str(uuid.uuid4())}"
    signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    query_data = {
        'partnerCode': MOMO_CONFIG['partner_code'],
        'accessKey': MOMO_CONFIG['access_key'],
        'requestId': request_id or str(uuid.uuid4()),
        'orderId': order_id,
        'signature': signature,
        'lang': 'vi'
    }
    
    try:
        response = requests.post(
            'https://test-payment.momo.vn/v2/gateway/api/query',
            json=query_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        result = response.json()
        
        # Cập nhật local payment status nếu cần
        if result.get('resultCode') == 0:
            payment = Payment.query.filter_by(payment_code=order_id).first()
            if payment:
                if result.get('message') == 'Giao dịch thành công.':
                    payment.payment_status = 'completed'
                    payment.payment_date = datetime.utcnow()
                    db.session.commit()
        
        return jsonify(result), 200
        
    except Exception as e:
        return jsonify({"msg": f"Error querying MoMo: {str(e)}"}), 500

# =============================================
# REFUND (FOR ADMIN)
# =============================================

@payment_bp.route('/refund/<int:payment_id>', methods=['POST'])
@jwt_required()
def refund_payment(payment_id):
    """Hoàn tiền (chỉ admin)"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role != 'admin':
        return jsonify({"msg": "Admin access required"}), 403
    
    payment = Payment.query.get_or_404(payment_id)
    
    if payment.payment_status != 'completed':
        return jsonify({"msg": "Can only refund completed payments"}), 400
    
    data = request.get_json()
    
    payment.payment_status = 'refunded'
    payment.refund_reason = data.get('reason', 'Refunded by admin')
    payment.refunded_at = datetime.utcnow()
    
    # Cập nhật appointment status về pending nếu cần
    if payment.appointment_id:
        appointment = Appointment.query.get(payment.appointment_id)
        if appointment:
            appointment.status = 'pending'
    
    try:
        db.session.commit()
        log_activity(user_id, "REFUND_PAYMENT", "payment", payment.id, 
                    f"Refunded payment: {payment.payment_code}")
        return jsonify({"msg": "Payment refunded successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error refunding payment: {str(e)}"}), 500

# Import User model ở đầu file nếu chưa có
from models import User