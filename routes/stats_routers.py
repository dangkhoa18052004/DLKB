from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (db, User, Appointment, Payment, Patient, Doctor, 
                     Department, Review, MedicalRecord, Service)
from utils import admin_required
from sqlalchemy import func, extract, and_, or_
from datetime import datetime, timedelta, date
from decimal import Decimal

stats_bp = Blueprint('stats', __name__)

# =============================================
# DASHBOARD OVERVIEW
# =============================================

@stats_bp.route('/dashboard/overview', methods=['GET'])
@jwt_required()
@admin_required
def get_dashboard_overview():
    """Tổng quan dashboard - Thống kê tổng thể"""
    
    today = date.today()
    this_month_start = today.replace(day=1)
    last_month_start = (this_month_start - timedelta(days=1)).replace(day=1)
    
    # Tổng số bệnh nhân
    total_patients = Patient.query.count()
    
    # Bệnh nhân mới trong tháng
    new_patients_this_month = Patient.query.filter(
        Patient.created_at >= this_month_start
    ).count()
    
    # Tổng số bác sĩ
    total_doctors = Doctor.query.filter_by(is_available=True).count()
    
    # Tổng số lịch hẹn
    total_appointments = Appointment.query.count()
    
    # Lịch hẹn hôm nay
    appointments_today = Appointment.query.filter_by(appointment_date=today).count()
    
    # Lịch hẹn pending
    appointments_pending = Appointment.query.filter_by(status='pending').count()
    
    # Lịch hẹn confirmed hôm nay
    appointments_today_confirmed = Appointment.query.filter(
        Appointment.appointment_date == today,
        Appointment.status.in_(['confirmed', 'checked_in'])
    ).count()
    
    # Doanh thu tháng này
    revenue_this_month = db.session.query(func.sum(Payment.amount)).filter(
        Payment.payment_status == 'completed',
        Payment.payment_date >= this_month_start
    ).scalar() or Decimal(0)
    
    # Doanh thu tháng trước
    revenue_last_month = db.session.query(func.sum(Payment.amount)).filter(
        Payment.payment_status == 'completed',
        Payment.payment_date >= last_month_start,
        Payment.payment_date < this_month_start
    ).scalar() or Decimal(0)
    
    # Tính phần trăm tăng/giảm
    revenue_change = 0
    if revenue_last_month > 0:
        revenue_change = ((revenue_this_month - revenue_last_month) / revenue_last_month) * 100
    
    # Đánh giá trung bình
    avg_rating = db.session.query(func.avg(Review.rating)).filter(
        Review.is_approved == True
    ).scalar() or 0
    
    # Số lượng đánh giá mới chưa duyệt
    pending_reviews = Review.query.filter_by(is_approved=False).count()
    
    overview_data = {
        'patients': {
            'total': total_patients,
            'new_this_month': new_patients_this_month
        },
        'doctors': {
            'total': total_doctors
        },
        'appointments': {
            'total': total_appointments,
            'today': appointments_today,
            'today_confirmed': appointments_today_confirmed,
            'pending': appointments_pending
        },
        'revenue': {
            'this_month': str(revenue_this_month),
            'last_month': str(revenue_last_month),
            'change_percent': round(float(revenue_change), 2)
        },
        'reviews': {
            'average_rating': round(float(avg_rating), 2),
            'pending_count': pending_reviews
        }
    }
    
    return jsonify(overview_data), 200

# =============================================
# APPOINTMENT STATISTICS
# =============================================

@stats_bp.route('/appointments/daily', methods=['GET'])
@jwt_required()
@admin_required
def get_daily_appointments():
    """Thống kê lịch hẹn theo ngày"""
    date_str = request.args.get('date', date.today().strftime('%Y-%m-%d'))
    
    try:
        target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({"msg": "Invalid date format"}), 400
    
    # Thống kê theo status
    appointments = Appointment.query.filter_by(appointment_date=target_date).all()
    
    status_count = {
        'pending': 0,
        'confirmed': 0,
        'checked_in': 0,
        'completed': 0,
        'cancelled': 0,
        'no_show': 0
    }
    
    for app in appointments:
        status_count[app.status] = status_count.get(app.status, 0) + 1
    
    # Thống kê theo khoa
    department_stats = db.session.query(
        Department.name,
        func.count(Appointment.id).label('count')
    ).join(Appointment, Department.id == Appointment.department_id).filter(
        Appointment.appointment_date == target_date
    ).group_by(Department.name).all()
    
    dept_data = [{'department': name, 'count': count} for name, count in department_stats]
    
    return jsonify({
        'date': date_str,
        'total': len(appointments),
        'by_status': status_count,
        'by_department': dept_data
    }), 200

