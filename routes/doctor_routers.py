from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (db, User, Doctor, Appointment, MedicalRecord, 
                     Prescription, DoctorSchedule, DoctorLeave, Patient,
                     FollowUpReminder)
from utils import log_activity, generate_code, doctor_required, get_doctor_id_from_user
from datetime import datetime, date, timedelta
from sqlalchemy.exc import IntegrityError

doctor_bp = Blueprint('doctor', __name__)

# =============================================
# DOCTOR PROFILE
# =============================================

@doctor_bp.route('/profile', methods=['GET'])
@jwt_required()
@doctor_required
def get_my_doctor_profile():
    """Lấy thông tin profile bác sĩ"""
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    doctor = Doctor.query.filter_by(user_id=user_id).first()
    
    if not doctor:
        return jsonify({"msg": "Doctor data not found"}), 404
    
    profile_data = {
        'user': {
            'id': user.id,
            'full_name': user.full_name,
            'email': user.email,
            'phone': user.phone,
            'avatar_url': user.avatar_url
        },
        'doctor': {
            'id': doctor.id,
            'license_number': doctor.license_number,
            'specialization': doctor.specialization,
            'department_id': doctor.department_id,
            'experience_years': doctor.experience_years,
            'education': doctor.education,
            'certificates': doctor.certificates,
            'bio': doctor.bio,
            'consultation_fee': str(doctor.consultation_fee),
            'rating': float(doctor.rating),
            'total_reviews': doctor.total_reviews,
            'is_available': doctor.is_available
        }
    }
    
    return jsonify(profile_data), 200

@doctor_bp.route('/profile', methods=['PUT'])
@jwt_required()
@doctor_required
def update_my_doctor_profile():
    """Cập nhật thông tin profile bác sĩ"""
    user_id = get_jwt_identity()
    doctor = Doctor.query.filter_by(user_id=user_id).first()
    
    if not doctor:
        return jsonify({"msg": "Doctor data not found"}), 404
    
    data = request.get_json()
    
    # Cập nhật Doctor info
    if 'specialization' in data:
        doctor.specialization = data['specialization']
    if 'experience_years' in data:
        doctor.experience_years = data['experience_years']
    if 'education' in data:
        doctor.education = data['education']
    if 'certificates' in data:
        doctor.certificates = data['certificates']
    if 'bio' in data:
        doctor.bio = data['bio']
    if 'consultation_fee' in data:
        doctor.consultation_fee = data['consultation_fee']
    if 'is_available' in data:
        doctor.is_available = data['is_available']
    
    try:
        db.session.commit()
        log_activity(user_id, "UPDATE_DOCTOR_PROFILE", "doctor", doctor.id, "Updated doctor profile")
        return jsonify({"msg": "Profile updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating profile: {str(e)}"}), 500

# =============================================
# APPOINTMENTS MANAGEMENT
# =============================================

