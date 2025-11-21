from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, Notification, User
from utils import log_activity
from datetime import datetime
from sqlalchemy import or_

notification_bp = Blueprint('notification', __name__)

# =============================================
# USER NOTIFICATIONS
# =============================================

@notification_bp.route('/my-notifications', methods=['GET'])
@jwt_required()
def get_my_notifications():
    """Lấy danh sách thông báo của người dùng"""
    user_id = get_jwt_identity()
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    unread_only = request.args.get('unread_only', 'false').lower() == 'true'
    notification_type = request.args.get('type')
    
    query = Notification.query.filter_by(user_id=user_id)
    
    if unread_only:
        query = query.filter_by(is_read=False)
    
    if notification_type:
        query = query.filter_by(type=notification_type)
    
    pagination = query.order_by(Notification.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )
    
    results = []
    for notif in pagination.items:
        results.append({
            'id': notif.id,
            'title': notif.title,
            'message': notif.message,
            'type': notif.type,
            'reference_id': notif.reference_id,
            'reference_type': notif.reference_type,
            'is_read': notif.is_read,
            'read_at': notif.read_at.strftime('%Y-%m-%d %H:%M:%S') if notif.read_at else None,
            'created_at': notif.created_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'notifications': results,
        'total': pagination.total,
        'unread_count': Notification.query.filter_by(user_id=user_id, is_read=False).count(),
        'pages': pagination.pages,
        'current_page': page
    }), 200

@notification_bp.route('/<int:notification_id>/read', methods=['PUT'])
@jwt_required()
def mark_as_read(notification_id):
    """Đánh dấu thông báo đã đọc"""
    user_id = get_jwt_identity()
    
    notification = Notification.query.filter_by(id=notification_id, user_id=user_id).first()
    
    if not notification:
        return jsonify({"msg": "Notification not found"}), 404
    
    if not notification.is_read:
        notification.is_read = True
        notification.read_at = datetime.utcnow()
        
        try:
            db.session.commit()
            return jsonify({"msg": "Notification marked as read"}), 200
        except Exception as e:
            db.session.rollback()
            return jsonify({"msg": f"Error: {str(e)}"}), 500
    
    return jsonify({"msg": "Notification already read"}), 200

