import 'package:flutter/material.dart';

// Đổi StatelessWidget thành StatefulWidget để quản lý Tab và trạng thái
class AppointmentManagementScreen extends StatefulWidget {
  const AppointmentManagementScreen({super.key});

  @override
  State<AppointmentManagementScreen> createState() =>
      _AppointmentManagementScreenState();
}

class _AppointmentManagementScreenState
    extends State<AppointmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dữ liệu mẫu cho các tab
  final Map<String, List<Map<String, dynamic>>> _mockAppointments = {
    'all': [
      {
        'code': 'APN3KVL',
        'status': 'confirmed',
        'patient': 'Nguyễn Văn A',
        'time': '09:00'
      },
      {
        'code': 'APN4MWL',
        'status': 'pending',
        'patient': 'Trần Thị B',
        'time': '10:30'
      },
      {
        'code': 'APN5XYZ',
        'status': 'checked_in',
        'patient': 'Phạm C',
        'time': '11:00'
      },
      {
        'code': 'APN6ABC',
        'status': 'completed',
        'patient': 'Lê Văn D',
        'time': '14:00'
      },
      {
        'code': 'APN7DEF',
        'status': 'cancelled',
        'patient': 'Võ Thị E',
        'time': '15:30'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    // 4 tabs: Tất cả, Chờ xác nhận, Đã xác nhận, Đã hoàn thành
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Lấy danh sách lịch hẹn theo trạng thái
  List<Map<String, dynamic>> _getAppointmentsByStatus(String status) {
    if (status == 'all') return _mockAppointments['all'] ?? [];
    return (_mockAppointments['all'] ?? [])
        .where((appt) => appt['status'] == status)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lịch hẹn'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
        ],
        // Dùng TabBar trong AppBar để giữ layout gọn gàng
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Tất cả (${_mockAppointments['all']?.length ?? 0})'),
            Tab(text: 'Chờ xác nhận'), // status: pending
            Tab(text: 'Đã xác nhận'), // status: confirmed
            Tab(text: 'Đã hoàn thành'), // status: completed
          ],
        ),
      ),
      // Bọc TabBarView trong Column với Expanded nếu TabBar không nằm trong AppBar.
      // Nhưng vì dùng AppBar.bottom, chỉ cần TabBarView
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Tất cả
          _buildAppointmentList(context, 'all'),
          // Tab 2: Chờ xác nhận
          _buildAppointmentList(context, 'pending'),
          // Tab 3: Đã xác nhận
          _buildAppointmentList(context, 'confirmed'),
          // Tab 4: Đã hoàn thành
          _buildAppointmentList(context, 'completed'),
        ],
      ),
    );
  }

  Widget _buildAppointmentList(BuildContext context, String statusFilter) {
    final list = _getAppointmentsByStatus(statusFilter);

    if (list.isEmpty) {
      return Center(
        child: Text('Không có lịch hẹn ở trạng thái "$statusFilter"'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appt = list[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: Icon(
              _getStatusIcon(appt['status']),
              color: _getStatusColor(appt['status']),
            ),
            title: Text(
              'Mã hẹn: ${appt['code']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bệnh nhân: ${appt['patient']}'),
                Text('Thời gian: 05/12/2025 ${appt['time']}'),
                Text(
                  'Trạng thái: ${_getStatusText(appt['status'])}',
                  style: TextStyle(
                    color: _getStatusColor(appt['status']),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => _handleAction(v, appt),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Text('Xem chi tiết')),
                if (appt['status'] == 'confirmed')
                  const PopupMenuItem(
                      value: 'check_in', child: Text('Check-in')),
                if (appt['status'] == 'pending' ||
                    appt['status'] == 'confirmed')
                  const PopupMenuItem(
                      value: 'reschedule', child: Text('Dời lịch')),
                if (appt['status'] != 'cancelled' &&
                    appt['status'] != 'completed')
                  const PopupMenuItem(value: 'cancel', child: Text('Hủy hẹn')),
              ],
            ),
          ),
        );
      },
    );
  }

  // Xử lý các hành động
  void _handleAction(String action, Map<String, dynamic> appointment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Hành động "$action" cho lịch hẹn ${appointment['code']}'),
      ),
    );
    // TODO: Triển khai logic API cho từng hành động (view, check_in, reschedule, cancel)
  }

  // Các hàm hỗ trợ hiển thị trạng thái
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.access_time;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'checked_in':
        return Icons.how_to_reg;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.event;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'checked_in':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'checked_in':
        return 'Đã Check-in';
      case 'completed':
        return 'Đã hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Khác';
    }
  }
}
