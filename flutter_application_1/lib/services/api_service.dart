import 'dart:convert';
import 'package:http/http.dart' as http;
// Thay thế 'package:flutter_secure_storage/flutter_secure_storage.dart' bằng 'package:shared_preferences/shared_preferences.dart'
// vì flutter_secure_storage không được phép sử dụng trong môi trường sandbox.
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Đảm bảo IP này là chính xác
  // Sử dụng IP VÀ CỔNG CỦA MÁY TÍNH WINDOWS
  static const String baseUrl = 'http://192.168.100.151:5000/api';

  // Thay đổi storage mechanism
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        return {'success': true, 'data': data};
      } else {
        // Xử lý trường hợp lỗi (401 Bad credentials)
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      // Xử lý lỗi kết nối
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    await deleteToken();
  }

  // === PUBLIC APIS ===

  // Get departments
  Future<Map<String, dynamic>> getDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/public/departments'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load departments'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get doctors by department
  Future<Map<String, dynamic>> getDoctors({int? departmentId}) async {
    try {
      var url = '$baseUrl/public/doctors';
      if (departmentId != null) {
        url += '?department_id=$departmentId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load doctors'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get available slots
  Future<Map<String, dynamic>> getAvailableSlots(
      int doctorId, String date) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/booking/doctors/$doctorId/available-slots?date=$date'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        // Xử lý lỗi 404 (Doctor not scheduled on this day) hoặc lỗi khác
        return {
          'success': false,
          'error': jsonDecode(response.body)['msg'] ?? 'Failed to load slots'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Create appointment
  Future<Map<String, dynamic>> createAppointment(
      Map<String, dynamic> appointmentData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/booking/appointments'),
        headers: await getHeaders(),
        body: jsonEncode(appointmentData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        // Xử lý lỗi 409 (Slot already booked) hoặc lỗi 400
        final body = jsonDecode(response.body);
        final msg = body['msg'] ?? 'Booking failed';

        // If server returns an invalid-token error (migration from old tokens),
        // clear stored token so the app forces a login and obtains a new token.
        if (response.statusCode == 422 ||
            msg.toString().toLowerCase().contains('subject must be a string') ||
            msg.toString().toLowerCase().contains('invalid token') ||
            msg.toString().toLowerCase().contains('token')) {
          await deleteToken();
          return {
            'success': false,
            'error': 'Authentication error. Please log in again.'
          };
        }

        return {'success': false, 'error': msg};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // === ADMIN/STATS APIS ===

  // Get dashboard overview
  Future<Map<String, dynamic>> getDashboardOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/dashboard/overview'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error': jsonDecode(response.body)['msg'] ?? 'Failed to load data'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Create a payment record (pending)
  Future<Map<String, dynamic>> createPaymentRecord(
      int appointmentId, double amount, String provider) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/create'),
        headers: await getHeaders(),
        body: jsonEncode({
          'appointment_id': appointmentId,
          'amount': amount,
          'provider': provider,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to create payment record'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Initiate MoMo payment and get redirect URL
  Future<Map<String, dynamic>> initiateMomoPayment(int paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/momo/create'),
        headers: await getHeaders(),
        body: jsonEncode({'payment_id': paymentId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to initiate MoMo'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Check payment status by payment code
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/status?payment_code=$paymentCode'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to check status'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