@stats_bp.route('/appointments/monthly', methods=['GET'])
@jwt_required()
@admin_required
def get_monthly_appointments():
    """Thống kê lịch hẹn theo tháng"""
    year = request.args.get('year', datetime.now().year, type=int)
    month = request.args.get('month', datetime.now().month, type=int)
    
    # Lấy ngày đầu và cuối tháng
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1)
    else:
        end_date = date(year, month + 1, 1)
    
    # Thống kê theo ngày trong tháng
    daily_stats = db.session.query(
        Appointment.appointment_date,
        func.count(Appointment.id).label('count')
    ).filter(
        Appointment.appointment_date >= start_date,
        Appointment.appointment_date < end_date
    ).group_by(Appointment.appointment_date).order_by(Appointment.appointment_date).all()
    
    daily_data = [
        {
            'date': appt_date.strftime('%Y-%m-%d'),
            'count': count
        } for appt_date, count in daily_stats
    ]
    
    # Tổng số lịch hẹn trong tháng
    total = sum(item['count'] for item in daily_data)
    
    # Thống kê theo status
    status_stats = db.session.query(
        Appointment.status,
        func.count(Appointment.id).label('count')
    ).filter(
        Appointment.appointment_date >= start_date,
        Appointment.appointment_date < end_date
    ).group_by(Appointment.status).all()
    
    status_data = {status: count for status, count in status_stats}
    
    return jsonify({
        'year': year,
        'month': month,
        'total': total,
        'daily': daily_data,
        'by_status': status_data
    }), 200

@stats_bp.route('/appointments/by-doctor', methods=['GET'])
@jwt_required()
@admin_required
def get_appointments_by_doctor():
    """Thống kê lịch hẹn theo bác sĩ"""
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    query = db.session.query(
        User.full_name,
        Doctor.id,
        func.count(Appointment.id).label('total_appointments'),
        func.sum(func.case((Appointment.status == 'completed', 1), else_=0)).label('completed'),
        func.sum(func.case((Appointment.status == 'cancelled', 1), else_=0)).label('cancelled')
    ).join(Doctor, User.id == Doctor.user_id).join(
        Appointment, Doctor.id == Appointment.doctor_id
    )
    
    if date_from:
        try:
            query = query.filter(Appointment.appointment_date >= datetime.strptime(date_from, '%Y-%m-%d').date())
        except ValueError:
            pass
    
    if date_to:
        try:
            query = query.filter(Appointment.appointment_date <= datetime.strptime(date_to, '%Y-%m-%d').date())
        except ValueError:
            pass
    
    results = query.group_by(User.full_name, Doctor.id).order_by(func.count(Appointment.id).desc()).all()
    
    doctor_stats = []
    for full_name, doctor_id, total, completed, cancelled in results:
        doctor_stats.append({
            'doctor_name': full_name,
            'doctor_id': doctor_id,
            'total_appointments': total,
            'completed': completed,
            'cancelled': cancelled,
            'completion_rate': round((completed / total * 100) if total > 0 else 0, 2)
        })
    
    return jsonify(doctor_stats), 200

# =============================================
# REVENUE STATISTICS
# =============================================

@stats_bp.route('/revenue/overview', methods=['GET'])
@jwt_required()
@admin_required
def get_revenue_overview():
    """Tổng quan doanh thu"""
    today = date.today()
    this_month_start = today.replace(day=1)
    this_year_start = today.replace(month=1, day=1)
    
    # Doanh thu hôm nay
    revenue_today = db.session.query(func.sum(Payment.amount)).filter(
        Payment.payment_status == 'completed',
        func.date(Payment.payment_date) == today
    ).scalar() or Decimal(0)
    
    # Doanh thu tháng này
    revenue_this_month = db.session.query(func.sum(Payment.amount)).filter(
        Payment.payment_status == 'completed',
        Payment.payment_date >= this_month_start
    ).scalar() or Decimal(0)
    
    # Doanh thu năm nay
    revenue_this_year = db.session.query(func.sum(Payment.amount)).filter(
        Payment.payment_status == 'completed',
        Payment.payment_date >= this_year_start
    ).scalar() or Decimal(0)
    
    # Tổng doanh thu
    revenue_total = db.session.query(func.sum(Payment.amount)).filter(
        Payment.payment_status == 'completed'
    ).scalar() or Decimal(0)
    
    # Số lượng giao dịch
    payment_count = Payment.query.filter_by(payment_status='completed').count()
    
    return jsonify({
        'today': str(revenue_today),
        'this_month': str(revenue_this_month),
        'this_year': str(revenue_this_year),
        'total': str(revenue_total),
        'transaction_count': payment_count
    }), 200

