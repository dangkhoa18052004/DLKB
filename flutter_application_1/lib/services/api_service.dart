import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
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
    await prefs.remove('user_data'); // <<< XÓA USER DATA KHI ĐĂNG XUẤT
  }

  // === BỔ SUNG: LƯU VÀ TẢI USER DATA ===
  Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) {
      return jsonDecode(data);
    }
    return null;
  }
  // ======================================

  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getAppointmentStats({String? timeframe}) async {
    String endpoint = '/stats/appointments/daily';
    if (timeframe != null) {
      endpoint += '?timeframe=$timeframe';
    }
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> getRevenueStats({String? timeframe}) async {
    String endpoint = '/stats/revenue/overview';
    if (timeframe != null) {
      endpoint += '?timeframe=$timeframe';
    }
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> getPatientStats() async {
    return await _sendRequest('GET', '/stats/patients/overview', null);
  }

  Future<Map<String, dynamic>> getDoctorPerformance() async {
    return await _sendRequest('GET', '/stats/doctors/performance', null);
  }

  Future<Map<String, dynamic>> getDepartmentStats() async {
    return await _sendRequest('GET', '/stats/departments/statistics', null);
  }

  // ===================================
  // === HTTP CORE METHODS (NEW) ===
  // ===================================

  Future<Map<String, dynamic>> _sendRequest(
      String method, String endpoint, Map<String, dynamic>? data) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders();

    try {
      http.Response response;
      final body = data != null ? jsonEncode(data) : null;

      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: body);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers, body: body);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Xử lý phản hồi rỗng (ví dụ: 204 No Content)
      if (response.body.isEmpty &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        return {'success': true, 'data': {}};
      }

      final dynamic responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        // Trích xuất lỗi từ backend (thường là key 'msg' hoặc 'error')
        final errorMsg =
            responseBody['msg'] ?? responseBody['error'] ?? 'Lỗi máy chủ';
        return {
          'success': false,
          'error': errorMsg,
          'status_code': response.statusCode
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Lỗi kết nối: ${e.toString()}'};
    }
  }

  // Phương thức post wrapper (dùng cho POST /admin/users, /notification/send)
  Future<Map<String, dynamic>> post(
          String endpoint, Map<String, dynamic> data) =>
      _sendRequest('POST', endpoint, data);

  // Phương thức put wrapper (dùng cho PUT /admin/users/<id>, /notification/read)
  Future<Map<String, dynamic>> put(
          String endpoint, Map<String, dynamic> data) =>
      _sendRequest('PUT', endpoint, data);

  // Phương thức delete wrapper
  Future<Map<String, dynamic>> delete(String endpoint) =>
      _sendRequest('DELETE', endpoint, null);

  // ===================================
  // === AUTHENTICATION APIS ===
  // ===================================

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
        await saveUser(data['user']); // <<< LƯU USER DATA
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<void> logout() async {
    await deleteToken();
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    // Sử dụng hàm post mới
    return await post('/auth/reset/request', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword, String confirmPassword) async {
    return await post('/auth/reset/reset-password', {
      'token': token,
      'new_password': newPassword,
      'confirm_password': confirmPassword
    });
  }

  // === PUBLIC APIS ===

  Future<Map<String, dynamic>> getDepartments() async {
    // Sử dụng _sendRequest mới
    return await _sendRequest('GET', '/public/departments', null);
  }

  Future<Map<String, dynamic>> getServices() async {
    return await _sendRequest('GET', '/public/services', null);
  }

  Future<Map<String, dynamic>> getDoctors({int? departmentId}) async {
    String endpoint = '/public/doctors';
    if (departmentId != null) {
      endpoint += '?department_id=$departmentId';
    }
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> getAvailableSlots(
      int doctorId, String date) async {
    return await _sendRequest(
        'GET', '/booking/doctors/$doctorId/available-slots?date=$date', null);
  }

  Future<Map<String, dynamic>> createAppointment(
      Map<String, dynamic> appointmentData) async {
    // Sử dụng post mới
    return await post('/booking/appointments', appointmentData);
  }

  Future<Map<String, dynamic>> cancelAppointment(
      int appointmentId, String reason) async {
    // Sử dụng put mới
    return await put(
        '/booking/appointments/$appointmentId/cancel', {'reason': reason});
  }

  Future<Map<String, dynamic>> rescheduleAppointment(
      int appointmentId, String newDate, String newTime) async {
    return await put('/patient/appointments/$appointmentId/reschedule', {
      'new_date': newDate,
      'new_time': newTime,
      'reason': 'Rescheduled by patient via app'
    });
  }

  Future<Map<String, dynamic>> getMyAppointments(
      {required String date, String? status}) async {
    return await _sendRequest('GET', '/booking/appointments/me', null);
  }

  Future<Map<String, dynamic>> getMedicalRecords() async {
    // Backend trả về list trong key 'medical_records'
    final result = await _sendRequest('GET', '/patient/medical-records', null);
    if (result['success']) {
      // Điều chỉnh dữ liệu để trả về list trực tiếp
      return {'success': true, 'data': result['data']['medical_records'] ?? []};
    }
    return result;
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    return await _sendRequest('GET', '/patient/profile', null);
  }

  Future<Map<String, dynamic>> getMyNotifications(
      {int page = 1, int perPage = 20, bool unreadOnly = false}) async {
    String endpoint =
        '/notifications/my-notifications?page=$page&per_page=$perPage&unread_only=${unreadOnly ? 'true' : 'false'}';
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> markNotificationAsRead(
      int notificationId) async {
    return await put('/notifications/$notificationId/read', {});
  }

  Future<Map<String, dynamic>> deleteNotification(int notificationId) async {
    return await delete('/notifications/$notificationId');
  }

  Future<Map<String, dynamic>> updateMyProfile(
      Map<String, dynamic> data) async {
    return await put('/patient/profile', data);
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword,
      String newPassword, String confirmPassword) async {
    return await put('/patient/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
      'confirm_password': confirmPassword
    });
  }

  // ===================================
  // === ADMIN/STAFF APIS ===
  // ===================================

  // --- ADMIN DOCTORS ---
  Future<Map<String, dynamic>> getAdminDoctors({
    int page = 1,
    int perPage = 20,
    int? departmentId,
    bool? isAvailable,
  }) async {
    String endpoint = '/admin/doctors?page=$page&per_page=$perPage';

    if (departmentId != null) {
      endpoint += '&department_id=$departmentId';
    }
    if (isAvailable != null) {
      endpoint += '&is_available=$isAvailable';
    }
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> updateDoctor(
    int doctorId,
    Map<String, dynamic> data,
  ) async {
    return await put('/admin/doctors/$doctorId', data);
  }

  Future<Map<String, dynamic>> getDoctorSchedule(int doctorId) async {
    final result =
        await _sendRequest('GET', '/doctors/$doctorId/schedules', null);

    if (result['success']) {
      final data = result['data'];
      // API có thể trả về list hoặc object
      if (data is List) {
        return {'success': true, 'data': data};
      } else {
        // Giả sử nếu là object thì chứa key 'schedules' hoặc list trực tiếp
        return {'success': true, 'data': data['schedules'] ?? data};
      }
    }
    return result;
  }

  // --- ADMIN/STATS APIS ---
  Future<Map<String, dynamic>> getDashboardOverview() async {
    return await _sendRequest('GET', '/stats/dashboard/overview', null);
  }

  // Khắc phục lỗi: Gọi hàm post() đã được định nghĩa ở trên
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    return await post('/admin/users', userData);
  }

  // Khắc phục lỗi: Gọi hàm put() đã được định nghĩa ở trên
  Future<Map<String, dynamic>> updateUser(
      int userId, Map<String, dynamic> updateData) async {
    return await put('/admin/users/$userId', updateData);
  }

  Future<Map<String, dynamic>> getAllUsers() async {
    // Backend trả về list trong key 'users'
    final result = await _sendRequest('GET', '/admin/users', null);
    if (result['success']) {
      // Điều chỉnh dữ liệu để trả về cấu trúc mà AdminUserManagementScreen mong đợi
      return {'success': true, 'data': result['data']};
    }
    return result;
  }

  // ADMIN NOTIFICATION APIS

  Future<Map<String, dynamic>> getAdminSentHistory({
    int page = 1,
    int perPage = 50,
    String? type,
    String? targetRole,
  }) async {
    String endpoint =
        '/notifications/admin/sent-history?page=$page&per_page=$perPage';

    if (type != null) {
      endpoint += '&type=$type';
    }
    if (targetRole != null) {
      endpoint += '&target_role=$targetRole';
    }

    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> sendNotification(
      Map<String, dynamic> data) async {
    // Endpoint: POST /notification/send
    return await post('/notifications/send', data);
  }

  Future<Map<String, dynamic>> broadcastNotification(
      Map<String, dynamic> data) async {
    // Endpoint: POST /notification/broadcast
    return await post('/notifications/broadcast', data);
  }

  Future<Map<String, dynamic>> updateBroadcastNotification(
      Map<String, dynamic> data) async {
    // ✅ Bỏ notificationId parameter
    return await put(
        '/notifications/admin/broadcast/update', data); // ✅ Đổi endpoint
  }

  Future<Map<String, dynamic>> deleteBroadcastNotification({
    required String title,
    required String message,
    required String sentDate,
  }) async {
    return await _sendRequest(
        'DELETE', '/notifications/admin/broadcast/delete', {
      'title': title,
      'message': message,
      'sent_date': sentDate,
    });
  }

  Future<Map<String, dynamic>> getAdminReviews({
    int page = 1,
    int perPage = 20,
    bool? isApproved,
  }) async {
    String endpoint = '/admin/reviews?page=$page&per_page=$perPage';
    if (isApproved != null) {
      endpoint += '&is_approved=${isApproved ? 'true' : 'false'}';
    }
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> approveReview(int reviewId) async {
    // PUT /admin/reviews/<int:review_id>/approve
    return await put('/admin/reviews/$reviewId/approve', {});
  }

  Future<Map<String, dynamic>> deleteReview(int reviewId) async {
    // DELETE /admin/reviews/<int:review_id>
    return await delete('/admin/reviews/$reviewId');
  }

// --- ADMIN FEEDBACK MANAGEMENT ---

  Future<Map<String, dynamic>> getAdminFeedback({
    int page = 1,
    int perPage = 20,
    String? status,
    String? priority,
  }) async {
    String endpoint = '/admin/feedback?page=$page&per_page=$perPage';
    if (status != null) endpoint += '&status=$status';
    if (priority != null) endpoint += '&priority=$priority';

    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> respondToFeedback(
    int feedbackId,
    String responseMessage,
    String newStatus,
  ) async {
    return await put('/admin/feedback/$feedbackId/respond', {
      'response': responseMessage,
      'status': newStatus,
    });
  }

// --- ADMIN PAYMENT (GET STATUS) ---
  Future<Map<String, dynamic>> getAdminPaymentRecords({
    int page = 1,
    int perPage = 20,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    String endpoint = '/admin/payments?page=$page&per_page=$perPage';

    if (status != null) endpoint += '&status=$status';
    if (dateFrom != null) endpoint += '&date_from=$dateFrom';
    if (dateTo != null) endpoint += '&date_to=$dateTo';
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> getAdminAppointments({
    int page = 1,
    int perPage = 20,
    String? status,
    String? dateFrom,
    String? dateTo,
    int? doctorId,
    int? patientId,
  }) async {
    String endpoint = '/admin/appointments?page=$page&per_page=$perPage';

    if (status != null) endpoint += '&status=$status';
    if (dateFrom != null) endpoint += '&date_from=$dateFrom';
    if (dateTo != null) endpoint += '&date_to=$dateTo';
    if (doctorId != null) endpoint += '&doctor_id=$doctorId';
    if (patientId != null) endpoint += '&patient_id=$patientId';

    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> updateAppointmentStatus(
    int appointmentId,
    String newStatus, {
    String? reason,
  }) async {
    return await put('/admin/appointments/$appointmentId/status', {
      'status': newStatus,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> getAppointmentDetail(int appointmentId) async {
    return await _sendRequest(
        'GET', '/admin/appointments/$appointmentId', null);
  }

  Future<Map<String, dynamic>> getAllDepartments() async {
    return await _sendRequest('GET', '/admin/departments', null);
  }

  Future<Map<String, dynamic>> createDepartment(
      Map<String, dynamic> data) async {
    return await post('/admin/departments', data);
  }

  Future<Map<String, dynamic>> updateDepartment(
      int deptId, Map<String, dynamic> data) async {
    return await put('/admin/departments/$deptId', data);
  }

  Future<Map<String, dynamic>> deleteDepartment(int deptId) async {
    return await delete('/admin/departments/$deptId');
  }

// === ADMIN SERVICES MANAGEMENT ===

  Future<Map<String, dynamic>> getAllServices() async {
    return await _sendRequest('GET', '/admin/services', null);
  }

  Future<Map<String, dynamic>> createService(Map<String, dynamic> data) async {
    return await post('/admin/services', data);
  }

  Future<Map<String, dynamic>> updateService(
      int serviceId, Map<String, dynamic> data) async {
    return await put('/admin/services/$serviceId', data);
  }

  Future<Map<String, dynamic>> deleteService(int serviceId) async {
    return await delete('/admin/services/$serviceId');
  }

  Future<Map<String, dynamic>> getDoctorProfile() async {
    // GET /doctor/profile
    return await _sendRequest('GET', '/doctor/profile', null);
  }

  Future<Map<String, dynamic>> updateDoctorProfile(
      Map<String, dynamic> data) async {
    // PUT /doctor/profile
    return await put('/doctor/profile', data);
  }

  Future<Map<String, dynamic>> getDoctorAppointments({
    String? date,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    // GET /doctor/appointments
    String endpoint = '/doctor/appointments?page=$page&per_page=$perPage';
    if (date != null) endpoint += '&date=$date';
    if (status != null) endpoint += '&status=$status';
    final result = await _sendRequest('GET', endpoint, null);

    // Hàm này trả về object có key 'appointments', cần trích xuất nếu cần
    return result;
  }

  Future<Map<String, dynamic>> getDoctorAppointmentDetail(
      int appointmentId) async {
    // GET /doctor/appointments/<id>
    return await _sendRequest(
        'GET', '/doctor/appointments/$appointmentId', null);
  }

  Future<Map<String, dynamic>> checkInAppointment(int appointmentId) async {
    // PUT /doctor/appointments/<id>/check-in
    return await put('/doctor/appointments/$appointmentId/check-in', {});
  }

  Future<Map<String, dynamic>> createMedicalRecord(
      Map<String, dynamic> recordData) async {
    // POST /doctor/medical-records
    return await post('/doctor/medical-records', recordData);
  }

  Future<Map<String, dynamic>> createBulkPrescriptions(
      Map<String, dynamic> prescriptionsData) async {
    // POST /doctor/prescriptions/bulk
    return await post('/doctor/prescriptions/bulk', prescriptionsData);
  }

  Future<Map<String, dynamic>> getDoctorSchedules() async {
    // GET /doctor/schedules
    return await _sendRequest('GET', '/doctor/schedules', null);
  }

  Future<Map<String, dynamic>> createDoctorSchedule(
      Map<String, dynamic> scheduleData) async {
    // POST /doctor/schedules
    return await post('/doctor/schedules', scheduleData);
  }

  Future<Map<String, dynamic>> deleteDoctorSchedule(int scheduleId) async {
    // DELETE /doctor/schedules/<id>
    return await delete('/doctor/schedules/$scheduleId');
  }

  Future<Map<String, dynamic>> getDoctorLeaves() async {
    // GET /doctor/leaves
    return await _sendRequest('GET', '/doctor/leaves', null);
  }

  Future<Map<String, dynamic>> createDoctorLeave(
      Map<String, dynamic> leaveData) async {
    // POST /doctor/leaves
    return await post('/doctor/leaves', leaveData);
  }

  Future<Map<String, dynamic>> deleteDoctorLeave(int leaveId) async {
    // DELETE /doctor/leaves/<id>
    return await delete('/doctor/leaves/$leaveId');
  }

// === DOCTOR STATISTICS ===

  Future<Map<String, dynamic>> getDoctorPersonalStats({
    String? dateFrom,
    String? dateTo,
  }) async {
    String endpoint = '/doctor/appointments';
    List<String> params = [];

    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');

    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }

    return await _sendRequest('GET', endpoint, null);
  }

// === DOCTOR PATIENTS LIST ===

  Future<Map<String, dynamic>> getDoctorPatientsList({
    int page = 1,
    int perPage = 20,
  }) async {
    // Lấy danh sách bệnh nhân đã khám thông qua appointments
    final result = await _sendRequest(
        'GET', '/doctor/appointments?page=$page&per_page=$perPage', null);

    if (result['success']) {
      // Trích xuất danh sách bệnh nhân unique
      final appointments = result['data']['appointments'] as List;
      final Map<int, Map<String, dynamic>> uniquePatients = {};

      for (var appt in appointments) {
        if (appt['patient_id'] != null &&
            !uniquePatients.containsKey(appt['patient_id'])) {
          uniquePatients[appt['patient_id']] = {
            'patient_id': appt['patient_id'],
            'patient_name': appt['patient_name'],
            'patient_phone': appt['patient_phone'],
            'patient_code': appt['patient_code'],
            'last_visit': appt['appointment_date'],
          };
        }
      }

      return {
        'success': true,
        'data': uniquePatients.values.toList(),
      };
    }

    return result;
  }

// === DOCTOR MEDICAL RECORDS HISTORY ===

  Future<Map<String, dynamic>> getDoctorMedicalRecordsHistory({
    int? patientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    // Lấy lịch sử hồ sơ bệnh án của bác sĩ
    String endpoint = '/doctor/appointments?page=$page&per_page=$perPage';
    List<String> params = ['status=completed'];

    if (patientId != null) params.add('patient_id=$patientId');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');

    endpoint += '&${params.join('&')}';

    return await _sendRequest('GET', endpoint, null);
  }

// === HELPER METHOD (Nếu chưa có) ===

  Future<Map<String, dynamic>> get(
      String endpoint, Map<String, dynamic> params) async {
    // Build query string from params
    if (params.isNotEmpty) {
      final queryString = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      endpoint = '$endpoint?$queryString';
    }
    return await _sendRequest('GET', endpoint, null);
  }

  Future<Map<String, dynamic>> createFollowUpReminder(
      Map<String, dynamic> reminderData) async {
    // POST /doctor/follow-up-reminders
    return await post('/doctor/follow-up-reminders', reminderData);
  }

  Future<Map<String, dynamic>> getMedicalRecordByAppointment(
      int appointmentId) async {
    // GET /doctor/appointments/<appointment_id>/medical-record
    return await _sendRequest(
        'GET', '/doctor/appointments/$appointmentId/medical-record', null);
  }

  // ===================================
  // === PAYMENT APIS ===
  // ===================================
  // Create a payment record (pending)
  Future<Map<String, dynamic>> createPaymentRecord(
      int appointmentId, double amount, String provider) async {
    return await post('/payment/create', {
      'appointment_id': appointmentId,
      'amount': amount,
      'provider': provider,
    });
  }

  // Initiate MoMo payment and get redirect URL
  Future<Map<String, dynamic>> initiateMomoPayment(int paymentId) async {
    return await post('/payment/initiate-momo', {'payment_id': paymentId});
  }

  // Check payment status by payment code
  Future<Map<String, dynamic>> checkPaymentStatus(String paymentCode) async {
    return await _sendRequest(
        'GET', '/payment/status?payment_code=$paymentCode', null);
  }

  // ===================================
  // === REVIEW & FEEDBACK APIS ===
  // ===================================

  Future<Map<String, dynamic>> getMyReviews() async {
    final result = await _sendRequest('GET', '/patient/reviews/my', null);
    // Backend trả về list trực tiếp
    return result;
  }

  Future<Map<String, dynamic>> submitReview(
      Map<String, dynamic> reviewData) async {
    return await post('/general/reviews', reviewData);
  }

  Future<Map<String, dynamic>> submitFeedback(
      Map<String, dynamic> feedbackData) async {
    return await post('/general/feedback', feedbackData);
  }
}
