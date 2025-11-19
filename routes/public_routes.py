from flask import Blueprint, request, jsonify
from models import Department, Doctor, User, Service
from sqlalchemy.orm import joinedload # Để tối ưu query

public_bp = Blueprint('public', __name__)

@public_bp.route('/departments', methods=['GET'])
def get_departments():
    # ... (Giữ nguyên logic từ app.py)
    departments = Department.query.filter_by(is_active=True).order_by(Department.display_order).all()
    results = [{'id': d.id, 'name': d.name, 'description': d.description} for d in departments]
    return jsonify(results), 200

@public_bp.route('/doctors', methods=['GET'])
def get_doctors():
    # ... (Giữ nguyên logic từ app.py)
    department_id = request.args.get('department_id', type=int)
    
    # Sử dụng joinedload để load thông tin User cùng lúc (tối ưu SQL)
    query = Doctor.query.options(joinedload(Doctor.user)).filter(Doctor.is_available == True)
    
    if department_id:
        query = query.filter(Doctor.department_id == department_id)

    doctors = query.all()
    
    results = []
    for d in doctors:
        results.append({
            'id': d.id,
            'full_name': d.user.full_name,
            'specialization': d.specialization,
            'department_id': d.department_id,
            'consultation_fee': str(d.consultation_fee),
            'rating': float(d.rating),
            'bio': d.bio
        })
    return jsonify(results), 200

@public_bp.route('/services', methods=['GET'])
def get_services():
    # ... (Giữ nguyên logic từ app.py)
    services = Service.query.filter_by(is_active=True).all()
    results = [{'id': s.id, 'name': s.name, 'price': str(s.price), 'duration_minutes': s.duration_minutes} for s in services]
    return jsonify(results), 200