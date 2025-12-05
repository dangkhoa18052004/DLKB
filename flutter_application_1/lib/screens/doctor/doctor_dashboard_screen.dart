// doctor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'package:hospital_admin_app/services/auth_service.dart';
import 'package:hospital_admin_app/screens/notifications_screen.dart';
import 'package:hospital_admin_app/screens/profile_screen.dart';
import 'doctor_appointment_list_screen.dart';
import 'doctor_profile_screen.dart';
import 'register_schedule_screen.dart';
import 'doctor_schedule_management_screen.dart';
import 'doctor_stats_screen.dart';

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
      final doctorProfileResult = await _apiService.getDoctorProfile();
      final today = DateTime.now().toString().split(' ')[0];
      final apptResult = await _apiService.getDoctorAppointments(date: today);

      if (!mounted) return;

      if (doctorProfileResult['success'] && apptResult['success']) {
        final profile = doctorProfileResult['data'];
        final appointmentsData = apptResult['data'];
        final appointments =
            appointmentsData['appointments'] as List<dynamic>? ?? [];

        final totalToday = appointments.length;
        final confirmedToday =
            appointments.where((a) => a['status'] == 'confirmed').length;
        final checkedInToday =
            appointments.where((a) => a['status'] == 'checked_in').length;
        final completedToday =
            appointments.where((a) => a['status'] == 'completed').length;

        setState(() {
          _profileData = profile['doctor'];
          _appointmentStats = {
            'total_today': totalToday,
            'waiting': confirmedToday + checkedInToday,
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

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (mounted) {
      _loadDashboardData();
    }
  }

  void _showLogoutDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                authService.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bác sĩ - Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      // ✅ THÊM SafeArea
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text('Lỗi: $_errorMessage',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _buildDashboardContent(),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final doctorName = _profileData?['full_name'] ?? 'Bác sĩ';
    final isAvailable = _profileData?['is_available'] ?? true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER SECTION ===
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        doctorName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào mừng,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            doctorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAvailable ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.do_not_disturb,
                        color: isAvailable ? Colors.green : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Trạng thái: ${isAvailable ? 'Đang Sẵn có' : 'Không hoạt động'}',
                          style: TextStyle(
                            color: isAvailable ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng quan Lịch hẹn Hôm nay',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // ✅ SỬA GRID - TĂNG childAspectRatio
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4, // Tăng từ 1.3 lên 1.4
                  children: [
                    _buildStatCard(
                      'Tổng Lịch hẹn',
                      _appointmentStats?['total_today']?.toString() ?? '0',
                      Icons.event_note,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Đang Chờ Khám',
                      _appointmentStats?['waiting']?.toString() ?? '0',
                      Icons.people_outline,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Đã Check-in',
                      _appointmentStats?['checked_in']?.toString() ?? '0',
                      Icons.how_to_reg,
                      Colors.teal,
                    ),
                    _buildStatCard(
                      'Đã Hoàn thành',
                      _appointmentStats?['completed']?.toString() ?? '0',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  'Hiệu suất và Quản lý',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                _buildActionButton(
                  context,
                  title: 'Thống kê Cá nhân',
                  subtitle: 'Xem hiệu suất và biểu đồ của bạn',
                  icon: Icons.bar_chart,
                  color: Colors.indigo,
                  onTap: () => _navigateAndRefresh(const DoctorStatsScreen()),
                ),
                const SizedBox(height: 8),

                _buildActionButton(
                  context,
                  title: 'Quản lý Lịch làm việc',
                  subtitle: 'Xem, sửa lịch định kỳ và đăng ký nghỉ phép',
                  icon: Icons.calendar_month,
                  color: Colors.teal,
                  onTap: () => _navigateAndRefresh(
                      const DoctorScheduleManagementScreen()),
                ),
                const SizedBox(height: 8),

                _buildActionButton(
                  context,
                  title: 'Quản lý Lịch hẹn',
                  subtitle: 'Xem, Check-in, và xử lý lịch khám',
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                  onTap: () =>
                      _navigateAndRefresh(const DoctorAppointmentListScreen()),
                ),
                const SizedBox(height: 8),

                _buildActionButton(
                  context,
                  title: 'Hồ sơ cá nhân & Lịch',
                  subtitle: 'Cập nhật thông tin, lịch làm việc, và ngày nghỉ',
                  icon: Icons.person,
                  color: Colors.purple,
                  onTap: () => _navigateAndRefresh(const DoctorProfileScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12), // Giảm padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6), // Giảm padding
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20), // Giảm size
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28, // Giảm từ 32
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11, // Giảm từ 12
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
