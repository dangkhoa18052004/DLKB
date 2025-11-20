import 'package:flutter/material.dart';
import 'send_notification_screen.dart'; // Chứa NotificationType và SendNotificationScreen
import '../services/api_service.dart'; // Import ApiService

class AdminNotificationsScreen extends StatefulWidget {
  // LỚP NÀY ĐƯỢC GỌI TỪ DASHBOARD. Dùng StatefulWidget để tải dữ liệu.
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _sentNotifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSentNotifications();
  }

  Future<void> _loadSentNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Yêu cầu API để lấy các thông báo đã gửi.
    try {
      final result = await _apiService.getMyNotifications();

      if (result['success']) {
        setState(() {
          _sentNotifications = result['data']['notifications'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Không thể tải lịch sử thông báo';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Hàm hiển thị Popup Menu khi nhấn nút
  void _showSendOption(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group, color: Colors.blue),
              title: const Text('Gửi Hàng loạt (Broadcast)'),
              onTap: () {
                Navigator.pop(context); // Đóng BottomSheet
                _navigateToSender(context, NotificationType.broadcast);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('Gửi Cá nhân (Theo ID)'),
              onTap: () {
                Navigator.pop(context); // Đóng BottomSheet
                _navigateToSender(context, NotificationType.single);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: const Text('Tải lại Lịch sử Thông báo'),
              onTap: () {
                Navigator.pop(context);
                _loadSentNotifications(); // Tải lại dữ liệu
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Đang tải lại lịch sử thông báo...')),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  void _navigateToSender(BuildContext context, NotificationType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Lỗi không xảy ra ở đây vì đã dùng Class/Enum được Import
        builder: (context) => SendNotificationScreen(initialType: type),
      ),
    ).then((result) {
      if (result == true) {
        _loadSentNotifications(); // Tải lại sau khi gửi thành công
      }
    });
  }

  Widget _buildNotificationList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
          child: Text('Lỗi tải dữ liệu: $_errorMessage',
              textAlign: TextAlign.center));
    }

    if (_sentNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Chưa có thông báo nào được gửi.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSentNotifications,
      child: ListView.builder(
        itemCount: _sentNotifications.length,
        itemBuilder: (context, index) {
          final notif = _sentNotifications[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                notif['type'] == 'system_broadcast'
                    ? Icons.public
                    : Icons.person_outline,
                color: notif['is_read']
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                notif['title'],
                style: TextStyle(
                    fontWeight:
                        notif['is_read'] ? FontWeight.normal : FontWeight.bold),
              ),
              subtitle: Text(
                '${notif['message']} - Gửi đến ID: ${notif['user_id']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                notif['created_at'].split(' ')[0],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              onTap: () {
                // Hiển thị chi tiết thông báo
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Thông báo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gửi Thông báo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // Nút để mở menu tùy chọn gửi
            ElevatedButton.icon(
              onPressed: () => _showSendOption(context),
              icon: const Icon(Icons.send),
              label: const Text('Tạo/Gửi Thông báo'),
            ),
            const SizedBox(height: 20),

            const Text('Lịch sử Thông báo Đã gửi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Expanded(
              child: _buildNotificationList(),
            ),
          ],
        ),
      ),
      // FloatingActionButton để mở menu tùy chọn
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSendOption(context),
        label: const Text('Tạo mới'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
