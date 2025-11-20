from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (db, User, Doctor, Patient, Department, Service, 
                     Appointment, DoctorSchedule, Review, Feedback, 
                     MedicalRecord, Payment, SystemSetting)
from utils import log_activity, generate_code, admin_required
from datetime import datetime
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, extract

admin_bp = Blueprint('admin', __name__)

# USER MANAGEMENT

@admin_bp.route('/users', methods=['GET'])
@jwt_required()
@admin_required
def get_all_users():
    """Lấy danh sách tất cả users với phân trang và lọc"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    role = request.args.get('role')
    is_active = request.args.get('is_active')
    search = request.args.get('search')
    
    query = User.query
    
    if role:
        query = query.filter_by(role=role)
    if is_active is not None:
        query = query.filter_by(is_active=is_active.lower() == 'true')
    if search:
        query = query.filter(
            (User.full_name.ilike(f'%{search}%')) |
            (User.email.ilike(f'%{search}%')) |
            (User.phone.ilike(f'%{search}%'))
        )
    
    pagination = query.order_by(User.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    results = []
    for user in pagination.items:
        results.append({
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'full_name': user.full_name,
            'phone': user.phone,
            'role': user.role,
            'is_active': user.is_active,
            'is_verified': user.is_verified,
            'created_at': user.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            'last_login': user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else None
        })
    
    return jsonify({
        'users': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@admin_bp.route('/users/<int:user_id>', methods=['GET'])
@jwt_required()
@admin_required
def get_user_detail(user_id):
    """Lấy thông tin chi tiết user"""
    user = User.query.get_or_404(user_id)
    
    user_data = {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'full_name': user.full_name,
        'phone': user.phone,
        'date_of_birth': user.date_of_birth.strftime('%Y-%m-%d') if user.date_of_birth else None,
        'gender': user.gender,
        'address': user.address,
        'avatar_url': user.avatar_url,
        'role': user.role,
        'is_active': user.is_active,
        'is_verified': user.is_verified,
        'created_at': user.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'last_login': user.last_login.strftime('%Y-%m-%d %H:%M:%S') if user.last_login else None
    }
    
    # Nếu là doctor, lấy thêm thông tin doctor
    if user.role == 'doctor' and hasattr(user, 'doctor_info'):
        doctor = user.doctor_info
        user_data['doctor_info'] = {
            'id': doctor.id,
            'license_number': doctor.license_number,
            'specialization': doctor.specialization,
            'department_id': doctor.department_id,
            'consultation_fee': str(doctor.consultation_fee),
            'rating': float(doctor.rating),
            'is_available': doctor.is_available
        }
    
    # Nếu là patient, lấy thêm thông tin patient
    if user.role == 'patient' and hasattr(user, 'patient_info'):
        patient = user.patient_info
        user_data['patient_info'] = {
            'id': patient.id,
            'patient_code': patient.patient_code,
            'blood_type': patient.blood_type,
            'insurance_number': patient.insurance_number
        }
    
    return jsonify(user_data), 200

@admin_bp.route('/users', methods=['POST'])
@jwt_required()
@admin_required
def create_user():
    """Tạo user mới (admin, doctor, staff, patient)"""
    admin_id = get_jwt_identity()
    data = request.get_json()
    
    required_fields = ['username', 'password', 'email', 'full_name', 'phone', 'role']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    if data['role'] not in ['admin', 'doctor', 'patient', 'staff']:
        return jsonify({"msg": "Invalid role"}), 400
    
    new_user = User(
        username=data['username'],
        email=data['email'],
        full_name=data['full_name'],
        phone=data['phone'],
        role=data['role'],
        date_of_birth=datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date() if data.get('date_of_birth') else None,
        gender=data.get('gender'),
        address=data.get('address'),
        is_active=data.get('is_active', True),
        is_verified=data.get('is_verified', False)
    )
    new_user.set_password(data['password'])
    
    try:
        db.session.add(new_user)
        db.session.flush()
        
        # Nếu role là patient, tạo Patient record
        if data['role'] == 'patient':
            patient_code = generate_code(prefix='PN', length=8)
            new_patient = Patient(
                user_id=new_user.id,
                patient_code=patient_code,
                blood_type=data.get('blood_type'),
                insurance_number=data.get('insurance_number'),
                insurance_provider=data.get('insurance_provider')
            )
            db.session.add(new_patient)
        
        # Nếu role là doctor, tạo Doctor record
        elif data['role'] == 'doctor':
            if not data.get('license_number') or not data.get('department_id'):
                return jsonify({"msg": "License number and department_id required for doctor"}), 400
            
            new_doctor = Doctor(
                user_id=new_user.id,
                department_id=data['department_id'],
                license_number=data['license_number'],
                specialization=data.get('specialization'),
                experience_years=data.get('experience_years'),
                education=data.get('education'),
                bio=data.get('bio'),
                consultation_fee=data.get('consultation_fee', 0),
                is_available=data.get('is_available', True)
            )
            db.session.add(new_doctor)
        
        db.session.commit()
        log_activity(admin_id, "CREATE_USER", "user", new_user.id, f"Created user: {new_user.username}")
        
        return jsonify({
            "msg": "User created successfully",
            "user_id": new_user.id,
            "username": new_user.username
        }), 201
        
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Username, Email, or Phone already exists"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating user: {str(e)}"}), 500

@admin_bp.route('/users/<int:user_id>', methods=['PUT'])
@jwt_required()
@admin_required
def update_user(user_id):
    """Cập nhật thông tin user"""
    admin_id = get_jwt_identity()
    user = User.query.get_or_404(user_id)
    data = request.get_json()
    
    # Cập nhật các trường được phép
    if 'full_name' in data:
        user.full_name = data['full_name']
    if 'email' in data:
        user.email = data['email']
    if 'phone' in data:
        user.phone = data['phone']
    if 'date_of_birth' in data:
        user.date_of_birth = datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date()
    if 'gender' in data:
        user.gender = data['gender']
    if 'address' in data:
        user.address = data['address']
    if 'is_active' in data:
        user.is_active = data['is_active']
    if 'is_verified' in data:
        user.is_verified = data['is_verified']
    if 'avatar_url' in data:
        user.avatar_url = data['avatar_url']
    
    # Nếu có password mới
    if 'password' in data and data['password']:
        user.set_password(data['password'])
    
    try:
        db.session.commit()
        log_activity(admin_id, "UPDATE_USER", "user", user.id, f"Updated user: {user.username}")
        return jsonify({"msg": "User updated successfully"}), 200
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Email or Phone already exists"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating user: {str(e)}"}), 500

@admin_bp.route('/users/<int:user_id>', methods=['DELETE'])
@jwt_required()
@admin_required
def delete_user(user_id):
    """Xóa user (soft delete bằng cách set is_active=False)"""
    admin_id = get_jwt_identity()
    
    if user_id == admin_id:
        return jsonify({"msg": "Cannot delete yourself"}), 400
    
    user = User.query.get_or_404(user_id)
    
    # Soft delete
    user.is_active = False
    
    try:
        db.session.commit()
        log_activity(admin_id, "DELETE_USER", "user", user.id, f"Deactivated user: {user.username}")
        return jsonify({"msg": "User deactivated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error deleting user: {str(e)}"}), 500

# =============================================
# DOCTOR MANAGEMENT
# =============================================

@admin_bp.route('/doctors', methods=['GET'])
@jwt_required()
@admin_required
def get_all_doctors():
    """Lấy danh sách tất cả bác sĩ"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    department_id = request.args.get('department_id', type=int)
    is_available = request.args.get('is_available')
    
    query = Doctor.query.join(User)
    
    if department_id:
        query = query.filter(Doctor.department_id == department_id)
    if is_available is not None:
        query = query.filter(Doctor.is_available == (is_available.lower() == 'true'))
    
    pagination = query.order_by(Doctor.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    results = []
    for doctor in pagination.items:
        results.append({
            'id': doctor.id,
            'full_name': doctor.user.full_name,
            'license_number': doctor.license_number,
            'specialization': doctor.specialization,
            'department_id': doctor.department_id,
            'consultation_fee': str(doctor.consultation_fee),
            'rating': float(doctor.rating),
            'total_reviews': doctor.total_reviews,
            'is_available': doctor.is_available,
            'email': doctor.user.email,
            'phone': doctor.user.phone
        })
    
    return jsonify({
        'doctors': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@admin_bp.route('/doctors/<int:doctor_id>', methods=['PUT'])
@jwt_required()
@admin_required
def update_doctor(doctor_id):
    """Cập nhật thông tin bác sĩ"""
    admin_id = get_jwt_identity()
    doctor = Doctor.query.get_or_404(doctor_id)
    data = request.get_json()
    
    if 'department_id' in data:
        doctor.department_id = data['department_id']
    if 'specialization' in data:
        doctor.specialization = data['specialization']
    if 'experience_years' in data:
        doctor.experience_years = data['experience_years']
    if 'education' in data:
        doctor.education = data['education']
    if 'bio' in data:
        doctor.bio = data['bio']
    if 'consultation_fee' in data:
        doctor.consultation_fee = data['consultation_fee']
    if 'is_available' in data:
        doctor.is_available = data['is_available']
    
    try:
        db.session.commit()
        log_activity(admin_id, "UPDATE_DOCTOR", "doctor", doctor.id, f"Updated doctor ID: {doctor.id}")
        return jsonify({"msg": "Doctor updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating doctor: {str(e)}"}), 500

# =============================================
# DEPARTMENT MANAGEMENT
# =============================================

@admin_bp.route('/departments', methods=['GET'])
@jwt_required()
@admin_required
def get_all_departments():
    """Lấy danh sách tất cả chuyên khoa"""
    departments = Department.query.order_by(Department.display_order).all()
    
    results = []
    for dept in departments:
        # Đếm số bác sĩ trong khoa
        doctor_count = Doctor.query.filter_by(department_id=dept.id, is_available=True).count()
        
        results.append({
            'id': dept.id,
            'name': dept.name,
            'description': dept.description,
            'icon_url': dept.icon_url,
            'display_order': dept.display_order,
            'is_active': dept.is_active,
            'doctor_count': doctor_count,
            'created_at': dept.created_at.strftime('%Y-%m-%d')
        })
    
    return jsonify(results), 200

@admin_bp.route('/departments', methods=['POST'])
@jwt_required()
@admin_required
def create_department():
    """Tạo chuyên khoa mới"""
    admin_id = get_jwt_identity()
    data = request.get_json()
    
    if not data.get('name'):
        return jsonify({"msg": "Department name is required"}), 400
    
    new_dept = Department(
        name=data['name'],
        description=data.get('description'),
        icon_url=data.get('icon_url'),
        display_order=data.get('display_order', 0),
        is_active=data.get('is_active', True)
    )
    
    try:
        db.session.add(new_dept)
        db.session.commit()
        log_activity(admin_id, "CREATE_DEPARTMENT", "department", new_dept.id, f"Created department: {new_dept.name}")
        return jsonify({"msg": "Department created successfully", "id": new_dept.id}), 201
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Department name already exists"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating department: {str(e)}"}), 500

@admin_bp.route('/departments/<int:dept_id>', methods=['PUT'])
@jwt_required()
@admin_required
def update_department(dept_id):
    """Cập nhật chuyên khoa"""
    admin_id = get_jwt_identity()
    dept = Department.query.get_or_404(dept_id)
    data = request.get_json()
    
    if 'name' in data:
        dept.name = data['name']
    if 'description' in data:
        dept.description = data['description']
    if 'icon_url' in data:
        dept.icon_url = data['icon_url']
    if 'display_order' in data:
        dept.display_order = data['display_order']
    if 'is_active' in data:
        dept.is_active = data['is_active']
    
    try:
        db.session.commit()
        log_activity(admin_id, "UPDATE_DEPARTMENT", "department", dept.id, f"Updated department: {dept.name}")
        return jsonify({"msg": "Department updated successfully"}), 200
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Department name already exists"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating department: {str(e)}"}), 500

