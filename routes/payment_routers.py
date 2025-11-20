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
import os

payment_bp = Blueprint('payment', __name__)

HOST_IP = '192.168.100.151' 
FRONTEND_URL = f'http://{HOST_IP}:3000' 

NGROK_URL = 'https://abc123xyz.ngrok-free.app'

MOMO_CONFIG = {
    'partner_code': 'MOMO',
    'access_key': 'F8BBA842ECF85',
    'secret_key': 'K951B6PE1waDMi640xX08PD3vg6EkVlz',
    'endpoint': 'https://test-payment.momo.vn/v2/gateway/api/create',
    'redirect_url': f'{NGROK_URL}/api/payment/momo/callback', 
    'ipn_url': f'{NGROK_URL}/api/payment/momo/ipn', 
    'request_type': 'captureWallet'
}

def generate_momo_signature(raw_signature, secret_key):
    """Tạo HMAC SHA256 signature cho MoMo (UTF-8 Support)"""
    h = hmac.new(bytes(secret_key, 'utf-8'), bytes(raw_signature, 'utf-8'), hashlib.sha256)
    return h.hexdigest()

# ... (giữ nguyên các hàm create_payment)

@payment_bp.route('/momo/create', methods=['POST'])
@jwt_required()
def create_momo_payment():
    """Khởi tạo thanh toán qua MoMo (Official GitHub Format)"""
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
    request_id = str(uuid.uuid4())
    amount = str(int(float(payment.amount)))
    order_info = payment.description
    extra_data = ""
    
    # ✅ SỬ DỤNG NGROK URL
    raw_signature = (
        "accessKey=" + MOMO_CONFIG['access_key'] + 
        "&amount=" + amount + 
        "&extraData=" + extra_data + 
        "&ipnUrl=" + MOMO_CONFIG['ipn_url'] +  # ← Ngrok URL
        "&orderId=" + order_id + 
        "&orderInfo=" + order_info + 
        "&partnerCode=" + MOMO_CONFIG['partner_code'] + 
        "&redirectUrl=" + MOMO_CONFIG['redirect_url'] +  # ← Ngrok URL
        "&requestId=" + request_id + 
        "&requestType=" + MOMO_CONFIG['request_type']
    )
    
    print("--------------------RAW SIGNATURE----------------")
    print(raw_signature)
    
    signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    print("--------------------SIGNATURE----------------")
    print(signature)
    
    momo_data = {
        'partnerCode': MOMO_CONFIG['partner_code'],
        'partnerName': "Hospital Booking",
        'storeId': "HospitalStore",
        'requestId': request_id,
        'amount': amount,
        'orderId': order_id,
        'orderInfo': order_info,
        'redirectUrl': MOMO_CONFIG['redirect_url'],  # ← Ngrok URL
        'ipnUrl': MOMO_CONFIG['ipn_url'],  # ← Ngrok URL
        'lang': "vi",
        'extraData': extra_data,
        'requestType': MOMO_CONFIG['request_type'],
        'signature': signature
    }
    
    print("--------------------JSON REQUEST----------------")
    print(json.dumps(momo_data, indent=2))
    
    try:
        json_data = json.dumps(momo_data)
        response = requests.post(
            MOMO_CONFIG['endpoint'],
            data=json_data,
            headers={
                'Content-Type': 'application/json',
                'Content-Length': str(len(json_data))
            },
            timeout=10
        )
        
        print("--------------------JSON RESPONSE----------------")
        print(response.json())
        
        result = response.json()
        
        if result.get('resultCode') == 0:
            payment.payment_status = 'processing'
            payment.transaction_id = request_id
            db.session.commit()
            
            log_activity(user_id, "INIT_MOMO_PAYMENT", "payment", payment.id, 
                        f"Initiated MoMo payment for {order_id}")
            
            print("--------------------PAY URL----------------")
            print(result.get('payUrl'))
            
            return jsonify({
                "msg": "MoMo payment initiated successfully",
                "payment_url": result.get('payUrl'),
                "qr_code_url": result.get('qrCodeUrl'),
                "deeplink": result.get('deeplink'),
                "request_id": request_id
            }), 200
        else:
            return jsonify({
                "msg": "MoMo payment failed",
                "error": result.get('message'),
                "result_code": result.get('resultCode'),
                "detail": result
            }), 400
            
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] MoMo Connection Error: {str(e)}")
        traceback.print_exc()
        return jsonify({"msg": f"Connection error: {str(e)}"}), 500
    except Exception as e:
        db.session.rollback()
        print(f"[ERROR] Unexpected error: {str(e)}")
        traceback.print_exc()
        return jsonify({"msg": f"Internal error: {str(e)}"}), 500


