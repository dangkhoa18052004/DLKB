from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User
from utils import log_activity, generate_code
from datetime import datetime, timedelta
import secrets

password_reset_bp = Blueprint('password_reset', __name__)

# Tạm thời lưu reset tokens trong memory (production nên dùng Redis hoặc DB)
password_reset_tokens = {}
email_verification_tokens = {}

# =============================================
# FORGOT PASSWORD
# =============================================

@password_reset_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    """Yêu cầu reset mật khẩu - Gửi mã xác thực qua email"""
    data = request.get_json()
    
    email = data.get('email')
    if not email:
        return jsonify({"msg": "Email is required"}), 400
    
    user = User.query.filter_by(email=email).first()
    
    # Không tiết lộ user có tồn tại hay không (security best practice)
    if not user:
        return jsonify({
            "msg": "If the email exists, a password reset link has been sent"
        }), 200
    
    # Tạo reset token
    reset_token = secrets.token_urlsafe(32)
    expiry_time = datetime.utcnow() + timedelta(hours=1)  # Token hết hạn sau 1 giờ
    
    # Lưu token (trong production nên lưu vào DB hoặc Redis)
    password_reset_tokens[reset_token] = {
        'user_id': user.id,
        'email': email,
        'expires_at': expiry_time
    }
    
    # TODO: Gửi email chứa reset link
    # reset_link = f"http://localhost:3000/reset-password?token={reset_token}"
    # send_email(email, "Reset Password", f"Click here to reset: {reset_link}")
    
    log_activity(user.id, "REQUEST_PASSWORD_RESET", "user", user.id, 
                f"Requested password reset for {email}")
    
    return jsonify({
        "msg": "If the email exists, a password reset link has been sent",
        "reset_token": reset_token  # Chỉ trả về trong dev/testing, không trả trong production
    }), 200

@password_reset_bp.route('/verify-reset-token', methods=['POST'])
def verify_reset_token():
    """Xác thực reset token có hợp lệ không"""
    data = request.get_json()
    
    token = data.get('token')
    if not token:
        return jsonify({"msg": "Token is required"}), 400
    
    token_data = password_reset_tokens.get(token)
    
    if not token_data:
        return jsonify({"msg": "Invalid or expired token"}), 400
    
    if datetime.utcnow() > token_data['expires_at']:
        del password_reset_tokens[token]
        return jsonify({"msg": "Token has expired"}), 400
    
    return jsonify({
        "msg": "Token is valid",
        "email": token_data['email']
    }), 200

@password_reset_bp.route('/reset-password', methods=['POST'])
def reset_password():
    """Reset mật khẩu với token hợp lệ"""
    data = request.get_json()
    
    token = data.get('token')
    new_password = data.get('new_password')
    confirm_password = data.get('confirm_password')
    
    if not all([token, new_password, confirm_password]):
        return jsonify({"msg": "All fields are required"}), 400
    
    if new_password != confirm_password:
        return jsonify({"msg": "Passwords do not match"}), 400
    
    if len(new_password) < 6:
        return jsonify({"msg": "Password must be at least 6 characters"}), 400
    
    # Xác thực token
    token_data = password_reset_tokens.get(token)
    
    if not token_data:
        return jsonify({"msg": "Invalid or expired token"}), 400
    
    if datetime.utcnow() > token_data['expires_at']:
        del password_reset_tokens[token]
        return jsonify({"msg": "Token has expired"}), 400
    
    # Tìm user và reset password
    user = User.query.get(token_data['user_id'])
    
    if not user:
        return jsonify({"msg": "User not found"}), 404
    
    user.set_password(new_password)
    
    try:
        db.session.commit()
        
        # Xóa token sau khi sử dụng
        del password_reset_tokens[token]
        
        log_activity(user.id, "PASSWORD_RESET", "user", user.id, 
                    "Password reset successfully")
        
        return jsonify({"msg": "Password reset successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error resetting password: {str(e)}"}), 500

# =============================================
# EMAIL VERIFICATION
# =============================================