@stats_bp.route('/revenue/monthly', methods=['GET'])
@jwt_required()
@admin_required
def get_monthly_revenue():
    """Doanh thu theo tháng trong năm"""
    year = request.args.get('year', datetime.now().year, type=int)
    
    monthly_revenue = db.session.query(
        extract('month', Payment.payment_date).label('month'),
        func.sum(Payment.amount).label('revenue'),
        func.count(Payment.id).label('count')
    ).filter(
        Payment.payment_status == 'completed',
        extract('year', Payment.payment_date) == year
    ).group_by(extract('month', Payment.payment_date)).order_by('month').all()
    
    # Tạo dữ liệu cho tất cả 12 tháng
    monthly_data = []
    revenue_by_month = {int(month): (float(revenue), count) for month, revenue, count in monthly_revenue}
    
    for month in range(1, 13):
        revenue, count = revenue_by_month.get(month, (0.0, 0))
        monthly_data.append({
            'month': month,
            'month_name': datetime(year, month, 1).strftime('%B'),
            'revenue': revenue,
            'transaction_count': count
        })
    
    total_revenue = sum(item['revenue'] for item in monthly_data)
    
    return jsonify({
        'year': year,
        'total_revenue': total_revenue,
        'monthly': monthly_data
    }), 200

@stats_bp.route('/revenue/by-service', methods=['GET'])
@jwt_required()
@admin_required
def get_revenue_by_service():
    """Doanh thu theo dịch vụ"""
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    query = db.session.query(
        Service.name,
        func.sum(PaymentItem.total_price).label('revenue'),
        func.sum(PaymentItem.quantity).label('quantity')
    ).join(PaymentItem, Service.id == PaymentItem.service_id).join(
        Payment, PaymentItem.payment_id == Payment.id
    ).filter(Payment.payment_status == 'completed')
    
    if date_from:
        try:
            query = query.filter(Payment.payment_date >= datetime.strptime(date_from, '%Y-%m-%d'))
        except ValueError:
            pass
    
    if date_to:
        try:
            query = query.filter(Payment.payment_date <= datetime.strptime(date_to, '%Y-%m-%d'))
        except ValueError:
            pass
    
    results = query.group_by(Service.name).order_by(func.sum(PaymentItem.total_price).desc()).all()
    
    service_revenue = []
    for service_name, revenue, quantity in results:
        service_revenue.append({
            'service_name': service_name,
            'revenue': str(revenue),
            'quantity': quantity
        })
    
    total_revenue = sum(float(item['revenue']) for item in service_revenue)
    
    return jsonify({
        'total_revenue': str(total_revenue),
        'services': service_revenue
    }), 200

# =============================================
# PATIENT STATISTICS
# =============================================

@stats_bp.route('/patients/overview', methods=['GET'])
@jwt_required()
@admin_required
def get_patient_overview():
    """Tổng quan bệnh nhân"""
    
    today = date.today()
    this_month_start = today.replace(day=1)
    this_year_start = today.replace(month=1, day=1)
    
    # Tổng số bệnh nhân
    total_patients = Patient.query.count()
    
    # Bệnh nhân mới trong tháng
    new_this_month = Patient.query.filter(
        Patient.created_at >= this_month_start
    ).count()
    
    # Bệnh nhân mới trong năm
    new_this_year = Patient.query.filter(
        Patient.created_at >= this_year_start
    ).count()
    
    # Thống kê theo giới tính
    gender_stats = db.session.query(
        User.gender,
        func.count(Patient.id).label('count')
    ).join(User, Patient.user_id == User.id).group_by(User.gender).all()
    
    gender_data = {gender: count for gender, count in gender_stats if gender}
    
    # Thống kê theo nhóm tuổi
    age_groups = {
        '0-5': 0,
        '6-12': 0,
        '13-18': 0,
        '18+': 0
    }
    
    patients_with_dob = db.session.query(User.date_of_birth).join(
        Patient, User.id == Patient.user_id
    ).filter(User.date_of_birth.isnot(None)).all()
    
    for (dob,) in patients_with_dob:
        if dob:
            age = (today - dob).days // 365
            if age <= 5:
                age_groups['0-5'] += 1
            elif age <= 12:
                age_groups['6-12'] += 1
            elif age <= 18:
                age_groups['13-18'] += 1
            else:
                age_groups['18+'] += 1
    
    return jsonify({
        'total': total_patients,
        'new_this_month': new_this_month,
        'new_this_year': new_this_year,
        'by_gender': gender_data,
        'by_age_group': age_groups
    }), 200