@admin_bp.route('/departments/<int:dept_id>', methods=['DELETE'])
@jwt_required()
@admin_required
def delete_department(dept_id):
    """Xóa chuyên khoa (soft delete)"""
    admin_id = get_jwt_identity()
    dept = Department.query.get_or_404(dept_id)
    
    # Kiểm tra xem có bác sĩ nào đang thuộc khoa này không
    doctor_count = Doctor.query.filter_by(department_id=dept_id).count()
    if doctor_count > 0:
        return jsonify({"msg": f"Cannot delete department with {doctor_count} doctors. Please reassign doctors first."}), 400
    
    dept.is_active = False
    
    try:
        db.session.commit()
        log_activity(admin_id, "DELETE_DEPARTMENT", "department", dept.id, f"Deactivated department: {dept.name}")
        return jsonify({"msg": "Department deactivated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error deleting department: {str(e)}"}), 500

# =============================================
# SERVICE MANAGEMENT
# =============================================

@admin_bp.route('/services', methods=['GET'])
@jwt_required()
@admin_required
def get_all_services():
    """Lấy danh sách tất cả dịch vụ"""
    services = Service.query.order_by(Service.created_at.desc()).all()
    
    results = []
    for service in services:
        results.append({
            'id': service.id,
            'name': service.name,
            'description': service.description,
            'department_id': service.department_id,
            'price': str(service.price),
            'duration_minutes': service.duration_minutes,
            'is_active': service.is_active,
            'created_at': service.created_at.strftime('%Y-%m-%d')
        })
    
    return jsonify(results), 200

