import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_user_management_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_appointments_screen.dart'; // ✅ THÊM IMPORT NÀY

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, dynamic>>? _overviewData;

  @override
  void initState() {
    super.initState();
    _overviewData = ApiService().getDashboardOverview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _overviewData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.data!['success']) {
            return Center(
              child: Text(
                'Failed to load dashboard data: ${snapshot.data?['error'] ?? snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final data = snapshot.data!['data'];
          final patients = data['patients'];
          final doctors = data['doctors'];
          final appointments = data['appointments'];
          final revenue = data['revenue'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tổng quan hôm nay',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),

                // GridView Stats
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildStatCard(
                      context,
                      'Bệnh nhân',
                      patients['total'].toString(),
                      Icons.people,
                      Colors.blue.shade100,
                      'Mới: ${patients['new_this_month']}',
                    ),
                    _buildStatCard(
                      context,
                      'Bác sĩ',
                      doctors['total'].toString(),
                      Icons.medication,
                      Colors.green.shade100,
                      'Đang hoạt động',
                    ),
                    _buildStatCard(
                      context,
                      'Lịch hẹn TQ',
                      appointments['total'].toString(),
                      Icons.calendar_today,
                      Colors.orange.shade100,
                      'Hôm nay: ${appointments['today']}',
                    ),
                    _buildStatCard(
                      context,
                      'Doanh thu T.',
                      '${(double.tryParse(revenue['this_month']) ?? 0).toStringAsFixed(0)} ₫',
                      Icons.monetization_on,
                      Colors.red.shade100,
                      'Tháng trước: ${revenue['change_percent']}%',
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // === QUẢN LÝ ===
                Text('Quản lý', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                // ✅ THÊM NÚT QUẢN LÝ LỊCH HẸN
                _buildManagementButton(
                  context,
                  title: 'Quản lý Lịch hẹn',
                  icon: Icons.event_note,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminAppointmentsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                _buildManagementButton(
                  context,
                  title: 'Quản lý Người dùng',
                  icon: Icons.group,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminUserManagementScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                _buildManagementButton(
                  context,
                  title: 'Quản lý Thông báo',
                  icon: Icons.notifications_active,
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminNotificationsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                _buildManagementButton(
                  context,
                  title: 'Báo cáo & Thống kê',
                  icon: Icons.bar_chart,
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminReportsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // ✅ LỊCH HẸN ĐANG CHỜ - CLICKABLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lịch hẹn đang chờ xử lý',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminAppointmentsScreen(),
                          ),
                        );
                      },
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminAppointmentsScreen(),
                      ),
                    );
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
                            ?.copyWith(color: Colors.orange),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 36, color: Colors.black54),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementButton(
    BuildContext context, {
    required String title,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: color.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
