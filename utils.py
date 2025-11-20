import random
import string
import pytz
from datetime import datetime
from functools import wraps
from flask import jsonify
from flask_jwt_extended import get_jwt_identity
from models import db, ActivityLog, SystemSetting, Patient, User, Doctor

# --- CÁC HẰNG SỐ ---
VIETNAM_TIMEZONE = pytz.timezone('Asia/Ho_Chi_Minh')

def generate_code(prefix='AP', length=8):
    """Tạo mã code ngẫu nhiên cho Appointment, Patient, Payment..."""
    chars = string.ascii_uppercase + string.digits
    return prefix + ''.join(random.choice(chars) for _ in range(length))

def get_patient_id_from_user(user_id):
    """Lấy patient_id từ user_id (Dành cho role 'patient')"""
    try:
        uid = int(user_id)
    except Exception:
        uid = user_id
    patient = Patient.query.filter_by(user_id=uid).first()
    return patient.id if patient else None

def get_doctor_id_from_user(user_id):
    """Lấy doctor_id từ user_id (Dành cho role 'doctor')"""
    try:
        uid = int(user_id)
    except Exception:
        uid = user_id
    doctor = Doctor.query.filter_by(user_id=uid).first()
    return doctor.id if doctor else None

def get_system_setting(key, default=None):
    """Lấy giá trị từ bảng SystemSettings"""
    setting = SystemSetting.query.filter_by(key=key).first()
    if setting:
        return setting.value
    return default

def log_activity(user_id, action, entity_type=None, entity_id=None, description=''):
    """Ghi lại hoạt động của người dùng"""
    try:
        log = ActivityLog(
            user_id=user_id, 
            action=action, 
            entity_type=entity_type, 
            entity_id=entity_id, 
            description=description,
        )
        db.session.add(log)
        db.session.commit()
    except Exception as e:
        print(f"ERROR LOGGING ACTIVITY: {e}")
        db.session.rollback()

def utc_to_vn_time(utc_datetime):
    """Chuyển đổi datetime từ UTC sang múi giờ Việt Nam"""
    if utc_datetime.tzinfo is None:
        utc_datetime = pytz.utc.localize(utc_datetime)
    return utc_datetime.astimezone(VIETNAM_TIMEZONE)

# =============================================
# ROLE-BASED DECORATORS
# =============================================

def admin_required(fn):
    """Decorator yêu cầu role admin"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user or user.role != 'admin':
            return jsonify({"msg": "Admin access required"}), 403
        
        return fn(*args, **kwargs)
    
    return wrapper

def doctor_required(fn):
    """Decorator yêu cầu role doctor"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user or user.role != 'doctor':
            return jsonify({"msg": "Doctor access required"}), 403
        
        return fn(*args, **kwargs)
    
    return wrapper

def patient_required(fn):
    """Decorator yêu cầu role patient"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user or user.role != 'patient':
            return jsonify({"msg": "Patient access required"}), 403
        
        return fn(*args, **kwargs)
    
    return wrapper

def staff_or_admin_required(fn):
    """Decorator yêu cầu role staff hoặc admin"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        user_id = get_jwt_identity()
        user = User.query.get(user_id)
        
        if not user or user.role not in ['admin', 'staff']:
            return jsonify({"msg": "Staff or Admin access required"}), 403
        
        return fn(*args, **kwargs)
    
    return wrapper