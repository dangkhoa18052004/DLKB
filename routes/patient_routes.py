from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (db, User, Patient, Appointment, MedicalRecord, 
                     Prescription, Payment, Review)
from utils import log_activity, get_patient_id_from_user, patient_required
from datetime import datetime
from sqlalchemy.exc import IntegrityError

patient_bp = Blueprint('patient', __name__)


@patient_bp.route('/profile', methods=['GET'])
@jwt_required()
@patient_required
def get_my_profile():
    """Lấy thông tin profile của bệnh nhân"""
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    patient = Patient.query.filter_by(user_id=user_id).first()
    
    if not patient:
        return jsonify({"msg": "Patient data not found"}), 404
    
    profile_data = {
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'full_name': user.full_name,
            'phone': user.phone,
            'date_of_birth': user.date_of_birth.strftime('%Y-%m-%d') if user.date_of_birth else None,
            'gender': user.gender,
            'address': user.address,
            'avatar_url': user.avatar_url
        },
        'patient': {
            'id': patient.id,
            'patient_code': patient.patient_code,
            'blood_type': patient.blood_type,
            'allergies': patient.allergies,
            'medical_notes': patient.medical_notes,
            'emergency_contact_name': patient.emergency_contact_name,
            'emergency_contact_phone': patient.emergency_contact_phone,
            'insurance_number': patient.insurance_number,
            'insurance_provider': patient.insurance_provider
        }
    }
    
    return jsonify(profile_data), 200

