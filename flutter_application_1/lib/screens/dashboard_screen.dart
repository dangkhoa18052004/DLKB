import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
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
                Text('Lịch hẹn đang chờ xử lý',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
