from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from datetime import datetime, date, time
from sqlalchemy import CheckConstraint
from sqlalchemy.orm import relationship

db = SQLAlchemy()
bcrypt = Bcrypt()

# =============================================
# HOSPITAL MANAGEMENT SYSTEM - FLASK SQLALCHEMY MODELS
# =============================================

# --- 1. BẢNG NGƯỜI DÙNG (Users) ---
class User(db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(15), unique=True, nullable=False)
    date_of_birth = db.Column(db.Date)
    gender = db.Column(db.String(10))
    address = db.Column(db.Text)
    avatar_url = db.Column(db.String(255))
    role = db.Column(db.String(20), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    is_verified = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = db.Column(db.DateTime)

    __table_args__ = (
        CheckConstraint(role.in_(['admin', 'doctor', 'patient', 'staff']), name='check_user_role'),
    )

    def set_password(self, password):
        """Mã hóa và thiết lập mật khẩu."""
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        """Kiểm tra mật khẩu."""
        return bcrypt.check_password_hash(self.password_hash, password)

    def to_json(self):
        """Chuyển đổi thông tin cơ bản sang JSON."""
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'full_name': self.full_name,
            'phone': self.phone,
            'role': self.role
        }

# --- 2. BẢNG CHUYÊN KHOA (Departments) ---
class Department(db.Model):
    __tablename__ = 'departments'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False)
    description = db.Column(db.Text)
    icon_url = db.Column(db.String(255))
    display_order = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# --- 3. BẢNG BÁC SĨ (Doctors) ---
class Doctor(db.Model):
    __tablename__ = 'doctors'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    department_id = db.Column(db.Integer, db.ForeignKey('departments.id'))
    license_number = db.Column(db.String(50), unique=True, nullable=False)
    specialization = db.Column(db.String(200))
    experience_years = db.Column(db.Integer)
    education = db.Column(db.Text)
    certificates = db.Column(db.Text)
    bio = db.Column(db.Text)
    consultation_fee = db.Column(db.Numeric(10, 2), default=0)
    rating = db.Column(db.Numeric(3, 2), default=0.0)
    total_reviews = db.Column(db.Integer, default=0)
    is_available = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = db.relationship("User", backref="doctor_info")
    department = db.relationship("Department", backref="doctors")

# --- 4. BẢNG LỊCH LÀM VIỆC BÁC SĨ (Doctor Schedules) ---
class DoctorSchedule(db.Model):
    __tablename__ = 'doctor_schedules'
    id = db.Column(db.Integer, primary_key=True)
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id', ondelete='CASCADE'))
    day_of_week = db.Column(db.Integer)
    start_time = db.Column(db.Time, nullable=False)
    end_time = db.Column(db.Time, nullable=False)
    max_patients = db.Column(db.Integer, default=20)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (
        CheckConstraint(day_of_week.between(0, 6), name='check_day_of_week'),
        db.UniqueConstraint('doctor_id', 'day_of_week', 'start_time', name='unique_schedule_slot')
    )

# --- 5. BẢNG NGÀY NGHỈ BÁC SĨ (Doctor Leaves) ---
class DoctorLeave(db.Model):
    __tablename__ = 'doctor_leaves'
    id = db.Column(db.Integer, primary_key=True)
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id', ondelete='CASCADE'))
    leave_date = db.Column(db.Date, nullable=False)
    start_time = db.Column(db.Time)
    end_time = db.Column(db.Time)
    reason = db.Column(db.Text)
    is_full_day = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# --- 6. BẢNG BỆNH NHÂN (Patients) ---
class Patient(db.Model):
    __tablename__ = 'patients'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    patient_code = db.Column(db.String(20), unique=True, nullable=False)
    blood_type = db.Column(db.String(5))
    allergies = db.Column(db.Text)
    medical_notes = db.Column(db.Text)
    emergency_contact_name = db.Column(db.String(100))
    emergency_contact_phone = db.Column(db.String(15))
    insurance_number = db.Column(db.String(50))
    insurance_provider = db.Column(db.String(100))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = db.relationship("User", backref="patient_info")

# --- 7. BẢNG DỊCH VỤ KHÁM (Services) ---
class Service(db.Model):
    __tablename__ = 'services'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    department_id = db.Column(db.Integer, db.ForeignKey('departments.id'))
    price = db.Column(db.Numeric(10, 2), nullable=False)
    duration_minutes = db.Column(db.Integer, default=30)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# --- 8. BẢNG LỊCH HẸN KHÁM (Appointments) ---
