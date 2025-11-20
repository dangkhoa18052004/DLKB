// api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Đảm bảo IP này là chính xác
  static const String baseUrl = 'http://192.168.100.151:5000/api';

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

  // Get services
  Future<Map<String, dynamic>> getServices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/public/services'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load services'};
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

        // Xử lý lỗi token hết hạn
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

  // Cancel appointment
  Future<Map<String, dynamic>> cancelAppointment(
      int appointmentId, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/booking/appointments/$appointmentId/cancel'),
        headers: await getHeaders(),
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {'success': false, 'error': body['msg'] ?? 'Hủy lịch thất bại'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Reschedule appointment
  Future<Map<String, dynamic>> rescheduleAppointment(
      int appointmentId, String newDate, String newTime) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/patient/appointments/$appointmentId/reschedule'),
        headers: await getHeaders(),
        body: jsonEncode({
          'new_date': newDate,
          'new_time': newTime,
          'reason': 'Rescheduled by patient via app'
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {'success': false, 'error': body['msg'] ?? 'Đổi lịch thất bại'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get my appointments
  Future<Map<String, dynamic>> getMyAppointments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/booking/appointments/me'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get my medical records
  Future<Map<String, dynamic>> getMedicalRecords() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patient/medical-records'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body)['medical_records']
        };
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get my profile
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/patient/profile'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get my notifications
  Future<Map<String, dynamic>> getMyNotifications(
      {int page = 1, int perPage = 20, bool unreadOnly = false}) async {
    try {
      final url = Uri.parse(
          '$baseUrl/notifications/my-notifications?page=$page&per_page=$perPage&unread_only=${unreadOnly ? 'true' : 'false'}');
      final response = await http.get(url, headers: await getHeaders());

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to load notifications'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> markNotificationAsRead(
      int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to mark read'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteNotification(int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {'success': false, 'error': body['msg'] ?? 'Failed to delete'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Update my profile
  Future<Map<String, dynamic>> updateMyProfile(
      Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/patient/profile'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(String currentPassword,
      String newPassword, String confirmPassword) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/patient/change-password'),
        headers: await getHeaders(),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
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

      if (response.statusCode == 201) {
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
      final url = '$baseUrl/payment/initiate-momo';

      print('==============================================');
      print('🔵 [DEBUG] Base URL: $baseUrl');
      print('🔵 [DEBUG] Full URL: $url');
      print('🔵 [DEBUG] Payment ID: $paymentId');
      print('==============================================');

      final response = await http.post(
        Uri.parse(url),
        headers: await getHeaders(),
        body: jsonEncode({'payment_id': paymentId}),
      );

      print('[API] MoMo Response: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to initiate MoMo',
        };
      }
    } catch (e) {
      print('[API ERROR] initiateMomoPayment: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
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

  // ===================================
  // === REVIEW & FEEDBACK APIs (NEW) ===
  // ===================================

  // 1. Get My Reviews (Endpoint: /patient/reviews/my)
  Future<Map<String, dynamic>> getMyReviews() async {
    try {
      // Đã sửa URL để khớp với Blueprint: /api/patient/reviews/my
      final response = await http.get(
        Uri.parse('$baseUrl/patient/reviews/my'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(response.body);

        // Vì patient_routes.py trả về List trực tiếp, ta cần xử lý List này
        return {
          'success': true,
          'data': decodedBody is List ? decodedBody : []
        };
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to load reviews'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 2. Submit Review (Endpoint: /general/reviews)
  Future<Map<String, dynamic>> submitReview(
      Map<String, dynamic> reviewData) async {
    try {
      // Đã sửa URL để khớp với Blueprint: /api/general/reviews
      final response = await http.post(
        Uri.parse('$baseUrl/general/reviews'),
        headers: await getHeaders(),
        body: jsonEncode(reviewData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to submit review'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 3. Submit Feedback (Endpoint: /general/feedback)
  Future<Map<String, dynamic>> submitFeedback(
      Map<String, dynamic> feedbackData) async {
    try {
      // Đã sửa URL để khớp với Blueprint: /api/general/feedback
      final response = await http.post(
        Uri.parse('$baseUrl/general/feedback'),
        headers: await getHeaders(),
        body: jsonEncode(feedbackData),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['msg'] ?? 'Failed to submit feedback'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
