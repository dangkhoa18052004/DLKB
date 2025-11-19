from flask import Flask, jsonify
from flask_jwt_extended import JWTManager
from config import Config
from models import SystemSetting, db, bcrypt
from routes.auth_routes import auth_bp
from routes.public_routes import public_bp
from routes.booking_routes import booking_bp
from routes.general_routes import general_bp
from utils import log_activity, generate_code, get_system_setting
import click

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Khởi tạo các phần mở rộng
    db.init_app(app)
    bcrypt.init_app(app)
    JWTManager(app)

    # Đăng ký Blueprints (Routes)
    # Prefix /api/v1/ là chuẩn cho API phiên bản 1
    app.register_blueprint(auth_bp, url_prefix='/api/v1/auth')
    app.register_blueprint(public_bp, url_prefix='/api/v1/public')
    app.register_blueprint(booking_bp, url_prefix='/api/v1/booking')
    app.register_blueprint(general_bp, url_prefix='/api/v1/general')
    
    # Định nghĩa lệnh CLI để tạo DB
    @app.cli.command("init-db")
    def init_db():
        """Tạo các bảng CSDL và chèn dữ liệu mẫu nếu cần"""
        with app.app_context():
            try:
                db.create_all()
                
                # Chèn SystemSettings nếu chưa có
                if not get_system_setting('hospital_name'):
                    db.session.add_all([
                        # Sử dụng các giá trị mặc định từ SQL schema của bạn
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
    app.run(debug=True)