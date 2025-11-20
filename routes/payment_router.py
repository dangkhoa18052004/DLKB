from flask import Blueprint, request, jsonify, redirect
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Payment, PaymentItem, Appointment, Service, Patient, User
from utils import log_activity, generate_code, get_patient_id_from_user
from datetime import datetime
import hashlib
import hmac
import json
import requests
import uuid
import traceback 

payment_bp = Blueprint('payment', __name__)

HOST_IP = '192.168.100.151' 
FRONTEND_URL = f'http://{HOST_IP}:3000' 

MOMO_CONFIG = {
    'partner_code': 'MOMOBKUN20180529',
    'access_key': 'klm05TvNBzhg7h7j',
    'secret_key': 'at67qH6mk8w5Y1nAyMoYKMWACiEi2bsa',
    'endpoint': 'https://test-payment.momo.vn/gateway/api/create',
    'redirect_url': f'http://{HOST_IP}:5000/api/payment/momo/callback',
    'ipn_url': f'http://{HOST_IP}:5000/api/payment/momo/ipn',
    'request_type': 'payWithATM'  
}

def generate_momo_signature(raw_signature, secret_key):
    """Tạo HMAC SHA256 signature cho MoMo"""
    h = hmac.new(secret_key.encode(), raw_signature.encode(), hashlib.sha256)
    return h.hexdigest()

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
    
    appointment = Appointment.query.filter_by(id=appointment_id, patient_id=patient_id).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found"}), 404
    
    existing_payment = Payment.query.filter_by(appointment_id=appointment_id).first()
    if existing_payment and existing_payment.payment_status in ['completed', 'processing']:
        return jsonify({"msg": "Payment already exists for this appointment"}), 409
    
    service = Service.query.get(appointment.service_id)
    if not service:
        return jsonify({"msg": "Service not found"}), 404
    
    total_amount = float(service.price)
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
        
        from models import PaymentItem 
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


# MOMO PAYMENT INTEGRATION
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
    
    payment = Payment.query.filter_by(id=payment_id, patient_id=patient_id).first()
    
    if not payment:
        return jsonify({"msg": "Payment not found"}), 404
    
    if payment.payment_status in ['completed', 'processing']:
         return jsonify({"msg": f"Payment already exists and is {payment.payment_status}"}), 409

    if payment.payment_status != 'pending':
        return jsonify({"msg": f"Payment status is {payment.payment_status}, cannot process"}), 400
    
    order_id = payment.payment_code
    try:
        amount = str(int(float(payment.amount)))
    except ValueError:
        return jsonify({"msg": f"Invalid amount value: {payment.amount}"}), 400
        
    order_info = payment.description
    request_id = str(uuid.uuid4())
    
    # 1. TẠO DICT CHỨA TẤT CẢ THAM SỐ GỐC
    params = {
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
        'lang': 'vi'
    }
    
    # 2. TẠO CHUỖI RAW SIGNATURE THEO THỨ TỰ CỦA MOMO (accessKey, amount, extraData, ...)
    # SỬ DỤNG LIST CÁC KEY THEO ĐÚNG THỨ TỰ BẢNG CHỮ CÁI ĐỂ KHẮC PHỤC LỖI 403
    
    MOMO_SIGNATURE_KEYS = [
        'accessKey', 'amount', 'extraData', 'ipnUrl', 'orderId', 'orderInfo', 
        'partnerCode', 'redirectUrl', 'requestId', 'requestType'
    ]
    
    # TẠO CHUỖI CHỮ KÝ RAW_SIGNATURE
    raw_signature_parts = []
    for key in MOMO_SIGNATURE_KEYS:
        # Lấy giá trị, sử dụng giá trị từ dict params
        value = params.get(key)
        # Chỉ thêm nếu key không phải là 'signature' (đã kiểm tra)
        raw_signature_parts.append(f"{key}={value}") 
        
    raw_signature = "&".join(raw_signature_parts)
    
    signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    momo_data = params
    momo_data['signature'] = signature
    
    try:
        response = requests.post(
            MOMO_CONFIG['endpoint'],
            json=momo_data,
            headers={'Content-Type': 'application/json'},
            timeout=10,
            verify=False 
        )
        
        # KIỂM TRA RESPONSE
        if response.status_code == 200:
            result = response.json()
        else:
            return jsonify({
                "msg": f"MoMo API returned status {response.status_code} ({response.reason})",
                "detail": response.text[:100]
            }), 400

        # XỬ LÝ KẾT QUẢ
        if result.get('resultCode') == 0:
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
            # Lỗi logic MoMo (ví dụ: tham số sai, mã code sai)
            return jsonify({
                "msg": "Failed to initiate MoMo payment (MoMo Logic Error)",
                "error": result.get('message'),
                "result_code": result.get('resultCode')
            }), 400
            
    except requests.exceptions.RequestException as e:
        error_msg = f"Network Error: Could not connect to MoMo. Details: {str(e)}"
        print(f"[ERROR] MoMo Init Failed: {error_msg}")
        traceback.print_exc() 
        return jsonify({"msg": error_msg}), 500
    except json.JSONDecodeError as e:
        error_msg = f"MoMo returned non-JSON data. Details: {str(e)} Response: {response.text[:500]}"
        print(f"[ERROR] MoMo JSON Decode Failed: {error_msg}")
        return jsonify({"msg": error_msg}), 500
    except Exception as e:
        db.session.rollback()
        print("[CRITICAL PYTHON ERROR] MoMo Init Crash:")
        traceback.print_exc() 
        return jsonify({"msg": f"Internal Server Crash: {type(e).__name__}"}), 500

