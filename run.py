from flask import Flask, jsonify
from flask_jwt_extended import JWTManager
from config import Config
from dotenv import load_dotenv
from flask_migrate import Migrate
from models import SystemSetting, db, bcrypt
from routes.auth_routes import auth_bp
from routes.public_routes import public_bp
from routes.booking_routes import booking_bp
from routes.general_routes import general_bp
from routes.payment_routers import payment_bp      
from routes.doctor_routers import doctor_bp        
from routes.patient_routes import patient_bp      
from routes.admin_routers import admin_bp        
from routes.password_reset_routers import password_reset_bp 
from routes.notification_routers import notification_bp 
from routes.search_routers import search_bp     
from routes.stats_routers import stats_bp      
from utils import log_activity, generate_code, get_system_setting
import click

def create_app(config_class=Config):
    load_dotenv()
    app = Flask(__name__) 
    app.config.from_object(config_class)

    db.init_app(app)
    bcrypt.init_app(app)
    jwt = JWTManager(app)
    migrate = Migrate(app, db)  

    # JWT Error Handlers (Giữ nguyên)
    @jwt.unauthorized_loader
    def _unauthorized_callback(msg):
        print(f"[JWT] Unauthorized: {msg}")
        return jsonify({"msg": msg}), 401

    @jwt.invalid_token_loader
    def _invalid_token_callback(msg):
        print(f"[JWT] Invalid token: {msg}")
        return jsonify({"msg": msg}), 422

    @jwt.expired_token_loader
    def _expired_token_callback(header, payload):
        print("[JWT] Token expired")
        return jsonify({"msg": "Token has expired"}), 401

    @jwt.revoked_token_loader
    def _revoked_token_callback(payload):
        print("[JWT] Token revoked")
        return jsonify({"msg": "Token has been revoked"}), 401

    # --- ĐĂNG KÝ TẤT CẢ CÁC BLUEPRINTS (Đã xóa /v1) ---
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(public_bp, url_prefix='/api/public')
    app.register_blueprint(booking_bp, url_prefix='/api/booking')
    app.register_blueprint(general_bp, url_prefix='/api/general')

    # Patient, Doctor, Admin Routes
    app.register_blueprint(patient_bp, url_prefix='/api/patient')
    app.register_blueprint(doctor_bp, url_prefix='/api/doctor')
    app.register_blueprint(admin_bp, url_prefix='/api/admin')

    # Utility & Transaction Routes
    app.register_blueprint(payment_bp, url_prefix='/api/payment')
    app.register_blueprint(password_reset_bp, url_prefix='/api/auth/reset')
    app.register_blueprint(notification_bp, url_prefix='/api/notifications')
    app.register_blueprint(search_bp, url_prefix='/api/search')
    app.register_blueprint(stats_bp, url_prefix='/api/stats')
    
    @app.cli.command("init-db")
    def init_db():
        """Tạo các bảng CSDL và chèn dữ liệu mẫu nếu cần"""
        with app.app_context():
            try:
                db.create_all()
                
                if not get_system_setting('hospital_name'):
                    from models import SystemSetting 
                    db.session.add_all([
                        SystemSetting(key='hospital_name', value='Bệnh viện Nhi Đồng II TP.HCM', description='Tên bệnh viện'),
                        SystemSetting(key='appointment_buffer_minutes', value='15', description='Khoảng cách giữa các lịch hẹn (phút)', data_type='integer'),
                        SystemSetting(key='cancellation_allowed_hours', value='24', description='Cho phép hủy lịch trước bao nhiêu giờ', data_type='integer'),
                    ])
                    db.session.commit()
                    click.echo("Default system settings inserted.")
                
                click.echo("Database tables created successfully!")
            except Exception as e:
                click.echo(f"Error creating database tables: {e}")

    return app


app = create_app()

if __name__ == '__main__':
    print("\n" + "="*60)
    print("📋 DANH SÁCH TẤT CẢ ROUTES ĐÃ ĐĂNG KÝ:")
    print("="*60)
    for rule in app.url_map.iter_rules():
        methods = ','.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
        print(f"{rule.endpoint:50s} {methods:10s} {rule.rule}")
    print("="*60 + "\n")
    
    app.run(debug=True, host='0.0.0.0', port=5000)