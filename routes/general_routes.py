from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Feedback, Review, Appointment
from utils import log_activity, get_patient_id_from_user
from sqlalchemy.exc import IntegrityError

general_bp = Blueprint('general', __name__)

@general_bp.route('/feedback', methods=['POST'])
@jwt_required()
def submit_feedback():
    # ... (Giữ nguyên logic gửi phản hồi từ app.py)
    user_id = get_jwt_identity()
    data = request.get_json()
    
    if not data.get('message'):
        return jsonify({"msg": "Feedback message is required"}), 400

    new_feedback = Feedback(
        user_id=user_id,
        type=data.get('type', 'suggestion'),
        subject=data.get('subject', 'General Feedback'),
        message=data['message'],
        priority=data.get('priority', 'normal')
    )

    try:
        db.session.add(new_feedback)
        db.session.commit()
        log_activity(user_id, "SUBMIT_FEEDBACK", "feedback", new_feedback.id, f"New feedback submitted: {new_feedback.type}")
        return jsonify({"msg": "Feedback submitted successfully", "feedback_id": new_feedback.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error submitting feedback: {str(e)}"}), 500

@general_bp.route('/reviews', methods=['POST'])
@jwt_required()
def submit_review():
    # ... (Giữ nguyên logic gửi đánh giá từ app.py)
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    data = request.get_json()
    
    required_fields = ['appointment_id', 'rating', 'service_rating', 'facility_rating']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required review fields"}), 400
    
    appointment_id = data['appointment_id']
    appointment = Appointment.query.filter_by(id=appointment_id, patient_id=patient_id).first()

    if not appointment or appointment.status != 'completed':
        return jsonify({"msg": "Review can only be submitted for completed appointments owned by the user"}), 403
    
    if Review.query.filter_by(appointment_id=appointment_id).first():
        return jsonify({"msg": "This appointment has already been reviewed"}), 409

    new_review = Review(
        appointment_id=appointment_id,
        patient_id=patient_id,
        doctor_id=appointment.doctor_id,
        rating=data['rating'],
        service_rating=data['service_rating'],
        facility_rating=data['facility_rating'],
        comment=data.get('comment'),
        is_anonymous=data.get('is_anonymous', False)
    )

    try:
        db.session.add(new_review)
        db.session.commit()
        log_activity(user_id, "SUBMIT_REVIEW", "review", new_review.id, f"Submitted review for AP ID: {appointment_id}")
        return jsonify({"msg": "Review submitted successfully", "review_id": new_review.id}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error submitting review: {str(e)}"}), 500

# TODO: Thêm API Thanh toán (Payment Gateway integration)
@general_bp.route('/payments/create', methods=['POST'])
@jwt_required()
def create_payment():
    # Logic tạm thời: Tạo bản ghi thanh toán Pending
    return jsonify({"msg": "Payment creation API not fully implemented. Use mock payment for now."}), 501