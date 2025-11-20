import random
import string
import pytz
from datetime import datetime
from models import db, ActivityLog, SystemSetting, Patient

# --- CÁC HẰNG SỐ ---
VIETNAM_TIMEZONE = pytz.timezone('Asia/Ho_Chi_Minh')

def generate_code(prefix='AP', length=8):
    """Tạo mã code ngẫu nhiên cho Appointment, Patient, Payment..."""
    chars = string.ascii_uppercase + string.digits
    return prefix + ''.join(random.choice(chars) for _ in range(length))

def get_patient_id_from_user(user_id):
    """Lấy patient_id từ user_id (Dành cho role 'patient')"""
    patient = Patient.query.filter_by(user_id=user_id).first()
    return patient.id if patient else None

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