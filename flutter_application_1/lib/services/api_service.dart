import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api/v1';
  final storage = const FlutterSecureStorage();

  // Get token from storage
  Future<String?> getToken() async {
    return await storage.read(key: 'access_token');
  }

  // Save token to storage
  Future<void> saveToken(String token) async {
    await storage.write(key: 'access_token', value: token);
  }

  // Delete token
  Future<void> deleteToken() async {
    await storage.delete(key: 'access_token');
  }

  // Get headers with token
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
        return {'success': false, 'error': jsonDecode(response.body)['msg']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    await deleteToken();
  }

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
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get monthly appointments
  Future<Map<String, dynamic>> getMonthlyAppointments(
      int year, int month) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/stats/appointments/monthly?year=$year&month=$month'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get monthly revenue
  Future<Map<String, dynamic>> getMonthlyRevenue(int year) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/revenue/monthly?year=$year'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get appointments by doctor
  Future<Map<String, dynamic>> getAppointmentsByDoctor(
      String? dateFrom, String? dateTo) async {
    try {
      var url = '$baseUrl/stats/appointments/by-doctor';
      if (dateFrom != null || dateTo != null) {
        url += '?';
        if (dateFrom != null) url += 'date_from=$dateFrom&';
        if (dateTo != null) url += 'date_to=$dateTo';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get patient overview
  Future<Map<String, dynamic>> getPatientOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/patients/overview'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get revenue overview
  Future<Map<String, dynamic>> getRevenueOverview() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/revenue/overview'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get doctor performance
  Future<Map<String, dynamic>> getDoctorPerformance(
      String? dateFrom, String? dateTo) async {
    try {
      var url = '$baseUrl/stats/doctors/performance';
      if (dateFrom != null || dateTo != null) {
        url += '?';
        if (dateFrom != null) url += 'date_from=$dateFrom&';
        if (dateTo != null) url += 'date_to=$dateTo';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Get department statistics
  Future<Map<String, dynamic>> getDepartmentStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/departments/statistics'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': 'Failed to load data'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}