@patient_bp.route('/profile', methods=['PUT'])
@jwt_required()
@patient_required
def update_my_profile():
    """Cập nhật thông tin profile"""
    user_id = get_jwt_identity()
    current_app.logger.debug("UpdateProfile request for user_id=%s payload=%s", user_id, request.json)
    user = User.query.get_or_404(user_id)
    patient = Patient.query.filter_by(user_id=user_id).first()
    
    data = request.get_json()
    
    # Cập nhật User info
    if 'full_name' in data:
        user.full_name = data['full_name']
    if 'phone' in data:
        user.phone = data['phone']
    if 'email' in data:
        user.email = data['email']
    if 'date_of_birth' in data:
        user.date_of_birth = datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date()
    if 'gender' in data:
        # Normalize incoming gender to match DB CHECK constraint values: 'Nam','Nữ','Khác'
        raw_gender = data.get('gender')
        if isinstance(raw_gender, str):
            g = raw_gender.strip().lower()
            if g in ('male', 'm', 'nam', 'man'):
                user.gender = 'Nam'
            elif g in ('female', 'f', 'nu', 'nữ', 'woman'):
                user.gender = 'Nữ'
            elif g in ('other', 'khac', 'khác'):
                user.gender = 'Khác'
            else:
                # Unknown string: try to map common Vietnamese spellings, else title-case
                if 'nam' in g:
                    user.gender = 'Nam'
                elif 'nữ' in g or 'nu' in g:
                    user.gender = 'Nữ'
                elif 'kh' in g or 'khác' in g or 'khac' in g:
                    user.gender = 'Khác'
                else:
                    user.gender = raw_gender.strip().title()
        else:
            # non-string values: store as-is (will likely fail DB constraints)
            user.gender = raw_gender
    if 'address' in data:
        user.address = data['address']
    if 'avatar_url' in data:
        user.avatar_url = data['avatar_url']
    
    # Cập nhật Patient info
    if patient:
        if 'blood_type' in data:
            patient.blood_type = data['blood_type']
        if 'allergies' in data:
            patient.allergies = data['allergies']
        if 'medical_notes' in data:
            patient.medical_notes = data['medical_notes']
        if 'emergency_contact_name' in data:
            patient.emergency_contact_name = data['emergency_contact_name']
        if 'emergency_contact_phone' in data:
            patient.emergency_contact_phone = data['emergency_contact_phone']
        if 'insurance_number' in data:
            patient.insurance_number = data['insurance_number']
        if 'insurance_provider' in data:
            patient.insurance_provider = data['insurance_provider']
    
    # Kiểm tra trùng email / phone (loại trừ chính user hiện tại) trước khi commit
    new_email = data.get('email', user.email)
    new_phone = data.get('phone', user.phone)

    conflict = User.query.filter(
        ((User.email == new_email) | (User.phone == new_phone)),
        User.id != user_id
    ).first()

    if conflict:
        if conflict.email == new_email:
            return jsonify({"msg": "Email already exists"}), 409
        if conflict.phone == new_phone:
            return jsonify({"msg": "Phone already exists"}), 409
        return jsonify({"msg": "Email or Phone already exists"}), 409

    try:
        db.session.commit()
        log_activity(user_id, "UPDATE_PROFILE", "patient", patient.id if patient else None, "Updated patient profile")
        return jsonify({"msg": "Profile updated successfully"}), 200
    except IntegrityError as ie:
        db.session.rollback()
        current_app.logger.exception("IntegrityError when updating profile for user_id=%s", user_id)
        # Return the DB error message to aid debugging (trim/format as needed)
        return jsonify({"msg": f"Integrity error: {str(ie.orig) if hasattr(ie, 'orig') else str(ie)}"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating profile: {str(e)}"}), 500

@patient_bp.route('/change-password', methods=['PUT'])
@jwt_required()
@patient_required
def change_password():
    """Đổi mật khẩu"""
    user_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    data = request.get_json()
    
    current_password = data.get('current_password')
    new_password = data.get('new_password')
    confirm_password = data.get('confirm_password')
    
    if not all([current_password, new_password, confirm_password]):
        return jsonify({"msg": "All password fields are required"}), 400
    
    if not user.check_password(current_password):
        return jsonify({"msg": "Current password is incorrect"}), 401
    
    if new_password != confirm_password:
        return jsonify({"msg": "New passwords do not match"}), 400
    
    if len(new_password) < 6:
        return jsonify({"msg": "Password must be at least 6 characters"}), 400
    
    user.set_password(new_password)
    
    try:
        db.session.commit()
        log_activity(user_id, "CHANGE_PASSWORD", "user", user_id, "Password changed successfully")
        return jsonify({"msg": "Password changed successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error changing password: {str(e)}"}), 500

# =============================================
# APPOINTMENT MANAGEMENT
# =============================================

@patient_bp.route('/appointments/<int:appointment_id>/reschedule', methods=['PUT'])
@jwt_required()
@patient_required
def reschedule_appointment(appointment_id):
    """Thay đổi ngày giờ khám (reschedule)"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    appointment = Appointment.query.filter_by(id=appointment_id, patient_id=patient_id).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found or not owned by user"}), 404
    
    if appointment.status in ['completed', 'cancelled', 'no_show']:
        return jsonify({"msg": f"Cannot reschedule appointment with status: {appointment.status}"}), 400
    
    data = request.get_json()
    
    try:
        new_date = datetime.strptime(data['new_date'], '%Y-%m-%d').date()
        new_time = datetime.strptime(data['new_time'], '%H:%M').time()
    except (KeyError, ValueError):
        return jsonify({"msg": "Invalid date or time format"}), 400
    
    # Kiểm tra slot mới có trống không
    existing_appointment = Appointment.query.filter(
        Appointment.doctor_id == appointment.doctor_id,
        Appointment.appointment_date == new_date,
        Appointment.appointment_time == new_time,
        Appointment.status.in_(['pending', 'confirmed']),
        Appointment.id != appointment_id
    ).first()
    
    if existing_appointment:
        return jsonify({"msg": "This time slot is already booked"}), 409
    
    # Lưu lịch sử thay đổi (có thể tạo AppointmentHistory record)
    from models import AppointmentHistory
    history = AppointmentHistory(
        appointment_id=appointment.id,
        changed_by=user_id,
        old_date=appointment.appointment_date,
        old_time=appointment.appointment_time,
        new_date=new_date,
        new_time=new_time,
        old_status=appointment.status,
        new_status=appointment.status,
        change_reason=data.get('reason', 'Rescheduled by patient')
    )
    
    appointment.appointment_date = new_date
    appointment.appointment_time = new_time
    
    try:
        db.session.add(history)
        db.session.commit()
        log_activity(user_id, "RESCHEDULE_APPOINTMENT", "appointment", appointment.id, 
                    f"Rescheduled to {new_date} {new_time}")
        return jsonify({"msg": "Appointment rescheduled successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error rescheduling appointment: {str(e)}"}), 500

# =============================================
# MEDICAL RECORDS
# =============================================

@patient_bp.route('/medical-records', methods=['GET'])
@jwt_required()
@patient_required
def get_my_medical_records():
    """Lấy lịch sử khám bệnh"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    
    pagination = MedicalRecord.query.filter_by(patient_id=patient_id).order_by(
        MedicalRecord.visit_date.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for record in pagination.items:
        results.append({
            'id': record.id,
            'record_code': record.record_code,
            'visit_date': record.visit_date.strftime('%Y-%m-%d %H:%M'),
            'doctor_name': record.doctor.user.full_name if record.doctor else 'N/A',
            'diagnosis': record.diagnosis,
            'symptoms': record.symptoms,
            'treatment': record.treatment,
            'prescription': record.prescription,
            'lab_results': record.lab_results,
            'notes': record.notes,
            'next_visit_date': record.next_visit_date.strftime('%Y-%m-%d') if record.next_visit_date else None,
            'is_follow_up': record.is_follow_up
        })
    
    return jsonify({
        'medical_records': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@patient_bp.route('/medical-records/<int:record_id>', methods=['GET'])
@jwt_required()
@patient_required
def get_medical_record_detail(record_id):
    """Lấy chi tiết một hồ sơ khám bệnh"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    record = MedicalRecord.query.filter_by(id=record_id, patient_id=patient_id).first()
    
    if not record:
        return jsonify({"msg": "Medical record not found"}), 404
    
    # Lấy danh sách đơn thuốc
    prescriptions = Prescription.query.filter_by(medical_record_id=record.id).all()
    
    prescription_list = []
    for presc in prescriptions:
        prescription_list.append({
            'id': presc.id,
            'medication_name': presc.medication_name,
            'dosage': presc.dosage,
            'frequency': presc.frequency,
            'duration': presc.duration,
            'quantity': presc.quantity,
            'instructions': presc.instructions
        })
    
    record_data = {
        'id': record.id,
        'record_code': record.record_code,
        'visit_date': record.visit_date.strftime('%Y-%m-%d %H:%M'),
        'doctor_name': record.doctor.user.full_name if record.doctor else 'N/A',
        'doctor_specialization': record.doctor.specialization if record.doctor else 'N/A',
        'diagnosis': record.diagnosis,
        'symptoms': record.symptoms,
        'treatment': record.treatment,
        'lab_results': record.lab_results,
        'notes': record.notes,
        'next_visit_date': record.next_visit_date.strftime('%Y-%m-%d') if record.next_visit_date else None,
        'is_follow_up': record.is_follow_up,
        'prescriptions': prescription_list
    }
    
    return jsonify(record_data), 200

# =============================================
# PRESCRIPTIONS
# =============================================

@patient_bp.route('/prescriptions', methods=['GET'])
@jwt_required()
@patient_required
def get_my_prescriptions():
    """Lấy danh sách đơn thuốc"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    # Lấy tất cả medical records của patient
    records = MedicalRecord.query.filter_by(patient_id=patient_id).all()
    record_ids = [r.id for r in records]
    
    prescriptions = Prescription.query.filter(
        Prescription.medical_record_id.in_(record_ids)
    ).order_by(Prescription.created_at.desc()).all()
    
    results = []
    for presc in prescriptions:
        record = MedicalRecord.query.get(presc.medical_record_id)
        results.append({
            'id': presc.id,
            'medical_record_code': record.record_code if record else 'N/A',
            'visit_date': record.visit_date.strftime('%Y-%m-%d') if record else 'N/A',
            'medication_name': presc.medication_name,
            'dosage': presc.dosage,
            'frequency': presc.frequency,
            'duration': presc.duration,
            'quantity': presc.quantity,
            'instructions': presc.instructions,
            'prescribed_date': presc.created_at.strftime('%Y-%m-%d')
        })
    
    return jsonify(results), 200

# =============================================
# PAYMENT HISTORY
# =============================================

@patient_bp.route('/payments', methods=['GET'])
@jwt_required()
@patient_required
def get_my_payments():
    """Lấy lịch sử thanh toán"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    
    pagination = Payment.query.filter_by(patient_id=patient_id).order_by(
        Payment.created_at.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for payment in pagination.items:
        results.append({
            'id': payment.id,
            'payment_code': payment.payment_code,
            'amount': str(payment.amount),
            'payment_method': payment.payment_method,
            'payment_status': payment.payment_status,
            'payment_date': payment.payment_date.strftime('%Y-%m-%d %H:%M:%S') if payment.payment_date else None,
            'description': payment.description,
            'created_at': payment.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'payments': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@patient_bp.route('/payments/<int:payment_id>', methods=['GET'])
@jwt_required()
@patient_required
def get_payment_detail(payment_id):
    """Lấy chi tiết thanh toán"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    payment = Payment.query.filter_by(id=payment_id, patient_id=patient_id).first()
    
    if not payment:
        return jsonify({"msg": "Payment not found"}), 404
    
    # Lấy payment items
    from models import PaymentItem
    items = PaymentItem.query.filter_by(payment_id=payment.id).all()
    
    item_list = []
    for item in items:
        item_list.append({
            'description': item.description,
            'quantity': item.quantity,
            'unit_price': str(item.unit_price),
            'total_price': str(item.total_price)
        })
    
    payment_data = {
        'id': payment.id,
        'payment_code': payment.payment_code,
        'amount': str(payment.amount),
        'payment_method': payment.payment_method,
        'payment_status': payment.payment_status,
        'transaction_id': payment.transaction_id,
        'payment_date': payment.payment_date.strftime('%Y-%m-%d %H:%M:%S') if payment.payment_date else None,
        'description': payment.description,
        'items': item_list,
        'created_at': payment.created_at.strftime('%Y-%m-%d %H:%M:%S')
    }
    
    return jsonify(payment_data), 200

# REVIEWS

@patient_bp.route('/reviews/my', methods=['GET'])
@jwt_required()
@patient_required
def get_my_reviews():
    """Lấy danh sách đánh giá của tôi"""
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    reviews = Review.query.filter_by(patient_id=patient_id).order_by(
        Review.created_at.desc()
    ).all()
    
    results = []
    for review in reviews:
        appointment = Appointment.query.get(review.appointment_id)
        results.append({
            'id': review.id,
            'appointment_code': appointment.appointment_code if appointment else 'N/A',
            'doctor_name': review.doctor.user.full_name if review.doctor and review.doctor.user else 'N/A',
            'rating': review.rating,
            'service_rating': review.service_rating,
            'facility_rating': review.facility_rating,
            'comment': review.comment,
            'is_approved': review.is_approved,
            'created_at': review.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify(results), 200