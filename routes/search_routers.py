from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (db, User, Doctor, Patient, Appointment, MedicalRecord, 
                     Department, Service, Payment)
from sqlalchemy import or_, and_, func
from datetime import datetime

search_bp = Blueprint('search', __name__)

# =============================================
# GLOBAL SEARCH (ADMIN)
# =============================================

@search_bp.route('/global', methods=['GET'])
@jwt_required()
def global_search():
    """Tìm kiếm toàn cục - Admin"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role not in ['admin', 'staff']:
        return jsonify({"msg": "Permission denied"}), 403
    
    query = request.args.get('q', '').strip()
    search_type = request.args.get('type', 'all')  # all, patient, doctor, appointment
    
    if not query or len(query) < 2:
        return jsonify({"msg": "Search query must be at least 2 characters"}), 400
    
    results = {
        'query': query,
        'patients': [],
        'doctors': [],
        'appointments': [],
        'medical_records': []
    }
    
    search_pattern = f'%{query}%'
    
    # Tìm kiếm Patients
    if search_type in ['all', 'patient']:
        patients = Patient.query.join(User).filter(
            or_(
                User.full_name.ilike(search_pattern),
                User.email.ilike(search_pattern),
                User.phone.ilike(search_pattern),
                Patient.patient_code.ilike(search_pattern)
            )
        ).limit(10).all()
        
        for patient in patients:
            results['patients'].append({
                'id': patient.id,
                'patient_code': patient.patient_code,
                'full_name': patient.user.full_name,
                'email': patient.user.email,
                'phone': patient.user.phone
            })
    
    # Tìm kiếm Doctors
    if search_type in ['all', 'doctor']:
        doctors = Doctor.query.join(User).filter(
            or_(
                User.full_name.ilike(search_pattern),
                User.email.ilike(search_pattern),
                Doctor.specialization.ilike(search_pattern),
                Doctor.license_number.ilike(search_pattern)
            )
        ).limit(10).all()
        
        for doctor in doctors:
            results['doctors'].append({
                'id': doctor.id,
                'full_name': doctor.user.full_name,
                'specialization': doctor.specialization,
                'license_number': doctor.license_number,
                'email': doctor.user.email
            })
    
    # Tìm kiếm Appointments
    if search_type in ['all', 'appointment']:
        appointments = Appointment.query.filter(
            Appointment.appointment_code.ilike(search_pattern)
        ).limit(10).all()
        
        for appointment in appointments:
            results['appointments'].append({
                'id': appointment.id,
                'appointment_code': appointment.appointment_code,
                'patient_name': appointment.patient.user.full_name if appointment.patient else 'N/A',
                'doctor_name': appointment.doctor.user.full_name if appointment.doctor else 'N/A',
                'appointment_date': appointment.appointment_date.strftime('%Y-%m-%d'),
                'status': appointment.status
            })
    
    # Tìm kiếm Medical Records
    if search_type in ['all', 'medical_record']:
        records = MedicalRecord.query.filter(
            or_(
                MedicalRecord.record_code.ilike(search_pattern),
                MedicalRecord.diagnosis.ilike(search_pattern)
            )
        ).limit(10).all()
        
        for record in records:
            results['medical_records'].append({
                'id': record.id,
                'record_code': record.record_code,
                'patient_name': record.patient.user.full_name if record.patient else 'N/A',
                'diagnosis': record.diagnosis,
                'visit_date': record.visit_date.strftime('%Y-%m-%d')
            })
    
    return jsonify(results), 200

# =============================================
# PATIENT SEARCH
# =============================================

@search_bp.route('/patients', methods=['GET'])
@jwt_required()
def search_patients():
    """Tìm kiếm bệnh nhân nâng cao"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role not in ['admin', 'doctor', 'staff']:
        return jsonify({"msg": "Permission denied"}), 403
    
    # Các filters
    name = request.args.get('name')
    phone = request.args.get('phone')
    email = request.args.get('email')
    patient_code = request.args.get('patient_code')
    blood_type = request.args.get('blood_type')
    gender = request.args.get('gender')
    age_from = request.args.get('age_from', type=int)
    age_to = request.args.get('age_to', type=int)
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    query = Patient.query.join(User)
    
    if name:
        query = query.filter(User.full_name.ilike(f'%{name}%'))
    
    if phone:
        query = query.filter(User.phone.ilike(f'%{phone}%'))
    
    if email:
        query = query.filter(User.email.ilike(f'%{email}%'))
    
    if patient_code:
        query = query.filter(Patient.patient_code.ilike(f'%{patient_code}%'))
    
    if blood_type:
        query = query.filter(Patient.blood_type == blood_type)
    
    if gender:
        query = query.filter(User.gender == gender)
    
    # Lọc theo tuổi (nếu có date_of_birth)
    if age_from or age_to:
        today = datetime.now().date()
        
        if age_from:
            birth_year_max = today.year - age_from
            query = query.filter(func.extract('year', User.date_of_birth) <= birth_year_max)
        
        if age_to:
            birth_year_min = today.year - age_to
            query = query.filter(func.extract('year', User.date_of_birth) >= birth_year_min)
    
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for patient in pagination.items:
        age = None
        if patient.user.date_of_birth:
            today = datetime.now().date()
            age = today.year - patient.user.date_of_birth.year
        
        results.append({
            'id': patient.id,
            'patient_code': patient.patient_code,
            'full_name': patient.user.full_name,
            'email': patient.user.email,
            'phone': patient.user.phone,
            'gender': patient.user.gender,
            'age': age,
            'blood_type': patient.blood_type
        })
    
    return jsonify({
        'patients': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

# =============================================
# APPOINTMENT SEARCH
# =============================================

@search_bp.route('/appointments', methods=['GET'])
@jwt_required()
def search_appointments():
    """Tìm kiếm lịch hẹn nâng cao"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role not in ['admin', 'doctor', 'staff']:
        return jsonify({"msg": "Permission denied"}), 403
    
    # Filters
    appointment_code = request.args.get('appointment_code')
    patient_name = request.args.get('patient_name')
    doctor_name = request.args.get('doctor_name')
    department_id = request.args.get('department_id', type=int)
    status = request.args.get('status')
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    query = Appointment.query
    
    if appointment_code:
        query = query.filter(Appointment.appointment_code.ilike(f'%{appointment_code}%'))
    
    if patient_name:
        query = query.join(Patient).join(User, Patient.user_id == User.id).filter(
            User.full_name.ilike(f'%{patient_name}%')
        )
    
    if doctor_name:
        query = query.join(Doctor).join(User, Doctor.user_id == User.id).filter(
            User.full_name.ilike(f'%{doctor_name}%')
        )
    
    if department_id:
        query = query.filter(Appointment.department_id == department_id)
    
    if status:
        query = query.filter(Appointment.status == status)
    
    if date_from:
        try:
            query = query.filter(
                Appointment.appointment_date >= datetime.strptime(date_from, '%Y-%m-%d').date()
            )
        except ValueError:
            pass
    
    if date_to:
        try:
            query = query.filter(
                Appointment.appointment_date <= datetime.strptime(date_to, '%Y-%m-%d').date()
            )
        except ValueError:
            pass
    
    pagination = query.order_by(
        Appointment.appointment_date.desc(),
        Appointment.appointment_time.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for appointment in pagination.items:
        results.append({
            'id': appointment.id,
            'appointment_code': appointment.appointment_code,
            'patient_name': appointment.patient.user.full_name if appointment.patient else 'N/A',
            'doctor_name': appointment.doctor.user.full_name if appointment.doctor else 'N/A',
            'appointment_date': appointment.appointment_date.strftime('%Y-%m-%d'),
            'appointment_time': appointment.appointment_time.strftime('%H:%M'),
            'status': appointment.status,
            'department_id': appointment.department_id
        })
    
    return jsonify({
        'appointments': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

# =============================================
# MEDICAL RECORDS SEARCH
# =============================================

@search_bp.route('/medical-records', methods=['GET'])
@jwt_required()
def search_medical_records():
    """Tìm kiếm hồ sơ bệnh án nâng cao"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role not in ['admin', 'doctor', 'staff']:
        return jsonify({"msg": "Permission denied"}), 403
    
    # Filters
    patient_name = request.args.get('patient_name')
    doctor_name = request.args.get('doctor_name')
    diagnosis = request.args.get('diagnosis')
    record_code = request.args.get('record_code')
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    query = MedicalRecord.query
    
    if record_code:
        query = query.filter(MedicalRecord.record_code.ilike(f'%{record_code}%'))
    
    if patient_name:
        query = query.join(Patient).join(User, Patient.user_id == User.id).filter(
            User.full_name.ilike(f'%{patient_name}%')
        )
    
    if doctor_name:
        query = query.join(Doctor).join(User, Doctor.user_id == User.id).filter(
            User.full_name.ilike(f'%{doctor_name}%')
        )
    
    if diagnosis:
        query = query.filter(MedicalRecord.diagnosis.ilike(f'%{diagnosis}%'))
    
    if date_from:
        try:
            query = query.filter(
                MedicalRecord.visit_date >= datetime.strptime(date_from, '%Y-%m-%d')
            )
        except ValueError:
            pass
    
    if date_to:
        try:
            query = query.filter(
                MedicalRecord.visit_date <= datetime.strptime(date_to, '%Y-%m-%d')
            )
        except ValueError:
            pass
    
    pagination = query.order_by(
        MedicalRecord.visit_date.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for record in pagination.items:
        results.append({
            'id': record.id,
            'record_code': record.record_code,
            'patient_name': record.patient.user.full_name if record.patient else 'N/A',
            'doctor_name': record.doctor.user.full_name if record.doctor else 'N/A',
            'diagnosis': record.diagnosis,
            'visit_date': record.visit_date.strftime('%Y-%m-%d %H:%M'),
            'next_visit_date': record.next_visit_date.strftime('%Y-%m-%d') if record.next_visit_date else None
        })
    
    return jsonify({
        'medical_records': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

# =============================================
# PAYMENTS SEARCH
# =============================================

@search_bp.route('/payments', methods=['GET'])
@jwt_required()
def search_payments():
    """Tìm kiếm thanh toán nâng cao"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role not in ['admin', 'staff']:
        return jsonify({"msg": "Permission denied"}), 403
    
    # Filters
    payment_code = request.args.get('payment_code')
    patient_name = request.args.get('patient_name')
    payment_method = request.args.get('payment_method')
    payment_status = request.args.get('payment_status')
    amount_from = request.args.get('amount_from', type=float)
    amount_to = request.args.get('amount_to', type=float)
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    
    query = Payment.query
    
    if payment_code:
        query = query.filter(Payment.payment_code.ilike(f'%{payment_code}%'))
    
    if patient_name:
        query = query.join(Patient).join(User, Patient.user_id == User.id).filter(
            User.full_name.ilike(f'%{patient_name}%')
        )
    
    if payment_method:
        query = query.filter(Payment.payment_method == payment_method)
    
    if payment_status:
        query = query.filter(Payment.payment_status == payment_status)
    
    if amount_from:
        query = query.filter(Payment.amount >= amount_from)
    
    if amount_to:
        query = query.filter(Payment.amount <= amount_to)
    
    if date_from:
        try:
            query = query.filter(
                Payment.created_at >= datetime.strptime(date_from, '%Y-%m-%d')
            )
        except ValueError:
            pass
    
    if date_to:
        try:
            query = query.filter(
                Payment.created_at <= datetime.strptime(date_to, '%Y-%m-%d')
            )
        except ValueError:
            pass
    
    pagination = query.order_by(
        Payment.created_at.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for payment in pagination.items:
        results.append({
            'id': payment.id,
            'payment_code': payment.payment_code,
            'patient_name': payment.patient.user.full_name if payment.patient else 'N/A',
            'amount': str(payment.amount),
            'payment_method': payment.payment_method,
            'payment_status': payment.payment_status,
            'payment_date': payment.payment_date.strftime('%Y-%m-%d %H:%M:%S') if payment.payment_date else None,
            'created_at': payment.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'payments': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200