import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _error;
  bool _isLoading = false;
  bool _isInitialized = false;

  AuthService(this._apiService);

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // 🛑 SỬA LỖI: KHÔI PHỤC THÔNG TIN USER (ROLE) VÀ XỬ LÝ TOKEN MẤT ĐỒNG BỘ
  Future<void> init() async {
    final token = await _apiService.getToken();
    final userData = await _apiService.getUserData(); // Lấy user data đã lưu

    if (token != null && userData != null) {
      _isAuthenticated = true;
      _user = userData; // Khôi phục thông tin người dùng và vai trò
    } else {
      // Nếu có token mà thiếu user data (hoặc ngược lại), xóa hết để đảm bảo sạch sẽ
      // Điều này ngăn lỗi khi profile cố gắng tải với token cũ nhưng thiếu role
      await _apiService.deleteToken();
      _isAuthenticated = false;
    }

    _isInitialized = true;
    notifyListeners();
  }

  //
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.login(username, password);

      if (result['success']) {
        _isAuthenticated = true;
        _user = result['data']['user']; // Lấy user data từ kết quả login

        // 🛑 LƯU Ý: Phải đảm bảo ApiService.login đã gọi saveUser(user)

        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Lỗi kết nối: ${e.toString()}'; // Thông báo lỗi rõ ràng hơn
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _apiService.logout(); // Gọi deleteToken() (cũng xóa user_data)
    _isAuthenticated = false;
    _user = null;
    notifyListeners(); // Kích hoạt HospitalBookingApp chuyển về LoginScreen
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
