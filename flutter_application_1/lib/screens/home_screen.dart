import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

// Import các màn hình (giữ các màn hình được sử dụng)
import 'select_department_screen.dart';
import 'my_appointment_screen.dart';
import 'medical_history_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userRole = authService.user?['role'] ?? 'patient';
    final userName = authService.user?['full_name'] ?? 'User';

    // Điều hướng theo role
    Widget bodyContent;

    switch (userRole) {
      case 'admin':
      case 'staff':
        bodyContent = const DashboardScreen();
        break;
      case 'doctor':
        // No dedicated doctor dashboard file; reuse main DashboardScreen for now
        bodyContent = const DashboardScreen();
        break;
      case 'patient':
      default:
        bodyContent = PatientHomeContent(userName: userName);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(userRole)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Notification Icon
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
              // Mở màn hình Thông báo
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()));
            },
          ),
          // Profile Icon
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, authService),
          ),
        ],
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        tooltip: 'Tìm kiếm',
        child: const Icon(Icons.search),
      ),
    );
  }

  String _getAppBarTitle(String role) {
    switch (role) {
      case 'admin':
      case 'staff':
        return 'Quản trị Hệ thống';
      case 'doctor':
        return 'Bác sĩ - Dashboard';
      case 'patient':
      default:
        return 'Bệnh viện Nhi Đồng II';
    }
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
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
}

// ============================================
// PATIENT HOME CONTENT
// ============================================
class PatientHomeContent extends StatefulWidget {
  final String userName;
  const PatientHomeContent({super.key, required this.userName});

  @override
  State<PatientHomeContent> createState() => _PatientHomeContentState();
}

class _PatientHomeContentState extends State<PatientHomeContent> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _patientStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatientStats();
  }

  Future<void> _loadPatientStats() async {
    setState(() => _isLoading = true);

    try {
      final appointments = await _apiService.getMyAppointments();
      if (appointments['success']) {
        final List data = appointments['data'] ?? [];
        setState(() {
          _patientStats = {
            'total': data.length,
            'pending': data.where((a) => a['status'] == 'pending').length,
            'confirmed': data.where((a) => a['status'] == 'confirmed').length,
            'completed': data.where((a) => a['status'] == 'completed').length,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPatientStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            _buildWelcomeBanner(),

            const SizedBox(height: 20),

            // Quick Stats
            if (!_isLoading && _patientStats != null) _buildQuickStats(),

            const SizedBox(height: 20),

            // Main Action Buttons
            _buildMainActions(),

            const SizedBox(height: 20),

            // Secondary Actions
            _buildSecondaryActions(),

            const SizedBox(height: 20),

            // Health Tips Section
            _buildHealthTips(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context)
                .colorScheme
                .primary
                .withAlpha((0.8 * 255).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào,',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chúc bạn một ngày khỏe mạnh! 💚',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch hẹn của bạn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Tổng số',
                  _patientStats!['total'].toString(),
                  Icons.calendar_today,
                  Colors.blue.shade100,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Đã xác nhận',
                  _patientStats!['confirmed'].toString(),
                  Icons.check_circle_outline,
                  Colors.green.shade100,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Chờ duyệt',
                  _patientStats!['pending'].toString(),
                  Icons.pending_outlined,
                  Colors.orange.shade100,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Hoàn thành',
                  _patientStats!['completed'].toString(),
                  Icons.done_all,
                  Colors.purple.shade100,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dịch vụ chính',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            title: 'Đặt lịch Khám bệnh',
            subtitle: 'Đặt lịch khám với bác sĩ chuyên khoa',
            icon: Icons.add_circle,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SelectDepartmentScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            context,
            title: 'Lịch hẹn của tôi',
            subtitle: 'Xem và quản lý lịch hẹn đã đặt',
            icon: Icons.event_note,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MyAppointmentsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dịch vụ khác',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallActionCard(
                  'Lịch sử khám',
                  Icons.history,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MedicalHistoryScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallActionCard(
                  'Hồ sơ',
                  Icons.person,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallActionCard(
                  'Thanh toán',
                  Icons.payment,
                  Colors.teal,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Chức năng Lịch sử thanh toán đang phát triển')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallActionCard(
                  'Phản hồi',
                  Icons.feedback,
                  Colors.red,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Chức năng Gửi phản hồi đang phát triển')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((0.3 * 255).round())),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((0.3 * 255).round())),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mẹo sức khỏe',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade100, Colors.teal.shade50],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.teal.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Uống đủ nước mỗi ngày giúp cơ thể khỏe mạnh và tăng cường hệ miễn dịch.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