@notification_bp.route('/mark-all-read', methods=['PUT'])
@jwt_required()
def mark_all_as_read():
    """Đánh dấu tất cả thông báo đã đọc"""
    user_id = get_jwt_identity()
    
    try:
        Notification.query.filter_by(user_id=user_id, is_read=False).update({
            'is_read': True,
            'read_at': datetime.utcnow()
        })
        db.session.commit()
        
        return jsonify({"msg": "All notifications marked as read"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error: {str(e)}"}), 500
    
@notification_bp.route('/admin/sent-history', methods=['GET'])
@jwt_required()
def get_sent_history():
    """Admin xem lịch sử tất cả thông báo đã gửi"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role != 'admin':
        return jsonify({"msg": "Admin access required"}), 403
    
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 50, type=int)
    notification_type = request.args.get('type')  # Filter by type
    target_role = request.args.get('target_role')  # Filter by target_role
    
    # Query tất cả notifications (group by title + message + created_at để tránh duplicate)
    query = db.session.query(
        Notification.title,
        Notification.message,
        Notification.type,
        Notification.target_role,
        Notification.sender_id,
        db.func.count(Notification.id).label('recipient_count'),
        db.func.max(Notification.created_at).label('sent_at')
    ).filter(
        Notification.sender_id.isnot(None)  # Chỉ lấy notifications có sender
    )
    
    # Apply filters
    if notification_type:
        query = query.filter(Notification.type == notification_type)
    
    if target_role:
        query = query.filter(Notification.target_role == target_role)
    
    # Group by để gộp các broadcast notifications
    query = query.group_by(
        Notification.title,
        Notification.message,
        Notification.type,
        Notification.target_role,
        Notification.sender_id,
        db.func.date(Notification.created_at)  # Group by date
    ).order_by(db.desc('sent_at'))
    
    # Paginate
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)
    
    results = []
    for item in pagination.items:
        sender = User.query.get(item.sender_id) if item.sender_id else None
        results.append({
            'title': item.title,
            'message': item.message,
            'type': item.type,
            'target_role': item.target_role,
            'recipient_count': item.recipient_count,
            'sender_name': sender.full_name if sender else 'System',
            'sent_at': item.sent_at.strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({
        'notifications': results,
        'total': pagination.total,
        'pages': pagination.pages,
        'current_page': page
    }), 200


@notification_bp.route('/<int:notification_id>', methods=['DELETE'])
@jwt_required()
def delete_notification(notification_id):
    """Xóa thông báo"""
    user_id = get_jwt_identity()
    
    notification = Notification.query.filter_by(id=notification_id, user_id=user_id).first()
    
    if not notification:
        return jsonify({"msg": "Notification not found"}), 404
    
    try:
        db.session.delete(notification)
        db.session.commit()
        return jsonify({"msg": "Notification deleted successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error: {str(e)}"}), 500

@notification_bp.route('/unread-count', methods=['GET'])
@jwt_required()
def get_unread_count():
    """Lấy số lượng thông báo chưa đọc"""
    user_id = get_jwt_identity()
    
    count = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    
    return jsonify({
        'unread_count': count
    }), 200

# =============================================
# ADMIN - CREATE NOTIFICATIONS
# =============================================

@notification_bp.route('/send', methods=['POST'])
@jwt_required()
def send_notification():
    """Gửi thông báo (Admin hoặc System)"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role not in ['admin', 'staff']:
        return jsonify({"msg": "Permission denied"}), 403
    
    data = request.get_json()
    
    required_fields = ['recipient_id', 'title', 'message']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    new_notification = Notification(
        user_id=data['recipient_id'],
        sender_id=user_id,  # ✅ Thêm sender_id
        title=data['title'],
        message=data['message'],
        type=data.get('type', 'system'),
        reference_id=data.get('reference_id'),
        reference_type=data.get('reference_type'),
        sent_via=data.get('sent_via', 'in_app')
    )
    
    try:
        db.session.add(new_notification)
        db.session.commit()
        log_activity(user_id, "SEND_NOTIFICATION", "notification", new_notification.id, 
                    f"Sent notification to user {data['recipient_id']}")
        
        return jsonify({
            "msg": "Notification sent successfully",
            "notification_id": new_notification.id
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error sending notification: {str(e)}"}), 500

@notification_bp.route('/broadcast', methods=['POST'])
@jwt_required()
def broadcast_notification():
    """Gửi thông báo hàng loạt (Broadcast)"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role != 'admin':
        return jsonify({"msg": "Admin access required"}), 403
    
    data = request.get_json()
    
    required_fields = ['title', 'message']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    target_role = data.get('target_role', 'all')
    
    query = User.query.filter_by(is_active=True)
    
    if target_role and target_role != 'all':
        query = query.filter_by(role=target_role)
    
    users = query.all()
    
    notifications = []
    for target_user in users:
        notification = Notification(
            user_id=target_user.id,
            sender_id=user_id,  # ✅ Thêm sender_id
            title=data['title'],
            message=data['message'],
            type=data.get('type', 'system'),
            target_role=target_role,  # ✅ Lưu target_role
            sent_via='in_app'
        )
        notifications.append(notification)
    
    try:
        db.session.add_all(notifications)
        db.session.commit()
        log_activity(user_id, "BROADCAST_NOTIFICATION", "notification", None, 
                    f"Broadcasted notification to {len(notifications)} users (role: {target_role})")
        
        return jsonify({
            "msg": "Notification broadcasted successfully",
            "sent_count": len(notifications)
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error broadcasting notification: {str(e)}"}), 500


@notification_bp.route('/admin/broadcast/update', methods=['PUT'])  # ✅ Đổi từ /<int:id> sang /update
@jwt_required()
def update_broadcast_notification():
    """Admin cập nhật thông báo broadcast đã gửi"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role != 'admin':
        return jsonify({"msg": "Admin access required"}), 403
    
    data = request.get_json()
    
    required_fields = ['old_title', 'old_message', 'sent_date', 'title', 'message']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    # Parse date
    try:
        sent_date = datetime.strptime(data['sent_date'], '%Y-%m-%d').date()
    except:
        return jsonify({"msg": "Invalid date format"}), 400
    
    # Tìm tất cả notifications cùng nhóm
    notifications_to_update = Notification.query.filter(
        Notification.title == data['old_title'],
        Notification.message == data['old_message'],
        db.func.date(Notification.created_at) == sent_date,
        Notification.sender_id == user_id
    ).all()
    
    if not notifications_to_update:
        return jsonify({"msg": "Notifications not found"}), 404
    
    try:
        for notif in notifications_to_update:
            notif.title = data['title']
            notif.message = data['message']
            if 'type' in data:
                notif.type = data['type']
        
        db.session.commit()
        
        log_activity(user_id, "UPDATE_BROADCAST", "notification", None, 
                    f"Updated {len(notifications_to_update)} notifications")
        
        return jsonify({
            "msg": "Notifications updated successfully",
            "updated_count": len(notifications_to_update)
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error updating notifications: {str(e)}"}), 500
    
@notification_bp.route('/admin/broadcast/delete', methods=['DELETE'])
@jwt_required()
def delete_broadcast_notification():
    """Admin xóa thông báo broadcast đã gửi"""
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if user.role != 'admin':
        return jsonify({"msg": "Admin access required"}), 403
    
    data = request.get_json()
    
    required_fields = ['title', 'message', 'sent_date']
    if not all(field in data for field in required_fields):
        return jsonify({"msg": "Missing required fields"}), 400
    
    # Parse date
    try:
        sent_date = datetime.strptime(data['sent_date'], '%Y-%m-%d').date()
    except:
        return jsonify({"msg": "Invalid date format"}), 400
    
    # Tìm tất cả notifications cùng nhóm
    notifications_to_delete = Notification.query.filter(
        Notification.title == data['title'],
        Notification.message == data['message'],
        db.func.date(Notification.created_at) == sent_date,
        Notification.sender_id == user_id
    ).all()
    
    if not notifications_to_delete:
        return jsonify({"msg": "Notifications not found"}), 404
    
    try:
        count = len(notifications_to_delete)
        for notif in notifications_to_delete:
            db.session.delete(notif)
        
        db.session.commit()
        
        log_activity(user_id, "DELETE_BROADCAST", "notification", None, 
                    f"Deleted {count} notifications")
        
        return jsonify({
            "msg": "Notifications deleted successfully",
            "deleted_count": count
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": f"Error deleting notifications: {str(e)}"}), 500
# =============================================
# UTILITY FUNCTIONS
# =============================================

def create_appointment_notification(user_id, appointment_id, title, message, notification_type='appointment'):
    """Helper function để tạo thông báo appointment"""
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=notification_type,
        reference_id=appointment_id,
        reference_type='appointment',
        sent_via='in_app'
    )
    
    try:
        db.session.add(notification)
        db.session.commit()
        return True
    except Exception as e:
        db.session.rollback()
        print(f"Error creating notification: {e}")
        return False

def create_payment_notification(user_id, payment_id, title, message):
    """Helper function để tạo thông báo payment"""
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type='payment',
        reference_id=payment_id,
        reference_type='payment',
        sent_via='in_app'
    )
    
    try:
        db.session.add(notification)
        db.session.commit()
        return True
    except Exception as e:
        db.session.rollback()
        print(f"Error creating notification: {e}")
        return False