@password_reset_bp.route('/send-verification-email', methods=['POST'])
@jwt_required()
def send_verification_email():
    """Gửi email xác thực"""
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    
    if user.is_verified:
        return jsonify({"msg": "Email already verified"}), 400
    
    # Tạo verification token
    verification_token = secrets.token_urlsafe(32)
    expiry_time = datetime.utcnow() + timedelta(hours=24)  # Token hết hạn sau 24 giờ
    
    # Lưu token
    email_verification_tokens[verification_token] = {
        'user_id': user.id,
        'email': user.email,
        'expires_at': expiry_time
    }
    
    # TODO: Gửi email chứa verification link
    # verification_link = f"http://localhost:3000/verify-email?token={verification_token}"
    # send_email(user.email, "Verify Email", f"Click here to verify: {verification_link}")
    
    log_activity(user.id, "SEND_VERIFICATION_EMAIL", "user", user.id, 
                f"Verification email sent to {user.email}")
    
    return jsonify({
        "msg": "Verification email sent",
        "verification_token": verification_token  # Chỉ trong dev/testing
    }), 200

@password_reset_bp.route('/verify-email', methods=['POST'])
def verify_email():
    """Xác thực email với token"""
    data = request.get_json()
    
    token = data.get('token')
    if not token:
        return jsonify({"msg": "Token is required"}), 400
    
    token_data = email_verification_tokens.get(token)
    
    if not token_data:
        return jsonify({"msg": "Invalid or expired token"}), 400
    
    if datetime.utcnow() > token_data['expires_at']:
        del email_verification_tokens[token]
        return jsonify({"msg": "Token has expired"}), 400
    
    # Tìm user và verify
    user = User.query.get(token_data['user_id'])
    
    if not user:
        return jsonify({"msg": "User not found"}), 404
    
    if user.is_verified:
        return jsonify({"msg": "Email already verified"}), 400
    
    user.is_verified = True
    
    try:
        db.session.commit()
        
        # Xóa token sau khi sử dụng
        del email_verification_tokens[token]
        
        log_activity(user.id, "EMAIL_VERIFIED", "user", user.id, 
                    f"Email {user.email} verified successfully")
        
        return jsonify({
            "msg": "Email verified successfully",
            "user": user.to_json()
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error verifying email: {str(e)}"}), 500

@password_reset_bp.route('/resend-verification', methods=['POST'])
@jwt_required()
def resend_verification_email():
    """Gửi lại email xác thực"""
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    
    if user.is_verified:
        return jsonify({"msg": "Email already verified"}), 400
    
    # Tạo verification token mới
    verification_token = secrets.token_urlsafe(32)
    expiry_time = datetime.utcnow() + timedelta(hours=24)
    
    # Lưu token
    email_verification_tokens[verification_token] = {
        'user_id': user.id,
        'email': user.email,
        'expires_at': expiry_time
    }
    
    # TODO: Gửi email
    
    log_activity(user.id, "RESEND_VERIFICATION_EMAIL", "user", user.id, 
                f"Verification email resent to {user.email}")
    
    return jsonify({
        "msg": "Verification email resent",
        "verification_token": verification_token
    }), 200

# =============================================
# ADMIN - MANUALLY VERIFY USER
# =============================================

@password_reset_bp.route('/admin/verify-user/<int:user_id>', methods=['PUT'])
@jwt_required()
def admin_verify_user(user_id):
    """Admin xác thực user thủ công"""
    admin_id = get_jwt_identity()
    admin = User.query.get(admin_id)
    
    if admin.role != 'admin':
        return jsonify({"msg": "Admin access required"}), 403
    
    user = User.query.get_or_404(user_id)
    
    if user.is_verified:
        return jsonify({"msg": "User already verified"}), 400
    
    user.is_verified = True
    
    try:
        db.session.commit()
        log_activity(admin_id, "ADMIN_VERIFY_USER", "user", user_id, 
                    f"Admin verified user: {user.email}")
        
        return jsonify({"msg": "User verified successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error: {str(e)}"}), 500