# [Giữ nguyên các routes callback, ipn và check-status]

@payment_bp.route('/momo/callback', methods=['GET'])
def momo_payment_callback():
    """Xử lý callback từ MoMo sau khi thanh toán"""
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
    
    payment = Payment.query.filter_by(payment_code=order_id).first()
    
    FRONTEND_URL = f'http://{HOST_IP}:3000' 

    if not payment:
        return redirect(f'{FRONTEND_URL}/payment/failed?msg=Payment not found')
    
    # Verify signature
    # Cần hardcode thứ tự tham số cho verify signature
    VERIFY_SIGNATURE_KEYS = [
        'accessKey', 'amount', 'extraData', 'message', 'orderId', 'orderInfo', 
        'orderType', 'partnerCode', 'payType', 'requestId', 'responseTime', 
        'resultCode', 'transId'
    ]
    
    raw_signature_data = {
        'accessKey': MOMO_CONFIG['access_key'],
        'amount': amount,
        'extraData': extra_data or '',
        'message': message,
        'orderId': order_id,
        'orderInfo': order_info,
        'orderType': order_type,
        'partnerCode': partner_code,
        'payType': pay_type,
        'requestId': request_id,
        'responseTime': response_time,
        'resultCode': result_code,
        'transId': trans_id
    }
    
    raw_signature_parts = [f"{key}={raw_signature_data[key]}" for key in VERIFY_SIGNATURE_KEYS]
    raw_signature = "&".join(raw_signature_parts)

    expected_signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    if signature != expected_signature:
        return redirect(f'{FRONTEND_URL}/payment/failed?msg=Invalid signature')
    
    if result_code == '0':
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = trans_id
        
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        
        return redirect(f'{FRONTEND_URL}/payment/success?payment_code={order_id}&trans_id={trans_id}')
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        
        return redirect(f'{FRONTEND_URL}/payment/failed?msg={message}&code={result_code}')

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
    # Cần hardcode thứ tự tham số cho verify signature
    VERIFY_SIGNATURE_KEYS = [
        'accessKey', 'amount', 'extraData', 'message', 'orderId', 'orderInfo', 
        'orderType', 'partnerCode', 'payType', 'requestId', 'responseTime', 
        'resultCode', 'transId'
    ]
    
    raw_signature_data = {
        'accessKey': MOMO_CONFIG['access_key'],
        'amount': amount,
        'extraData': extra_data or '',
        'message': message,
        'orderId': order_id,
        'orderInfo': order_info,
        'orderType': order_type,
        'partnerCode': partner_code,
        'payType': pay_type,
        'requestId': request_id,
        'responseTime': response_time,
        'resultCode': result_code,
        'transId': trans_id
    }
    
    raw_signature_parts = [f"{key}={raw_signature_data[key]}" for key in VERIFY_SIGNATURE_KEYS]
    raw_signature = "&".join(raw_signature_parts)
    
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