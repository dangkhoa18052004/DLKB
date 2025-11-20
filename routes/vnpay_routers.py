from flask import Blueprint, request, jsonify, redirect
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Payment, PaymentItem, Appointment, Service
from utils import log_activity, get_patient_id_from_user
from datetime import datetime
import hashlib
import hmac
import urllib.parse
import uuid

vnpay_bp = Blueprint('vnpay', __name__)

# VNPAY CONFIGURATION (SANDBOX)
VNPAY_CONFIG = {
    'vnp_TmnCode': 'YOUR_TMN_CODE',  # Mã website tại VNPAY
    'vnp_HashSecret': 'YOUR_HASH_SECRET',  # Chuỗi bí mật
    'vnp_Url': 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
    'vnp_ReturnUrl': 'http://localhost:5000/api/v1/payment/vnpay/callback',
    'vnp_IpnUrl': 'http://localhost:5000/api/v1/payment/vnpay/ipn'
}

def generate_vnpay_hash(data, secret_key):
    """Tạo HMAC SHA512 hash cho VNPay"""
    # Sắp xếp parameters theo alphabet
    sorted_params = sorted(data.items())
    
    # Tạo query string
    query_string = '&'.join([f"{key}={value}" for key, value in sorted_params if value])
    
    # Tạo hash
    h = hmac.new(secret_key.encode(), query_string.encode(), hashlib.sha512)
    return h.hexdigest()

