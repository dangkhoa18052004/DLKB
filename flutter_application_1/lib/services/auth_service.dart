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

  Future<void> init() async {
    final token = await _apiService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      _user = {'full_name': 'Người Dùng', 'role': 'patient'};
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
        _user = result['data']['user'];
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
    await _apiService.logout();
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