@stats_bp.route('/patients/growth', methods=['GET'])
@jwt_required()
@admin_required
def get_patient_growth():
    """Tăng trưởng bệnh nhân theo tháng"""
    year = request.args.get('year', datetime.now().year, type=int)
    
    monthly_growth = db.session.query(
        extract('month', Patient.created_at).label('month'),
        func.count(Patient.id).label('count')
    ).filter(
        extract('year', Patient.created_at) == year
    ).group_by(extract('month', Patient.created_at)).order_by('month').all()
    
    growth_by_month = {int(month): count for month, count in monthly_growth}
    
    monthly_data = []
    cumulative = 0
    
    for month in range(1, 13):
        new_patients = growth_by_month.get(month, 0)
        cumulative += new_patients
        monthly_data.append({
            'month': month,
            'month_name': datetime(year, month, 1).strftime('%B'),
            'new_patients': new_patients,
            'cumulative': cumulative
        })
    
    return jsonify({
        'year': year,
        'monthly': monthly_data,
        'total_new': cumulative
    }), 200

# =============================================
# DOCTOR PERFORMANCE
# =============================================

@stats_bp.route('/doctors/performance', methods=['GET'])
@jwt_required()
@admin_required
def get_doctor_performance():
    """Hiệu suất làm việc của bác sĩ"""
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    query = db.session.query(
        User.full_name,
        Doctor.id,
        Department.name.label('department_name'),
        func.count(Appointment.id).label('total_appointments'),
        func.sum(func.case((Appointment.status == 'completed', 1), else_=0)).label('completed'),
        func.avg(Review.rating).label('avg_rating'),
        func.count(Review.id).label('review_count')
    ).join(Doctor, User.id == Doctor.user_id).join(
        Department, Doctor.department_id == Department.id
    ).outerjoin(
        Appointment, Doctor.id == Appointment.doctor_id
    ).outerjoin(
        Review, Doctor.id == Review.doctor_id
    )
    
    if date_from:
        try:
            query = query.filter(
                or_(
                    Appointment.appointment_date >= datetime.strptime(date_from, '%Y-%m-%d').date(),
                    Appointment.appointment_date.is_(None)
                )
            )
        except ValueError:
            pass
    
    if date_to:
        try:
            query = query.filter(
                or_(
                    Appointment.appointment_date <= datetime.strptime(date_to, '%Y-%m-%d').date(),
                    Appointment.appointment_date.is_(None)
                )
            )
        except ValueError:
            pass
    
    results = query.group_by(
        User.full_name, Doctor.id, Department.name
    ).order_by(func.count(Appointment.id).desc()).all()
    
    performance_data = []
    for full_name, doctor_id, dept_name, total_apps, completed, avg_rating, review_count in results:
        performance_data.append({
            'doctor_name': full_name,
            'doctor_id': doctor_id,
            'department': dept_name,
            'total_appointments': total_apps or 0,
            'completed_appointments': completed or 0,
            'completion_rate': round((completed / total_apps * 100) if total_apps and total_apps > 0 else 0, 2),
            'average_rating': round(float(avg_rating) if avg_rating else 0, 2),
            'review_count': review_count or 0
        })
    
    return jsonify(performance_data), 200

# =============================================
# DEPARTMENT STATISTICS
# =============================================

@stats_bp.route('/departments/statistics', methods=['GET'])
@jwt_required()
@admin_required
def get_department_statistics():
    """Thống kê theo chuyên khoa"""
    
    dept_stats = db.session.query(
        Department.name,
        Department.id,
        func.count(func.distinct(Doctor.id)).label('doctor_count'),
        func.count(Appointment.id).label('appointment_count'),
        func.sum(func.case((Appointment.status == 'completed', 1), else_=0)).label('completed_count')
    ).outerjoin(
        Doctor, Department.id == Doctor.department_id
    ).outerjoin(
        Appointment, Department.id == Appointment.department_id
    ).group_by(Department.name, Department.id).order_by(
        func.count(Appointment.id).desc()
    ).all()
    
    results = []
    for dept_name, dept_id, doctor_count, appt_count, completed in dept_stats:
        results.append({
            'department_name': dept_name,
            'department_id': dept_id,
            'doctor_count': doctor_count or 0,
            'appointment_count': appt_count or 0,
            'completed_appointments': completed or 0
        })
    
    return jsonify(results), 200

# Import PaymentItem
from models import PaymentItem