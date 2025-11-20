from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Appointment, Doctor, DoctorSchedule, Service, User
from utils import log_activity, generate_code, get_patient_id_from_user, get_system_setting
from datetime import datetime, timedelta, time
from sqlalchemy.exc import SQLAlchemyError
import pytz

booking_bp = Blueprint('booking', __name__)

@booking_bp.route('/doctors/<int:doctor_id>/available-slots', methods=['GET'])
def get_available_slots(doctor_id):
    target_date_str = request.args.get('date')
    if not target_date_str:
        return jsonify({"msg": "Missing 'date' parameter (YYYY-MM-DD)"}), 400
    
    try:
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
        day_of_week = target_date.weekday() + 1
        if day_of_week == 7: 
             day_of_week = 0 
    except ValueError:
        return jsonify({"msg": "Invalid date format. Use YYYY-MM-DD"}), 400

    schedules = DoctorSchedule.query.filter_by(
        doctor_id=doctor_id, 
        day_of_week=day_of_week, 
        is_active=True
    ).all()

    if not schedules:
        return jsonify({"msg": "Doctor is not scheduled on this day"}), 404

    booked_appointments = Appointment.query.filter(
        Appointment.doctor_id == doctor_id,
        Appointment.appointment_date == target_date,
        Appointment.status.in_(['pending', 'confirmed'])
    ).all()
    
    booked_slots = {} 
    for app in booked_appointments:
        slot_key = (app.appointment_time.hour, app.appointment_time.minute)
        booked_slots[slot_key] = booked_slots.get(slot_key, 0) + 1
        
    buffer_minutes = int(get_system_setting('appointment_buffer_minutes', '15'))
    available_slots = []

    for schedule in schedules:
        start = datetime.combine(target_date, schedule.start_time)
        end = datetime.combine(target_date, schedule.end_time)
        current_slot_start = start
        
        while current_slot_start + timedelta(minutes=buffer_minutes) <= end:
            slot_key = (current_slot_start.hour, current_slot_start.minute)
            current_bookings = booked_slots.get(slot_key, 0)
            
            if current_bookings < schedule.max_patients:
                available_slots.append({
                    'start_time': current_slot_start.strftime('%H:%M'),
                    'end_time': (current_slot_start + timedelta(minutes=buffer_minutes)).strftime('%H:%M'),
                    'capacity': schedule.max_patients - current_bookings
                })
            
            current_slot_start += timedelta(minutes=buffer_minutes)

    return jsonify(available_slots), 200

@booking_bp.route('/appointments', methods=['POST'])
@jwt_required()
def create_appointment():
    # Debug: log incoming request headers and raw body to help trace 422 errors
    try:
        raw = request.get_data(cache=True)
        print(f"[BOOKING] Request headers: {dict(request.headers)}")
        print(f"[BOOKING] Raw body: {raw.decode('utf-8', errors='replace')}")
    except Exception as _:
        print("[BOOKING] Failed to read request body for debugging")

    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    if not patient_id:
        return jsonify({"msg": "User role is not patient or patient data missing"}), 403

    # Lấy dữ liệu an toàn hơn, tránh lỗi serialization/middleware
    try:
        data = request.get_json(silent=True) # Dùng silent=True để tránh lỗi parser
        if not data:
             return jsonify({"msg": "Invalid or empty JSON data received"}), 400
             
        doctor_id = data['doctor_id']
        service_id = data['service_id']
        appointment_date = datetime.strptime(data['appointment_date'], '%Y-%m-%d').date()
        appointment_time = datetime.strptime(data['appointment_time'], '%H:%M').time()
    except (KeyError, ValueError) as e:
        # Trả lỗi chi tiết hơn nếu thiếu trường bắt buộc
        return jsonify({"msg": f"Missing or invalid data field: {e}"}), 400
    except Exception as e:
         # Lỗi không rõ nguyên nhân, có thể do JSON bị hỏng
         return jsonify({"msg": f"Critical error parsing JSON: {str(e)}"}), 400


    now_utc = datetime.utcnow().replace(tzinfo=pytz.utc)
    appointment_dt_utc = datetime.combine(appointment_date, appointment_time).replace(tzinfo=pytz.utc)
    if appointment_dt_utc < now_utc:
         return jsonify({"msg": "Cannot book an appointment in the past"}), 400

    doctor = Doctor.query.get(doctor_id)
    service = Service.query.get(service_id)
    if not doctor or not service:
         return jsonify({"msg": "Doctor or Service not found"}), 404
         
    existing_appointment = Appointment.query.filter(
        Appointment.doctor_id == doctor_id,
        Appointment.appointment_date == appointment_date,
        Appointment.appointment_time == appointment_time,
        Appointment.status.in_(['pending', 'confirmed'])
    ).first()
    if existing_appointment:
        return jsonify({"msg": "This time slot is already booked"}), 409

    new_appointment = Appointment(
        appointment_code=generate_code(prefix='AP', length=10),
        patient_id=patient_id,
        doctor_id=doctor_id,
        department_id=doctor.department_id,
        service_id=service_id,
        appointment_date=appointment_date,
        appointment_time=appointment_time,
        status='pending',
        reason=data.get('reason'),
        symptoms=data.get('symptoms')
    )

    try:
        db.session.add(new_appointment)
        db.session.commit()
        log_activity(user_id, "CREATE_APPOINTMENT", "appointment", new_appointment.id, f"Booked AP code: {new_appointment.appointment_code}")
        
        return jsonify({
            "msg": "Appointment created successfully", 
            "appointment_id": new_appointment.id, 
            "appointment_code": new_appointment.appointment_code,
            "required_payment": str(service.price)
        }), 201
        
    except SQLAlchemyError as e:
        db.session.rollback()
        return jsonify({"msg": f"Database error during booking: {str(e)}"}), 500