@doctor_bp.route('/appointments', methods=['GET'])
@jwt_required()
@doctor_required
def get_my_appointments():
    """Lấy danh sách lịch hẹn của bác sĩ"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    date_filter = request.args.get('date')
    status = request.args.get('status')
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    query = Appointment.query.filter_by(doctor_id=doctor_id)
    
    if date_filter:
        try:
            filter_date = datetime.strptime(date_filter, '%Y-%m-%d').date()
            query = query.filter_by(appointment_date=filter_date)
        except ValueError:
            return jsonify({"msg": "Invalid date format"}), 400
    
    if status:
        query = query.filter_by(status=status)
    
    pagination = query.order_by(
        Appointment.appointment_date.asc(), 
        Appointment.appointment_time.asc()
    ).paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for app in pagination.items:
        patient_user = app.patient.user if app.patient else None
        results.append({
            'id': app.id,
            'appointment_code': app.appointment_code,
            'patient_name': patient_user.full_name if patient_user else 'N/A',
            'patient_phone': patient_user.phone if patient_user else 'N/A',
            'patient_code': app.patient.patient_code if app.patient else 'N/A',
            'appointment_date': app.appointment_date.strftime('%Y-%m-%d'),
            'appointment_time': app.appointment_time.strftime('%H:%M'),
            'status': app.status,
            'reason': app.reason,
            'symptoms': app.symptoms,
            'notes': app.notes
        })
    
    return jsonify({
        'appointments': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@doctor_bp.route('/appointments/<int:appointment_id>', methods=['GET'])
@jwt_required()
@doctor_required
def get_appointment_detail(appointment_id):
    """Lấy chi tiết lịch hẹn"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    appointment = Appointment.query.filter_by(id=appointment_id, doctor_id=doctor_id).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found"}), 404
    
    patient = appointment.patient
    patient_user = patient.user if patient else None
    
    appointment_data = {
        'id': appointment.id,
        'appointment_code': appointment.appointment_code,
        'appointment_date': appointment.appointment_date.strftime('%Y-%m-%d'),
        'appointment_time': appointment.appointment_time.strftime('%H:%M'),
        'status': appointment.status,
        'reason': appointment.reason,
        'symptoms': appointment.symptoms,
        'notes': appointment.notes,
        'patient': {
            'id': patient.id if patient else None,
            'patient_code': patient.patient_code if patient else 'N/A',
            'full_name': patient_user.full_name if patient_user else 'N/A',
            'phone': patient_user.phone if patient_user else 'N/A',
            'date_of_birth': patient_user.date_of_birth.strftime('%Y-%m-%d') if patient_user and patient_user.date_of_birth else None,
            'gender': patient_user.gender if patient_user else 'N/A',
            'blood_type': patient.blood_type if patient else None,
            'allergies': patient.allergies if patient else None,
            'medical_notes': patient.medical_notes if patient else None
        }
    }
    
    return jsonify(appointment_data), 200