@vnpay_bp.route('/create', methods=['POST'])
@jwt_required()
def create_vnpay_payment():
    """Khởi tạo thanh toán qua VNPay"""
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
    
    # Chuẩn bị dữ liệu cho VNPay
    txn_ref = payment.payment_code
    amount = int(float(payment.amount) * 100)  # VNPay yêu cầu số tiền tính bằng đồng (x100)
    order_info = payment.description
    order_type = 'billpayment'
    locale = 'vn'
    ip_addr = request.remote_addr or '127.0.0.1'
    
    # Tạo request_id
    request_id = str(uuid.uuid4())
    
    # Tạo thời gian
    create_date = datetime.now().strftime('%Y%m%d%H%M%S')
    
    # Dữ liệu gửi đến VNPay
    vnp_params = {
        'vnp_Version': '2.1.0',
        'vnp_Command': 'pay',
        'vnp_TmnCode': VNPAY_CONFIG['vnp_TmnCode'],
        'vnp_Amount': str(amount),
        'vnp_CurrCode': 'VND',
        'vnp_TxnRef': txn_ref,
        'vnp_OrderInfo': order_info,
        'vnp_OrderType': order_type,
        'vnp_Locale': locale,
        'vnp_ReturnUrl': VNPAY_CONFIG['vnp_ReturnUrl'],
        'vnp_IpAddr': ip_addr,
        'vnp_CreateDate': create_date
    }
    
    # Tạo secure hash
    secure_hash = generate_vnpay_hash(vnp_params, VNPAY_CONFIG['vnp_HashSecret'])
    vnp_params['vnp_SecureHash'] = secure_hash
    
    # Tạo payment URL
    query_string = urllib.parse.urlencode(vnp_params)
    payment_url = f"{VNPAY_CONFIG['vnp_Url']}?{query_string}"
    
    # Cập nhật payment status
    payment.payment_status = 'processing'
    payment.transaction_id = request_id
    
    try:
        db.session.commit()
        log_activity(user_id, "INIT_VNPAY_PAYMENT", "payment", payment.id, 
                    f"Initiated VNPay payment for {txn_ref}")
        
        return jsonify({
            "msg": "VNPay payment initiated successfully",
            "payment_url": payment_url,
            "request_id": request_id
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error processing VNPay payment: {str(e)}"}), 500

@vnpay_bp.route('/callback', methods=['GET'])
def vnpay_payment_callback():
    """Xử lý callback từ VNPay sau khi thanh toán"""
    # Lấy parameters từ VNPay
    vnp_params = {}
    for key, value in request.args.items():
        if key != 'vnp_SecureHash':
            vnp_params[key] = value
    
    vnp_secure_hash = request.args.get('vnp_SecureHash')
    
    # Verify signature
    calculated_hash = generate_vnpay_hash(vnp_params, VNPAY_CONFIG['vnp_HashSecret'])
    
    if vnp_secure_hash != calculated_hash:
        return redirect(f'http://localhost:3000/payment/failed?msg=Invalid signature')
    
    # Lấy thông tin
    txn_ref = vnp_params.get('vnp_TxnRef')
    response_code = vnp_params.get('vnp_ResponseCode')
    transaction_no = vnp_params.get('vnp_TransactionNo')
    
    # Tìm payment
    payment = Payment.query.filter_by(payment_code=txn_ref).first()
    
    if not payment:
        return redirect(f'http://localhost:3000/payment/failed?msg=Payment not found')
    
    # Cập nhật payment status
    if response_code == '00':  # Giao dịch thành công
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = transaction_no
        
        # Cập nhật appointment status thành confirmed
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        
        return redirect(f'http://localhost:3000/payment/success?payment_code={txn_ref}&trans_id={transaction_no}')
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        
        error_message = get_vnpay_error_message(response_code)
        return redirect(f'http://localhost:3000/payment/failed?msg={error_message}&code={response_code}')

@vnpay_bp.route('/ipn', methods=['GET'])
def vnpay_payment_ipn():
    """Xử lý IPN (Instant Payment Notification) từ VNPay"""
    # Lấy parameters từ VNPay
    vnp_params = {}
    for key, value in request.args.items():
        if key != 'vnp_SecureHash':
            vnp_params[key] = value
    
    vnp_secure_hash = request.args.get('vnp_SecureHash')
    
    # Verify signature
    calculated_hash = generate_vnpay_hash(vnp_params, VNPAY_CONFIG['vnp_HashSecret'])
    
    if vnp_secure_hash != calculated_hash:
        return jsonify({
            'RspCode': '97',
            'Message': 'Invalid signature'
        }), 200
    
    # Lấy thông tin
    txn_ref = vnp_params.get('vnp_TxnRef')
    response_code = vnp_params.get('vnp_ResponseCode')
    transaction_no = vnp_params.get('vnp_TransactionNo')
    
    # Tìm payment
    payment = Payment.query.filter_by(payment_code=txn_ref).first()
    
    if not payment:
        return jsonify({
            'RspCode': '01',
            'Message': 'Order not found'
        }), 200
    
    # Kiểm tra trạng thái payment
    if payment.payment_status == 'completed':
        return jsonify({
            'RspCode': '02',
            'Message': 'Order already confirmed'
        }), 200
    
    # Cập nhật payment status
    if response_code == '00':
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = transaction_no
        
        # Cập nhật appointment status
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        
        return jsonify({
            'RspCode': '00',
            'Message': 'Confirm Success'
        }), 200
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        
        return jsonify({
            'RspCode': '00',
            'Message': 'Confirm Success'
        }), 200

def get_vnpay_error_message(response_code):
    """Lấy thông báo lỗi từ response code"""
    error_messages = {
        '07': 'Trừ tiền thành công. Giao dịch bị nghi ngờ (liên quan tới lừa đảo, giao dịch bất thường).',
        '09': 'Giao dịch không thành công do: Thẻ/Tài khoản của khách hàng chưa đăng ký dịch vụ InternetBanking tại ngân hàng.',
        '10': 'Giao dịch không thành công do: Khách hàng xác thực thông tin thẻ/tài khoản không đúng quá 3 lần',
        '11': 'Giao dịch không thành công do: Đã hết hạn chờ thanh toán. Xin quý khách vui lòng thực hiện lại giao dịch.',
        '12': 'Giao dịch không thành công do: Thẻ/Tài khoản của khách hàng bị khóa.',
        '13': 'Giao dịch không thành công do Quý khách nhập sai mật khẩu xác thực giao dịch (OTP).',
        '24': 'Giao dịch không thành công do: Khách hàng hủy giao dịch',
        '51': 'Giao dịch không thành công do: Tài khoản của quý khách không đủ số dư để thực hiện giao dịch.',
        '65': 'Giao dịch không thành công do: Tài khoản của Quý khách đã vượt quá hạn mức giao dịch trong ngày.',
        '75': 'Ngân hàng thanh toán đang bảo trì.',
        '79': 'Giao dịch không thành công do: KH nhập sai mật khẩu thanh toán quá số lần quy định.',
        '99': 'Các lỗi khác'
    }
    
    return error_messages.get(response_code, 'Giao dịch thất bại')

@vnpay_bp.route('/query', methods=['POST'])
@jwt_required()
def query_vnpay_transaction():
    """Truy vấn trạng thái giao dịch VNPay"""
    user_id = get_jwt_identity()
    data = request.get_json()
    
    txn_ref = data.get('txn_ref')
    trans_date = data.get('trans_date')  # Format: yyyyMMddHHmmss
    
    if not txn_ref or not trans_date:
        return jsonify({"msg": "txn_ref and trans_date are required"}), 400
    
    request_id = str(uuid.uuid4())
    
    # Dữ liệu truy vấn
    vnp_params = {
        'vnp_Version': '2.1.0',
        'vnp_Command': 'querydr',
        'vnp_TmnCode': VNPAY_CONFIG['vnp_TmnCode'],
        'vnp_TxnRef': txn_ref,
        'vnp_OrderInfo': 'Query transaction',
        'vnp_TransactionDate': trans_date,
        'vnp_CreateDate': datetime.now().strftime('%Y%m%d%H%M%S'),
        'vnp_IpAddr': request.remote_addr or '127.0.0.1',
        'vnp_RequestId': request_id
    }
    
    # Tạo secure hash
    secure_hash = generate_vnpay_hash(vnp_params, VNPAY_CONFIG['vnp_HashSecret'])
    vnp_params['vnp_SecureHash'] = secure_hash
    
    # VNPay query endpoint (khác với payment endpoint)
    query_url = 'https://sandbox.vnpayment.vn/merchant_webapi/api/transaction'
    
    try:
        import requests
        response = requests.post(
            query_url,
            json=vnp_params,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        result = response.json()
        return jsonify(result), 200
        
    except Exception as e:
        return jsonify({"msg": f"Error querying VNPay: {str(e)}"}), 500

# Import models
from models import Appointment