@payment_bp.route('/momo/callback', methods=['GET'])
def momo_payment_callback():
    """Xử lý callback từ MoMo (Official Format)"""
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
    extra_data = request.args.get('extraData', '')
    signature = request.args.get('signature')
    
    print("="*60)
    print(f"[CALLBACK RECEIVED] Order ID: {order_id}, Result Code: {result_code}")
    print(f"[CALLBACK] Transaction ID: {trans_id}")
    print(f"[CALLBACK] Message: {message}")
    print("="*60)
    
    payment = Payment.query.filter_by(payment_code=order_id).first()
    
    if not payment:
        print(f"[ERROR] Payment not found: {order_id}")
        return redirect(f'{FRONTEND_URL}/payment/failed?msg=Payment not found')
    
    # ✅ VERIFY SIGNATURE
    raw_signature = (
        "accessKey=" + MOMO_CONFIG['access_key'] +
        "&amount=" + str(amount) +
        "&extraData=" + str(extra_data) +
        "&message=" + str(message) +
        "&orderId=" + str(order_id) +
        "&orderInfo=" + str(order_info) +
        "&orderType=" + str(order_type) +
        "&partnerCode=" + str(partner_code) +
        "&payType=" + str(pay_type) +
        "&requestId=" + str(request_id) +
        "&responseTime=" + str(response_time) +
        "&resultCode=" + str(result_code) +
        "&transId=" + str(trans_id)
    )
    
    expected_signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    print(f"[VERIFY] Expected: {expected_signature}")
    print(f"[VERIFY] Received: {signature}")
    
    if signature != expected_signature:
        print(f"[ERROR] Signature mismatch!")
        return redirect(f'{FRONTEND_URL}/payment/failed?msg=Invalid signature')
    
    # ✅ CẬP NHẬT DATABASE
    if result_code == '0':
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = trans_id
        
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        
        print(f"[SUCCESS] ✅ Payment completed: {order_id}")
        print(f"[SUCCESS] ✅ Appointment confirmed: {appointment.appointment_code if appointment else 'N/A'}")
        
        # ⚠️ LƯU Ý: Redirect về frontend sẽ không hoạt động vì đây là callback từ MoMo
        # App Flutter sẽ tự động check status và cập nhật UI
        return jsonify({"msg": "Payment completed successfully"}), 200
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        
        print(f"[FAILED] ❌ Payment failed: {order_id}, Message: {message}")
        return jsonify({"msg": f"Payment failed: {message}"}), 200


@payment_bp.route('/momo/ipn', methods=['POST'])
def momo_payment_ipn():
    """Xử lý IPN từ MoMo (Official Format)"""
    data = request.get_json()
    
    print("="*60)
    print("[IPN RECEIVED]")
    print(json.dumps(data, indent=2))
    print("="*60)
    
    partner_code = data.get('partnerCode')
    order_id = data.get('orderId')
    request_id = data.get('requestId')
    amount = str(data.get('amount'))
    order_info = data.get('orderInfo')
    order_type = data.get('orderType')
    trans_id = str(data.get('transId'))
    result_code = str(data.get('resultCode'))
    message = data.get('message')
    pay_type = data.get('payType')
    response_time = str(data.get('responseTime'))
    extra_data = data.get('extraData', '')
    signature = data.get('signature')
    
    # Verify signature
    raw_signature = (
        "accessKey=" + MOMO_CONFIG['access_key'] +
        "&amount=" + amount +
        "&extraData=" + extra_data +
        "&message=" + message +
        "&orderId=" + order_id +
        "&orderInfo=" + order_info +
        "&orderType=" + order_type +
        "&partnerCode=" + partner_code +
        "&payType=" + pay_type +
        "&requestId=" + request_id +
        "&responseTime=" + response_time +
        "&resultCode=" + result_code +
        "&transId=" + trans_id
    )
    
    expected_signature = generate_momo_signature(raw_signature, MOMO_CONFIG['secret_key'])
    
    if signature != expected_signature:
        print(f"[IPN ERROR] Invalid signature")
        return jsonify({'resultCode': 97, 'message': 'Invalid signature'}), 200
    
    payment = Payment.query.filter_by(payment_code=order_id).first()
    
    if not payment:
        print(f"[IPN ERROR] Payment not found: {order_id}")
        return jsonify({'resultCode': 99, 'message': 'Payment not found'}), 200
    
    if result_code == '0':
        payment.payment_status = 'completed'
        payment.payment_date = datetime.utcnow()
        payment.transaction_id = trans_id
        
        if payment.appointment_id:
            appointment = Appointment.query.get(payment.appointment_id)
            if appointment and appointment.status == 'pending':
                appointment.status = 'confirmed'
        
        db.session.commit()
        print(f"[IPN SUCCESS] ✅ Payment completed via IPN: {order_id}")
        return jsonify({'resultCode': 0, 'message': 'Success'}), 200
    else:
        payment.payment_status = 'failed'
        db.session.commit()
        print(f"[IPN FAILED] ❌ Payment failed: {order_id}")
        return jsonify({'resultCode': 0, 'message': 'Confirmed'}), 200


@payment_bp.route('/status', methods=['GET'])
@jwt_required()
def check_payment_status():
    """Kiểm tra trạng thái thanh toán"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    payment_code = request.args.get('payment_code')
    
    if not payment_code:
        return jsonify({"msg": "payment_code is required"}), 400
    
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