@doctor_bp.route('/appointments/<int:appointment_id>/check-in', methods=['PUT'])
@jwt_required()
@doctor_required
def check_in_appointment(appointment_id):
    """Check-in bệnh nhân"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    appointment = Appointment.query.filter_by(id=appointment_id, doctor_id=doctor_id).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found"}), 404
    
    if appointment.status != 'confirmed':
        return jsonify({"msg": f"Cannot check-in appointment with status: {appointment.status}"}), 400
    
    appointment.status = 'checked_in'
    appointment.checked_in_at = datetime.utcnow()
    
    try:
        db.session.commit()
        log_activity(user_id, "CHECK_IN_APPOINTMENT", "appointment", appointment.id, 
                    f"Checked in appointment: {appointment.appointment_code}")
        return jsonify({"msg": "Patient checked in successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error checking in: {str(e)}"}), 500

# =============================================
# MEDICAL RECORDS
# =============================================

@doctor_bp.route('/medical-records', methods=['POST'])
@jwt_required()
@doctor_required
def create_medical_record():
    """Tạo hồ sơ khám bệnh sau khi khám"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    data = request.get_json()
    
    required_fields = ['appointment_id', 'patient_id', 'diagnosis']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    # Kiểm tra appointment có thuộc bác sĩ này không
    appointment = Appointment.query.filter_by(
        id=data['appointment_id'], 
        doctor_id=doctor_id
    ).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found or not assigned to you"}), 404
    
    if appointment.status not in ['checked_in', 'completed']:
        return jsonify({"msg": "Appointment must be checked-in first"}), 400
    
    # Tạo medical record
    record_code = generate_code(prefix='MR', length=10)
    
    new_record = MedicalRecord(
        record_code=record_code,
        appointment_id=data['appointment_id'],
        patient_id=data['patient_id'],
        doctor_id=doctor_id,
        visit_date=datetime.utcnow(),
        diagnosis=data['diagnosis'],
        symptoms=data.get('symptoms'),
        treatment=data.get('treatment'),
        prescription=data.get('prescription'),
        lab_results=data.get('lab_results'),
        notes=data.get('notes'),
        next_visit_date=datetime.strptime(data['next_visit_date'], '%Y-%m-%d').date() if data.get('next_visit_date') else None,
        is_follow_up=data.get('is_follow_up', False)
    )
    
    # Cập nhật appointment status thành completed
    appointment.status = 'completed'
    appointment.completed_at = datetime.utcnow()
    
    try:
        db.session.add(new_record)
        db.session.commit()
        log_activity(user_id, "CREATE_MEDICAL_RECORD", "medical_record", new_record.id, 
                    f"Created medical record: {record_code}")
        
        return jsonify({
            "msg": "Medical record created successfully",
            "record_id": new_record.id,
            "record_code": record_code
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating medical record: {str(e)}"}), 500

@doctor_bp.route('/medical-records/<int:record_id>', methods=['PUT'])
@jwt_required()
@doctor_required
def update_medical_record(record_id):
    """Cập nhật hồ sơ khám bệnh"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    record = MedicalRecord.query.filter_by(id=record_id, doctor_id=doctor_id).first()
    
    if not record:
        return jsonify({"msg": "Medical record not found or not authorized"}), 404
    
    data = request.get_json()
    
    if 'diagnosis' in data:
        record.diagnosis = data['diagnosis']
    if 'symptoms' in data:
        record.symptoms = data['symptoms']
    if 'treatment' in data:
        record.treatment = data['treatment']
    if 'prescription' in data:
        record.prescription = data['prescription']
    if 'lab_results' in data:
        record.lab_results = data['lab_results']
    if 'notes' in data:
        record.notes = data['notes']
    if 'next_visit_date' in data:
        record.next_visit_date = datetime.strptime(data['next_visit_date'], '%Y-%m-%d').date()
    if 'is_follow_up' in data:
        record.is_follow_up = data['is_follow_up']
    
    try:
        db.session.commit()
        log_activity(user_id, "UPDATE_MEDICAL_RECORD", "medical_record", record.id, 
                    f"Updated medical record: {record.record_code}")
        return jsonify({"msg": "Medical record updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating medical record: {str(e)}"}), 500

# =============================================
# PRESCRIPTIONS
# =============================================

@doctor_bp.route('/prescriptions', methods=['POST'])
@jwt_required()
@doctor_required
def create_prescription():
    """Kê đơn thuốc"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    data = request.get_json()
    
    required_fields = ['medical_record_id', 'medication_name', 'dosage', 'frequency']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    # Kiểm tra medical record có thuộc bác sĩ này không
    record = MedicalRecord.query.filter_by(
        id=data['medical_record_id'],
        doctor_id=doctor_id
    ).first()
    
    if not record:
        return jsonify({"msg": "Medical record not found or not authorized"}), 404
    
    new_prescription = Prescription(
        medical_record_id=data['medical_record_id'],
        medication_name=data['medication_name'],
        dosage=data['dosage'],
        frequency=data['frequency'],
        duration=data.get('duration'),
        quantity=data.get('quantity'),
        instructions=data.get('instructions')
    )
    
    try:
        db.session.add(new_prescription)
        db.session.commit()
        log_activity(user_id, "CREATE_PRESCRIPTION", "prescription", new_prescription.id, 
                    f"Created prescription for MR: {record.record_code}")
        
        return jsonify({
            "msg": "Prescription created successfully",
            "prescription_id": new_prescription.id
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating prescription: {str(e)}"}), 500

@doctor_bp.route('/prescriptions/bulk', methods=['POST'])
@jwt_required()
@doctor_required
def create_bulk_prescriptions():
    """Kê nhiều đơn thuốc cùng lúc"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    data = request.get_json()
    
    medical_record_id = data.get('medical_record_id')
    medications = data.get('medications', [])
    
    if not medical_record_id or not medications:
        return jsonify({"msg": "medical_record_id and medications list are required"}), 400
    
    # Kiểm tra medical record
    record = MedicalRecord.query.filter_by(
        id=medical_record_id,
        doctor_id=doctor_id
    ).first()
    
    if not record:
        return jsonify({"msg": "Medical record not found or not authorized"}), 404
    
    prescriptions = []
    for med in medications:
        prescription = Prescription(
            medical_record_id=medical_record_id,
            medication_name=med.get('medication_name'),
            dosage=med.get('dosage'),
            frequency=med.get('frequency'),
            duration=med.get('duration'),
            quantity=med.get('quantity'),
            instructions=med.get('instructions')
        )
        prescriptions.append(prescription)
    
    try:
        db.session.add_all(prescriptions)
        db.session.commit()
        log_activity(user_id, "CREATE_BULK_PRESCRIPTIONS", "prescription", medical_record_id, 
                    f"Created {len(prescriptions)} prescriptions for MR: {record.record_code}")
        
        return jsonify({
            "msg": f"{len(prescriptions)} prescriptions created successfully"
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating prescriptions: {str(e)}"}), 500

# =============================================
# SCHEDULE MANAGEMENT
# =============================================

@doctor_bp.route('/schedules', methods=['GET'])
@jwt_required()
@doctor_required
def get_my_schedules():
    """Lấy lịch làm việc của bác sĩ"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    schedules = DoctorSchedule.query.filter_by(doctor_id=doctor_id).order_by(
        DoctorSchedule.day_of_week, DoctorSchedule.start_time
    ).all()
    
    results = []
    day_names = ['Chủ Nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7']
    
    for schedule in schedules:
        results.append({
            'id': schedule.id,
            'day_of_week': schedule.day_of_week,
            'day_name': day_names[schedule.day_of_week],
            'start_time': schedule.start_time.strftime('%H:%M'),
            'end_time': schedule.end_time.strftime('%H:%M'),
            'max_patients': schedule.max_patients,
            'is_active': schedule.is_active
        })
    
    return jsonify(results), 200

@doctor_bp.route('/schedules', methods=['POST'])
@jwt_required()
@doctor_required
def create_schedule():
    """Tạo lịch làm việc mới"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    data = request.get_json()
    
    required_fields = ['day_of_week', 'start_time', 'end_time']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    try:
        start_time = datetime.strptime(data['start_time'], '%H:%M').time()
        end_time = datetime.strptime(data['end_time'], '%H:%M').time()
    except ValueError:
        return jsonify({"msg": "Invalid time format. Use HH:MM"}), 400
    
    # Kiểm tra trùng lặp
    existing = DoctorSchedule.query.filter_by(
        doctor_id=doctor_id,
        day_of_week=data['day_of_week'],
        start_time=start_time
    ).first()
    
    if existing:
        return jsonify({"msg": "Schedule already exists for this time slot"}), 409
    
    new_schedule = DoctorSchedule(
        doctor_id=doctor_id,
        day_of_week=data['day_of_week'],
        start_time=start_time,
        end_time=end_time,
        max_patients=data.get('max_patients', 20),
        is_active=data.get('is_active', True)
    )
    
    try:
        db.session.add(new_schedule)
        db.session.commit()
        log_activity(user_id, "CREATE_SCHEDULE", "doctor_schedule", new_schedule.id, 
                    f"Created schedule for day {data['day_of_week']}")
        
        return jsonify({
            "msg": "Schedule created successfully",
            "schedule_id": new_schedule.id
        }), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Schedule conflict"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating schedule: {str(e)}"}), 500

@doctor_bp.route('/schedules/<int:schedule_id>', methods=['DELETE'])
@jwt_required()
@doctor_required
def delete_schedule(schedule_id):
    """Xóa lịch làm việc"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    schedule = DoctorSchedule.query.filter_by(id=schedule_id, doctor_id=doctor_id).first()
    
    if not schedule:
        return jsonify({"msg": "Schedule not found"}), 404
    
    try:
        db.session.delete(schedule)
        db.session.commit()
        log_activity(user_id, "DELETE_SCHEDULE", "doctor_schedule", schedule_id, 
                    f"Deleted schedule ID: {schedule_id}")
        return jsonify({"msg": "Schedule deleted successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error deleting schedule: {str(e)}"}), 500

# =============================================
# LEAVE MANAGEMENT
# =============================================

@doctor_bp.route('/leaves', methods=['POST'])
@jwt_required()
@doctor_required
def register_leave():
    """Đăng ký ngày nghỉ"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    data = request.get_json()
    
    if not data.get('leave_date'):
        return jsonify({"msg": "leave_date is required"}), 400
    
    try:
        leave_date = datetime.strptime(data['leave_date'], '%Y-%m-%d').date()
    except ValueError:
        return jsonify({"msg": "Invalid date format"}), 400
    
    new_leave = DoctorLeave(
        doctor_id=doctor_id,
        leave_date=leave_date,
        start_time=datetime.strptime(data['start_time'], '%H:%M').time() if data.get('start_time') else None,
        end_time=datetime.strptime(data['end_time'], '%H:%M').time() if data.get('end_time') else None,
        reason=data.get('reason'),
        is_full_day=data.get('is_full_day', True)
    )
    
    try:
        db.session.add(new_leave)
        db.session.commit()
        log_activity(user_id, "REGISTER_LEAVE", "doctor_leave", new_leave.id, 
                    f"Registered leave for {leave_date}")
        
        return jsonify({
            "msg": "Leave registered successfully",
            "leave_id": new_leave.id
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error registering leave: {str(e)}"}), 500

@doctor_bp.route('/leaves', methods=['GET'])
@jwt_required()
@doctor_required
def get_my_leaves():
    """Lấy danh sách ngày nghỉ"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    
    leaves = DoctorLeave.query.filter_by(doctor_id=doctor_id).order_by(
        DoctorLeave.leave_date.desc()
    ).all()
    
    results = []
    for leave in leaves:
        results.append({
            'id': leave.id,
            'leave_date': leave.leave_date.strftime('%Y-%m-%d'),
            'start_time': leave.start_time.strftime('%H:%M') if leave.start_time else None,
            'end_time': leave.end_time.strftime('%H:%M') if leave.end_time else None,
            'reason': leave.reason,
            'is_full_day': leave.is_full_day
        })
    
    return jsonify(results), 200

# FOLLOW-UP REMINDERS

@doctor_bp.route('/follow-up-reminders', methods=['POST'])
@jwt_required()
@doctor_required
def create_follow_up_reminder():
    """Tạo lịch nhắc tái khám"""
    user_id = get_jwt_identity()
    doctor_id = get_doctor_id_from_user(user_id)
    data = request.get_json()
    
    required_fields = ['medical_record_id', 'patient_id', 'follow_up_date']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    try:
        follow_up_date = datetime.strptime(data['follow_up_date'], '%Y-%m-%d').date()
        reminder_date = datetime.strptime(data['reminder_date'], '%Y-%m-%d').date() if data.get('reminder_date') else follow_up_date - timedelta(days=1)
    except ValueError:
        return jsonify({"msg": "Invalid date format"}), 400
    
    new_reminder = FollowUpReminder(
        medical_record_id=data['medical_record_id'],
        patient_id=data['patient_id'],
        doctor_id=doctor_id,
        follow_up_date=follow_up_date,
        reminder_date=reminder_date,
        message=data.get('message', 'Nhắc lịch tái khám'),
        status='pending'
    )
    
    try:
        db.session.add(new_reminder)
        db.session.commit()
        log_activity(user_id, "CREATE_FOLLOW_UP_REMINDER", "follow_up_reminder", new_reminder.id, 
                    f"Created follow-up reminder for {follow_up_date}")
        
        return jsonify({
            "msg": "Follow-up reminder created successfully",
            "reminder_id": new_reminder.id
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating reminder: {str(e)}"}), 500