@booking_bp.route('/appointments/me', methods=['GET'])
@jwt_required()
def get_my_appointments():
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    if not patient_id:
        return jsonify({"msg": "Invalid user role for this action"}), 403
        
    appointments = Appointment.query.filter_by(patient_id=patient_id).order_by(Appointment.appointment_date.desc()).all()
    
    results = []
    for app in appointments:
        doctor_name = app.doctor.user.full_name if app.doctor and app.doctor.user else 'N/A'
        
        results.append({
            'id': app.id,
            'code': app.appointment_code,
            'date': app.appointment_date.strftime('%Y-%m-%d'),
            'time': app.appointment_time.strftime('%H:%M'),
            'status': app.status,
            'doctor_name': doctor_name,
            'department_id': app.department_id
        })
        
    return jsonify(results), 200

@booking_bp.route('/appointments/<int:appointment_id>/cancel', methods=['PUT'])
@jwt_required()
def cancel_appointment(appointment_id):
    user_id = get_jwt_identity()
    patient_id = get_patient_id_from_user(user_id)
    
    appointment = Appointment.query.filter_by(id=appointment_id, patient_id=patient_id).first()
    
    if not appointment:
        return jsonify({"msg": "Appointment not found or not owned by user"}), 404

    if appointment.status in ['completed', 'cancelled', 'no_show']:
        return jsonify({"msg": f"Cannot cancel appointment with status: {appointment.status}"}), 400

    cancellation_hours = int(get_system_setting('cancellation_allowed_hours', '24'))
    
    appointment_dt = datetime.combine(appointment.appointment_date, appointment.appointment_time).replace(tzinfo=pytz.utc)
    now_utc = datetime.utcnow().replace(tzinfo=pytz.utc)
    time_difference = (appointment_dt - now_utc).total_seconds() / 3600

    if time_difference < cancellation_hours:
        return jsonify({"msg": f"Cancellation is only allowed {cancellation_hours} hours before the appointment."}), 400

    try:
        appointment.status = 'cancelled'
        appointment.cancellation_reason = request.get_json().get('reason', 'Cancelled by patient via app')
        appointment.cancelled_by = user_id
        appointment.cancelled_at = datetime.utcnow()
        db.session.commit()
        log_activity(user_id, "CANCEL_APPOINTMENT", "appointment", appointment.id, f"Cancelled AP code: {appointment.appointment_code}")
        
        return jsonify({"msg": "Appointment cancelled successfully", "status": "cancelled"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error during cancellation: {str(e)}"}), 500