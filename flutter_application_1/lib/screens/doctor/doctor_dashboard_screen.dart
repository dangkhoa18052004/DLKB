// doctor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'doctor_appointment_list_screen.dart';
import 'doctor_profile_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _appointmentStats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _apiService.getMyProfile();

      final doctorProfileResult = await _apiService.getDoctorProfile();

      final today = DateTime.now().toString().split(' ')[0];
      final apptResult = await _apiService.getMyAppointments(date: today);

      if (!mounted) return;

      if (doctorProfileResult['success'] && apptResult['success']) {
        final profile = doctorProfileResult['data'];
        final appointments = apptResult['data'] as List<dynamic>;

        // Tính toán nhanh số lượng
        final totalToday = appointments.length;
        final confirmedToday =
            appointments.where((a) => a['status'] == 'confirmed').length;
        final checkedInToday =
            appointments.where((a) => a['status'] == 'checked_in').length;
        final completedToday =
            appointments.where((a) => a['status'] == 'completed').length;

        setState(() {
          _profileData = profile['doctor']; // Lấy phần doctor info
          _appointmentStats = {
            'total_today': totalToday,
            'waiting': confirmedToday +
                checkedInToday -
                completedToday, // Lịch hẹn đã confirm/checkin nhưng chưa complete
            'checked_in': checkedInToday,
            'completed': completedToday,
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = doctorProfileResult['error'] ??
              apptResult['error'] ??
              'Lỗi tải dữ liệu';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Phương thức navigate và refresh
  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (mounted) {
      _loadDashboardData();
    }
  }

  // Widget hiển thị rating ngôi sao (Mô phỏng)
  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Lỗi: $_errorMessage'));
    }

    final doctorName = _profileData?['full_name'] ?? 'Bác sĩ';
    final currentRating = (_profileData?['rating'] as num?)?.toDouble() ?? 0.0;
    final isAvailable = _profileData?['is_available'] ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Chào mừng và Trạng thái
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chào mừng, ${doctorName}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDashboardData,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Thẻ Trạng thái Sẵn có
          Card(
            color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
            elevation: 2,
            child: ListTile(
              leading: Icon(
                  isAvailable ? Icons.check_circle_outline : Icons.block,
                  color: isAvailable ? Colors.green : Colors.red),
              title: Text(
                'Trạng thái hiện tại: ${isAvailable ? 'Đang Sẵn có' : 'Nghỉ phép/Không hoạt động'}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? Colors.green.shade800
                        : Colors.red.shade800),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Điều hướng đến màn hình Profile để thay đổi trạng thái
                _navigateAndRefresh(const DoctorProfileScreen());
              },
            ),
          ),
          const SizedBox(height: 24),

          // === THỐNG KÊ NGÀY (DAILY STATS) ===
          Text(
            'Tổng quan Lịch hẹn Hôm nay',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                  'Tổng Lịch hẹn',
                  _appointmentStats?['total_today']?.toString() ?? '0',
                  Icons.schedule,
                  Colors.blue.shade100),
              _buildStatCard(
                  'Đang Chờ Khám',
                  _appointmentStats?['waiting']?.toString() ?? '0',
                  Icons.people_outline,
                  Colors.orange.shade100),
              _buildStatCard(
                  'Đã Check-in',
                  _appointmentStats?['checked_in']?.toString() ?? '0',
                  Icons.person_pin_circle,
                  Colors.teal.shade100),
              _buildStatCard(
                  'Đã Hoàn thành',
                  _appointmentStats?['completed']?.toString() ?? '0',
                  Icons.verified,
                  Colors.green.shade100),
            ],
          ),

          const SizedBox(height: 32),

          // === HIỆU SUẤT VÀ ĐIỀU HƯỚNG NHANH ===
          Text(
            'Hiệu suất và Quản lý',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // Thẻ Rating
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text('Đánh giá trung bình'),
              subtitle: _buildRatingStars(currentRating),
              trailing: Text('${currentRating.toStringAsFixed(2)} / 5.0',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              onTap: () {
                // Điều hướng đến màn hình Reviews (nếu có)
              },
            ),
          ),
          const SizedBox(height: 8),

          // Nút điều hướng nhanh
          _buildManagementButton(
            context,
            title: 'Quản lý Lịch hẹn',
            subtitle: 'Xem, Check-in, và xử lý lịch khám',
            icon: Icons.event_note,
            color: Colors.blue,
            onTap: () => _navigateAndRefresh(
                const DoctorAppointmentListScreen()), // Giả định màn hình
          ),
          _buildManagementButton(
            context,
            title: 'Hồ sơ cá nhân & Lịch',
            subtitle: 'Cập nhật thông tin, lịch làm việc, và ngày nghỉ',
            icon: Icons.account_circle,
            color: Colors.purple,
            onTap: () => _navigateAndRefresh(
                const DoctorProfileScreen()), // Giả định màn hình
          ),
        ],
      ),
    );
  }

  // Helper Widget cho Stat Card
  Widget _buildStatCard(
      String title, String value, IconData icon, Color bgColor) {
    return Card(
      elevation: 4,
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.black),
            ),
            const Text('Hôm nay',
                style: TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // Helper Widget cho Management Button
  Widget _buildManagementButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