class Appointment(db.Model):
    __tablename__ = 'appointments'
    id = db.Column(db.Integer, primary_key=True)
    appointment_code = db.Column(db.String(20), unique=True, nullable=False)
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'))
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'))
    department_id = db.Column(db.Integer, db.ForeignKey('departments.id'))
    service_id = db.Column(db.Integer, db.ForeignKey('services.id'))
    appointment_date = db.Column(db.Date, nullable=False)
    appointment_time = db.Column(db.Time, nullable=False)
    status = db.Column(db.String(20), default='pending')
    reason = db.Column(db.Text)
    symptoms = db.Column(db.Text)
    notes = db.Column(db.Text)
    cancellation_reason = db.Column(db.Text)
    cancelled_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    cancelled_at = db.Column(db.DateTime)
    checked_in_at = db.Column(db.DateTime)
    completed_at = db.Column(db.DateTime)
    reminder_sent = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(status.in_(['pending', 'confirmed', 'checked_in', 'completed', 'cancelled', 'no_show']), name='check_appointment_status'),
    )

    patient = db.relationship("Patient", backref="appointments")
    doctor = db.relationship("Doctor", backref="appointments")

# --- 9. BẢNG LỊCH SỬ THAY ĐỔI LỊCH HẸN (Appointment History) ---
class AppointmentHistory(db.Model):
    __tablename__ = 'appointment_history'
    id = db.Column(db.Integer, primary_key=True)
    appointment_id = db.Column(db.Integer, db.ForeignKey('appointments.id', ondelete='CASCADE'))
    changed_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    old_date = db.Column(db.Date)
    old_time = db.Column(db.Time)
    new_date = db.Column(db.Date)
    new_time = db.Column(db.Time)
    old_status = db.Column(db.String(20))
    new_status = db.Column(db.String(20))
    change_reason = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# --- 10. BẢNG HỒ SƠ KHÁM BỆNH (Medical Records) ---
class MedicalRecord(db.Model):
    __tablename__ = 'medical_records'
    id = db.Column(db.Integer, primary_key=True)
    record_code = db.Column(db.String(20), unique=True, nullable=False)
    appointment_id = db.Column(db.Integer, db.ForeignKey('appointments.id'))
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'))
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'))
    visit_date = db.Column(db.DateTime, nullable=False)
    diagnosis = db.Column(db.Text)
    symptoms = db.Column(db.Text)
    treatment = db.Column(db.Text)
    prescription = db.Column(db.Text)
    lab_results = db.Column(db.Text)
    notes = db.Column(db.Text)
    next_visit_date = db.Column(db.Date)
    is_follow_up = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    patient = db.relationship("Patient", backref="medical_records")

# --- 11. BẢNG ĐƠN THUỐC (Prescriptions) ---
class Prescription(db.Model):
    __tablename__ = 'prescriptions'
    id = db.Column(db.Integer, primary_key=True)
    medical_record_id = db.Column(db.Integer, db.ForeignKey('medical_records.id', ondelete='CASCADE'))
    medication_name = db.Column(db.String(200), nullable=False)
    dosage = db.Column(db.String(100))
    frequency = db.Column(db.String(100))
    duration = db.Column(db.String(100))
    quantity = db.Column(db.Integer)
    instructions = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# --- 12. BẢNG LỊCH TÁI KHÁM (Follow-up Reminders) ---
class FollowUpReminder(db.Model):
    __tablename__ = 'follow_up_reminders'
    id = db.Column(db.Integer, primary_key=True)
    medical_record_id = db.Column(db.Integer, db.ForeignKey('medical_records.id'))
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'))
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'))
    follow_up_date = db.Column(db.Date, nullable=False)
    reminder_date = db.Column(db.Date, nullable=False)
    message = db.Column(db.Text)
    is_sent = db.Column(db.Boolean, default=False)
    sent_at = db.Column(db.DateTime)
    status = db.Column(db.String(20), default='pending')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(status.in_(['pending', 'sent', 'scheduled', 'cancelled']), name='check_reminder_status'),
    )

# --- 13. BẢNG THANH TOÁN (Payments) ---
class Payment(db.Model):
    __tablename__ = 'payments'
    id = db.Column(db.Integer, primary_key=True)
    payment_code = db.Column(db.String(20), unique=True, nullable=False)
    appointment_id = db.Column(db.Integer, db.ForeignKey('appointments.id'))
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'))
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    payment_method = db.Column(db.String(50))
    payment_status = db.Column(db.String(20), default='pending')
    transaction_id = db.Column(db.String(100))
    payment_date = db.Column(db.DateTime)
    description = db.Column(db.Text)
    refund_reason = db.Column(db.Text)
    refunded_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(payment_method.in_(['cash', 'credit_card', 'momo', 'vnpay', 'zalopay', 'bank_transfer']), name='check_payment_method'),
        CheckConstraint(payment_status.in_(['pending', 'processing', 'completed', 'failed', 'refunded']), name='check_payment_status'),
    )