@admin_bp.route('/services', methods=['POST'])
@jwt_required()
@admin_required
def create_service():
    """Tạo dịch vụ mới"""
    admin_id = get_jwt_identity()
    data = request.get_json()
    
    if not data.get('name') or not data.get('price'):
        return jsonify({"msg": "Service name and price are required"}), 400
    
    new_service = Service(
        name=data['name'],
        description=data.get('description'),
        department_id=data.get('department_id'),
        price=data['price'],
        duration_minutes=data.get('duration_minutes', 30),
        is_active=data.get('is_active', True)
    )
    
    try:
        db.session.add(new_service)
        db.session.commit()
        log_activity(admin_id, "CREATE_SERVICE", "service", new_service.id, f"Created service: {new_service.name}")
        return jsonify({"msg": "Service created successfully", "id": new_service.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error creating service: {str(e)}"}), 500

@admin_bp.route('/services/<int:service_id>', methods=['PUT'])
@jwt_required()
@admin_required
def update_service(service_id):
    """Cập nhật dịch vụ"""
    admin_id = get_jwt_identity()
    service = Service.query.get_or_404(service_id)
    data = request.get_json()
    
    if 'name' in data:
        service.name = data['name']
    if 'description' in data:
        service.description = data['description']
    if 'department_id' in data:
        service.department_id = data['department_id']
    if 'price' in data:
        service.price = data['price']
    if 'duration_minutes' in data:
        service.duration_minutes = data['duration_minutes']
    if 'is_active' in data:
        service.is_active = data['is_active']
    
    try:
        db.session.commit()
        log_activity(admin_id, "UPDATE_SERVICE", "service", service.id, f"Updated service: {service.name}")
        return jsonify({"msg": "Service updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating service: {str(e)}"}), 500

@admin_bp.route('/services/<int:service_id>', methods=['DELETE'])
@jwt_required()
@admin_required
def delete_service(service_id):
    """Xóa dịch vụ (soft delete)"""
    admin_id = get_jwt_identity()
    service = Service.query.get_or_404(service_id)
    
    service.is_active = False
    
    try:
        db.session.commit()
        log_activity(admin_id, "DELETE_SERVICE", "service", service.id, f"Deactivated service: {service.name}")
        return jsonify({"msg": "Service deactivated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error deleting service: {str(e)}"}), 500

# =============================================
# APPOINTMENT MANAGEMENT
# =============================================

@admin_bp.route('/appointments', methods=['GET'])
@jwt_required()
@admin_required
def get_all_appointments():
    """Lấy danh sách tất cả lịch hẹn với filter"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    status = request.args.get('status')
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    doctor_id = request.args.get('doctor_id', type=int)
    patient_id = request.args.get('patient_id', type=int)
    
    query = Appointment.query
    
    if status:
        query = query.filter_by(status=status)
    if doctor_id:
        query = query.filter_by(doctor_id=doctor_id)
    if patient_id:
        query = query.filter_by(patient_id=patient_id)
    if date_from:
        query = query.filter(Appointment.appointment_date >= datetime.strptime(date_from, '%Y-%m-%d').date())
    if date_to:
        query = query.filter(Appointment.appointment_date <= datetime.strptime(date_to, '%Y-%m-%d').date())
    
    pagination = query.order_by(Appointment.appointment_date.desc(), Appointment.appointment_time.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    results = []
    for app in pagination.items:
        results.append({
            'id': app.id,
            'appointment_code': app.appointment_code,
            'patient_name': app.patient.user.full_name if app.patient else 'N/A',
            'patient_phone': app.patient.user.phone if app.patient else 'N/A',
            'doctor_name': app.doctor.user.full_name if app.doctor else 'N/A',
            'appointment_date': app.appointment_date.strftime('%Y-%m-%d'),
            'appointment_time': app.appointment_time.strftime('%H:%M'),
            'status': app.status,
            'reason': app.reason,
            'created_at': app.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'appointments': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@admin_bp.route('/appointments/<int:appointment_id>/status', methods=['PUT'])
@jwt_required()
@admin_required
def update_appointment_status(appointment_id):
    """Cập nhật trạng thái lịch hẹn"""
    admin_id = get_jwt_identity()
    appointment = Appointment.query.get_or_404(appointment_id)
    data = request.get_json()
    
    new_status = data.get('status')
    if new_status not in ['pending', 'confirmed', 'checked_in', 'completed', 'cancelled', 'no_show']:
        return jsonify({"msg": "Invalid status"}), 400
    
    old_status = appointment.status
    appointment.status = new_status
    
    if new_status == 'checked_in':
        appointment.checked_in_at = datetime.utcnow()
    elif new_status == 'completed':
        appointment.completed_at = datetime.utcnow()
    elif new_status == 'cancelled':
        appointment.cancelled_by = admin_id
        appointment.cancelled_at = datetime.utcnow()
        appointment.cancellation_reason = data.get('reason', 'Cancelled by admin')
    
    try:
        db.session.commit()
        log_activity(admin_id, "UPDATE_APPOINTMENT_STATUS", "appointment", appointment.id, 
                    f"Changed status from {old_status} to {new_status}")
        return jsonify({"msg": "Appointment status updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating appointment: {str(e)}"}), 500

# =============================================
# REVIEW MANAGEMENT
# =============================================

@admin_bp.route('/reviews', methods=['GET'])
@jwt_required()
@admin_required
def get_all_reviews():
    """Lấy danh sách tất cả đánh giá"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    is_approved = request.args.get('is_approved')
    
    query = Review.query
    
    if is_approved is not None:
        query = query.filter_by(is_approved=(is_approved.lower() == 'true'))
    
    pagination = query.order_by(Review.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    results = []
    for review in pagination.items:
        results.append({
            'id': review.id,
            'patient_name': 'Anonymous' if review.is_anonymous else (review.patient.user.full_name if review.patient else 'N/A'),
            'doctor_name': review.doctor.user.full_name if review.doctor else 'N/A',
            'rating': review.rating,
            'service_rating': review.service_rating,
            'facility_rating': review.facility_rating,
            'comment': review.comment,
            'is_approved': review.is_approved,
            'created_at': review.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'reviews': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@admin_bp.route('/reviews/<int:review_id>/approve', methods=['PUT'])
@jwt_required()
@admin_required
def approve_review(review_id):
    """Duyệt đánh giá"""
    admin_id = get_jwt_identity()
    review = Review.query.get_or_404(review_id)
    
    review.is_approved = True
    review.approved_by = admin_id
    review.approved_at = datetime.utcnow()
    
    try:
        db.session.commit()
        log_activity(admin_id, "APPROVE_REVIEW", "review", review.id, f"Approved review ID: {review.id}")
        return jsonify({"msg": "Review approved successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error approving review: {str(e)}"}), 500

@admin_bp.route('/reviews/<int:review_id>', methods=['DELETE'])
@jwt_required()
@admin_required
def delete_review(review_id):
    """Xóa đánh giá"""
    admin_id = get_jwt_identity()
    review = Review.query.get_or_404(review_id)
    
    try:
        db.session.delete(review)
        db.session.commit()
        log_activity(admin_id, "DELETE_REVIEW", "review", review_id, f"Deleted review ID: {review_id}")
        return jsonify({"msg": "Review deleted successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error deleting review: {str(e)}"}), 500

# =============================================
# FEEDBACK MANAGEMENT
# =============================================

@admin_bp.route('/feedback', methods=['GET'])
@jwt_required()
@admin_required
def get_all_feedback():
    """Lấy danh sách tất cả phản hồi"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    status = request.args.get('status')
    priority = request.args.get('priority')
    
    query = Feedback.query
    
    if status:
        query = query.filter_by(status=status)
    if priority:
        query = query.filter_by(priority=priority)
    
    pagination = query.order_by(Feedback.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    results = []
    for feedback in pagination.items:
        results.append({
            'id': feedback.id,
            'user_name': feedback.user.full_name if feedback.user else 'Anonymous',
            'type': feedback.type,
            'subject': feedback.subject,
            'message': feedback.message,
            'status': feedback.status,
            'priority': feedback.priority,
            'response': feedback.response,
            'created_at': feedback.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'feedback': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200

@admin_bp.route('/feedback/<int:feedback_id>/respond', methods=['PUT'])
@jwt_required()
@admin_required
def respond_to_feedback(feedback_id):
    """Trả lời phản hồi"""
    admin_id = get_jwt_identity()
    feedback = Feedback.query.get_or_404(feedback_id)
    data = request.get_json()
    
    if not data.get('response'):
        return jsonify({"msg": "Response message is required"}), 400
    
    feedback.response = data['response']
    feedback.responded_by = admin_id
    feedback.responded_at = datetime.utcnow()
    feedback.status = data.get('status', 'resolved')
    
    try:
        db.session.commit()
        log_activity(admin_id, "RESPOND_FEEDBACK", "feedback", feedback.id, f"Responded to feedback ID: {feedback.id}")
        return jsonify({"msg": "Feedback response saved successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error responding to feedback: {str(e)}"}), 500

# =============================================
# SYSTEM SETTINGS
# =============================================

@admin_bp.route('/settings', methods=['GET'])
@jwt_required()
@admin_required
def get_system_settings():
    """Lấy tất cả cài đặt hệ thống"""
    settings = SystemSetting.query.all()
    
    results = []
    for setting in settings:
        results.append({
            'id': setting.id,
            'key': setting.key,
            'value': setting.value,
            'description': setting.description,
            'data_type': setting.data_type
        })
    
    return jsonify(results), 200

@admin_bp.route('/settings/<int:setting_id>', methods=['PUT'])
@jwt_required()
@admin_required
def update_system_setting(setting_id):
    """Cập nhật cài đặt hệ thống"""
    admin_id = get_jwt_identity()
    setting = SystemSetting.query.get_or_404(setting_id)
    data = request.get_json()
    
    if 'value' in data:
        setting.value = data['value']
    if 'description' in data:
        setting.description = data['description']
    
    setting.updated_by = admin_id
    
    try:
        db.session.commit()
        log_activity(admin_id, "UPDATE_SETTING", "system_setting", setting.id, f"Updated setting: {setting.key}")
        return jsonify({"msg": "Setting updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating setting: {str(e)}"}), 500