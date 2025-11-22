// dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'admin_user_management_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_appointments_screen.dart';
import 'admin_services_screen.dart';
import 'admin_doctors_screen.dart';
import 'admin_payment_management_screen.dart';
import 'admin_review_feedback_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _dashboardData;
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

    final result = await ApiService().getDashboardOverview();

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _dashboardData = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'];
        _isLoading = false;
      });
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

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (mounted) {
      _loadDashboardData();
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    return num.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Lỗi: $_errorMessage', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData!;
    final patients = data['patients'];
    final doctors = data['doctors'];
    final appointments = data['appointments'];
    final revenue = data['revenue'];

    // 🛑 ĐÃ THÊM SAFEAREAD VÀO ĐÂY
    return Scaffold(
      body: SafeArea(
        // Bọc toàn bộ nội dung trong SafeArea
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Thay thế AppBar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tổng quan hôm nay',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 20,
                              ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút Thông báo với badge
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
                            _navigateAndRefresh(
                                const AdminNotificationsScreen());
                          },
                        ),
                        // IconButton(
                        //   icon: const Icon(Icons.account_circle),
                        //   onPressed: () {
                        //   },
                        // ),
                        // Nút Refresh
                        IconButton(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Làm mới',
                        ),
                        // Nút Đăng xuất
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () =>
                              _showLogoutDialog(context, authService),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Responsive Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 2;

                    if (constraints.maxWidth > 800) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth > 500) {
                      crossAxisCount = 3;
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _buildStatCard(
                              context,
                              'Bệnh nhân',
                              patients['total'].toString(),
                              Icons.people,
                              Colors.blue.shade100,
                              'Mới: ${patients['new_this_month']}',
                            );
                          case 1:
                            return _buildStatCard(
                              context,
                              'Bác sĩ',
                              doctors['total'].toString(),
                              Icons.medication,
                              Colors.green.shade100,
                              'Đang hoạt động',
                            );
                          case 2:
                            return _buildStatCard(
                              context,
                              'Lịch hẹn TQ',
                              appointments['total'].toString(),
                              Icons.calendar_today,
                              Colors.orange.shade100,
                              'Hôm nay: ${appointments['today']}',
                            );
                          case 3:
                            return _buildStatCard(
                              context,
                              'Doanh thu T.',
                              '${_formatNumber(revenue['this_month'])} ₫',
                              Icons.monetization_on,
                              Colors.red.shade100,
                              'Tháng trước: ${revenue['change_percent']}%',
                            );
                          default:
                            return Container();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),

                // === QUẢN LÝ ===
                Text('Quản lý', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                ..._buildManagementButtons(),

                const SizedBox(height: 32),

                // === LỊCH HẸN ĐANG CHỜ ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lịch hẹn đang chờ xử lý',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        _navigateAndRefresh(const AdminAppointmentsScreen());
                      },
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                InkWell(
                  onTap: () {
                    _navigateAndRefresh(const AdminAppointmentsScreen());
                  },
                  child: Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.access_time, color: Colors.orange),
                      title: const Text('Tổng số lịch hẹn đang chờ duyệt'),
                      trailing: Text(
                        appointments['pending'].toString(),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.orange, fontSize: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Phương thức build các nút quản lý
  List<Widget> _buildManagementButtons() {
    final List<Map<String, dynamic>> managementItems = [
      {
        'title': 'Quản lý Lịch hẹn',
        'icon': Icons.event_note,
        'color': Colors.blue,
        'screen': const AdminAppointmentsScreen(),
      },
      {
        'title': 'Quản lý Dịch vụ',
        'icon': Icons.medical_services,
        'color': Colors.green,
        'screen': const AdminServicesScreen(),
      },
      {
        'title': 'Quản lý Bác sĩ',
        'icon': Icons.person_search,
        'color': Colors.teal,
        'screen': const AdminDoctorsScreen(),
      },
      {
        'title': 'Quản lý Người dùng',
        'icon': Icons.group,
        'color': Colors.purple,
        'screen': const AdminUserManagementScreen(),
      },
      {
        'title': 'Quản lý Thanh Toán',
        'icon': Icons.payment,
        'color': Colors.orange,
        'screen': const AdminPaymentManagementScreen(),
      },
      {
        'title': 'Quản lý Đánh giá & P.Hồi',
        'icon': Icons.rate_review,
        'color': Colors.indigo,
        'screen': const AdminReviewFeedbackScreen(),
      },
      {
        'title': 'Quản lý Thông báo',
        'icon': Icons.notifications_active,
        'color': Colors.red,
        'screen': const AdminNotificationsScreen(),
      },
      // {
      //   'title': 'Báo cáo & Thống kê',
      //   'icon': Icons.bar_chart,
      //   'color': Colors.blueGrey,
      //   'screen': const AdminReportsScreen(),
      // },
    ];

    return managementItems.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildManagementButton(
          context,
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: () {
            debugPrint('Navigating to ${item['title']}');
            _navigateAndRefresh(item['screen'] as Widget);
          },
        ),
      );
    }).toList();
  }

  // WIDGET _buildStatCard (ĐÃ CHỈNH KÍCH THƯỚC)
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color bgColor,
    String subtitle,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: bgColor,
      child: Padding(
        padding:
            const EdgeInsets.all(8.0), // Giảm padding tổng thể (từ 12 xuống 8)
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 20,
                    color: Colors
                        .black54), // Giảm kích thước icon (từ 24 xuống 20)
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10, // Giảm kích thước chữ (từ 12 xuống 10)
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14, // Giảm kích thước chữ (từ 16 xuống 14)
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
                maxLines: 1,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black54), // Giảm kích thước chữ (từ 10 xuống 9)
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET _buildManagementButton (ĐÃ CHỈNH KÍCH THƯỚC)
  Widget _buildManagementButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(
              10.0), // Giảm padding tổng thể (từ 12 xuống 10)
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // Giảm padding (từ 8 xuống 6)
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: color,
                    size: 22), // Giảm kích thước icon (từ 24 xuống 22)
              ),
              const SizedBox(width: 10), // Giảm khoảng cách (từ 12 xuống 10)
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15, // Giảm kích thước chữ (từ 16 xuống 15)
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14, // Giảm kích thước icon (từ 16 xuống 14)
                color: color.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