# --- 14. BẢNG CHI TIẾT THANH TOÁN (Payment Items) ---
class PaymentItem(db.Model):
    __tablename__ = 'payment_items'
    id = db.Column(db.Integer, primary_key=True)
    payment_id = db.Column(db.Integer, db.ForeignKey('payments.id', ondelete='CASCADE'))
    service_id = db.Column(db.Integer, db.ForeignKey('services.id'))
    description = db.Column(db.String(200))
    quantity = db.Column(db.Integer, default=1)
    unit_price = db.Column(db.Numeric(10, 2), nullable=False)
    total_price = db.Column(db.Numeric(10, 2), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# --- 15. BẢNG ĐÁNH GIÁ (Reviews) ---
class Review(db.Model):
    __tablename__ = 'reviews'
    id = db.Column(db.Integer, primary_key=True)
    appointment_id = db.Column(db.Integer, db.ForeignKey('appointments.id'))
    patient_id = db.Column(db.Integer, db.ForeignKey('patients.id'))
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'))
    rating = db.Column(db.Integer)
    service_rating = db.Column(db.Integer)
    facility_rating = db.Column(db.Integer)
    comment = db.Column(db.Text)
    is_anonymous = db.Column(db.Boolean, default=False)
    is_approved = db.Column(db.Boolean, default=False)
    approved_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    approved_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(rating.between(1, 5), name='check_rating_range'),
        CheckConstraint(service_rating.between(1, 5), name='check_service_rating_range'),
        CheckConstraint(facility_rating.between(1, 5), name='check_facility_rating_range'),
    )

# --- 16. BẢNG PHẢN HỒI (Feedback) ---
class Feedback(db.Model):
    __tablename__ = 'feedback'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    type = db.Column(db.String(50))
    subject = db.Column(db.String(200))
    message = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='pending')
    priority = db.Column(db.String(20), default='normal')
    assigned_to = db.Column(db.Integer, db.ForeignKey('users.id'))
    response = db.Column(db.Text)
    responded_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    responded_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(type.in_(['complaint', 'suggestion', 'compliment', 'question', 'other']), name='check_feedback_type'),
        CheckConstraint(status.in_(['pending', 'in_progress', 'resolved', 'closed']), name='check_feedback_status'),
        CheckConstraint(priority.in_(['low', 'normal', 'high', 'urgent']), name='check_feedback_priority'),
    )

# --- 17. BẢNG THÔNG BÁO (Notifications) ---
class Notification(db.Model):
    __tablename__ = 'notifications'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    type = db.Column(db.String(50))
    reference_id = db.Column(db.Integer)
    reference_type = db.Column(db.String(50))
    is_read = db.Column(db.Boolean, default=False)
    read_at = db.Column(db.DateTime)
    sent_via = db.Column(db.String(50))
    target_role = db.Column(db.String(50), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(type.in_(['appointment', 'reminder', 'payment', 'review', 'system', 'promotion']), name='check_notification_type'),
    )

# --- 18. BẢNG THIẾT BỊ (User Devices) ---
class UserDevice(db.Model):
    __tablename__ = 'user_devices'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    device_token = db.Column(db.String(255), unique=True, nullable=False)
    device_type = db.Column(db.String(20))
    device_name = db.Column(db.String(100))
    is_active = db.Column(db.Boolean, default=True)
    last_used = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(device_type.in_(['ios', 'android', 'web']), name='check_device_type'),
    )

# --- 19. BẢNG CẤU HÌNH HỆ THỐNG (System Settings) ---
class SystemSetting(db.Model):
    __tablename__ = 'system_settings'
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True, nullable=False)
    value = db.Column(db.Text)
    description = db.Column(db.Text)
    data_type = db.Column(db.String(20), default='string')
    updated_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        CheckConstraint(data_type.in_(['string', 'integer', 'boolean', 'json']), name='check_data_type'),
    )

# --- 20. BẢNG LOG HOẠT ĐỘNG (Activity Logs) ---
class ActivityLog(db.Model):
    __tablename__ = 'activity_logs'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    action = db.Column(db.String(100), nullable=False)
    entity_type = db.Column(db.String(50))
    entity_id = db.Column(db.Integer)
    description = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)