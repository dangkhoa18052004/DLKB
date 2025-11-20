import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'select_department_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userRole = authService.user?['role'] ?? 'patient';
    final userName = authService.user?['full_name'] ?? 'User';

    // Tùy chỉnh giao diện theo role
    Widget primaryScreen;
    String appBarTitle;
    List<Widget> actions = [
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => authService.logout(),
      ),
    ];

    if (userRole == 'admin' || userRole == 'staff') {
      // Nếu là Admin/Staff, hiển thị Dashboard thống kê
      appBarTitle = 'Quản trị Bệnh viện';
      primaryScreen = const DashboardContent();
    } else {
      // Nếu là Patient, hiển thị trang Đặt lịch chính
      appBarTitle = 'Đặt lịch Khám bệnh';
      primaryScreen = PatientBookingContent(userName: userName);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: actions,
      ),
      body: primaryScreen,
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Tạm thời hiển thị DashboardScreen cũ đã được nâng cấp (Bên trên)
    return const SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            // DashboardScreen(), // Sử dụng nội dung của DashboardScreen đã sửa
            Text("Admin/Staff Content here (Using Dashboard Screen logic)"),
          ],
        ),
      ),
    );
  }
}

class PatientBookingContent extends StatelessWidget {
  final String userName;
  const PatientBookingContent({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Chào mừng, $userName! Hãy đặt lịch khám ngay.',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 250,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SelectDepartmentScreen()),
                );
              },
              icon: const Icon(Icons.calendar_month, size: 24),
              label: const Text('Đặt lịch Khám trực tuyến',
                  style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Các nút chức năng khác
          TextButton.icon(
            onPressed: () {
              // TODO: Chuyển đến màn hình Lịch hẹn của tôi
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Chức năng Quản lý Lịch hẹn sắp ra mắt!')));
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('Xem Lịch hẹn của tôi'),
          ),
          TextButton.icon(
            onPressed: () {
              // TODO: Chuyển đến màn hình Lịch sử khám bệnh
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Chức năng Lịch sử Khám bệnh sắp ra mắt!')));
            },
            icon: const Icon(Icons.history),
            label: const Text('Xem Lịch sử Khám bệnh'),
          ),
        ],
      ),
    );
  }
}
