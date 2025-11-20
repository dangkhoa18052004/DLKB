from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from models import db, User, Patient
from utils import log_activity, generate_code
from sqlalchemy.exc import IntegrityError
from datetime import datetime

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    # ... (Giữ nguyên logic đăng ký và tạo Patient từ app.py)
    data = request.get_json()
    required_fields = ['username', 'password', 'email', 'full_name', 'phone']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400

    new_user = User(
        username=data['username'],
        email=data['email'],
        full_name=data['full_name'],
        phone=data['phone'],
        role='patient',
        date_of_birth=data.get('date_of_birth'),
        gender=data.get('gender')
    )
    new_user.set_password(data['password'])

    try:
        db.session.add(new_user)
        db.session.flush() 
        
        patient_code = generate_code(prefix='PN', length=8)
        new_patient = Patient(user_id=new_user.id, patient_code=patient_code)
        db.session.add(new_patient)
        
        db.session.commit()
        log_activity(new_user.id, "REGISTER", "user", new_user.id, "New patient registered")
        return jsonify(new_user.to_json()), 201
    
    except IntegrityError:
        db.session.rollback()
        return jsonify({"msg": "Username, Email, or Phone already exists"}), 409
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Registration failed: {str(e)}"}), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    # ... (Giữ nguyên logic đăng nhập từ app.py)
    data = request.get_json()
    username_or_email = data.get('username', None)
    password = data.get('password', None)

    user = User.query.filter(
        (User.username == username_or_email) | (User.email == username_or_email)
    ).first()

    if user and user.check_password(password) and user.is_active:
        # Use string identity to ensure JWT 'sub' is a string (avoid PyJWT Subject type errors)
        access_token = create_access_token(
            identity=str(user.id),
            additional_claims={'role': user.role}
        )
        user.last_login = datetime.utcnow()
        db.session.commit()
        log_activity(user.id, "LOGIN", "user", user.id, "User logged in")
        return jsonify(
            access_token=access_token, 
            user=user.to_json()
        ), 200
    
    return jsonify({"msg": "Invalid credentials or account is inactive"}), 401
    
@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    user_id = get_jwt_identity()
    log_activity(user_id, "LOGOUT", "user", user_id, "User logged out")
    return jsonify({"msg": "Successfully logged out"}), 200