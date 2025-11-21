import 'package:flutter/material.dart';
import 'send_notification_screen.dart';
import '../services/api_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
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
    _loadSentHistory();
  }

  Future<void> _loadSentHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _apiService.getAdminSentHistory(
      page: 1,
      perPage: 50,
    );

    if (res['success']) {
      setState(() {
        _sentNotifications = res['data']['notifications'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = res['error'];
        _isLoading = false;
      });
    }
  }

  String _getTargetRoleText(String? role) {
    if (role == null || role == 'all') return 'Tất cả';
    if (role == 'patient') return 'Bệnh nhân';
    if (role == 'doctor') return 'Bác sĩ';
    if (role == 'staff') return 'Nhân viên';
    return 'Cá nhân';
  }

  // ===== CHỨC NĂNG XÓA =====
  Future<void> _deleteNotification(Map<String, dynamic> notif) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa thông báo "${notif['title']}"?\n\n'
          'Thao tác này sẽ xóa thông báo cho ${notif['recipient_count']} người.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _apiService.deleteBroadcastNotification(
      title: notif['title'],
      message: notif['message'],
      sentDate: notif['sent_at'].split(' ')[0],
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã xóa ${result['data']['deleted_count']} thông báo',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadSentHistory(); // Reload list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===== CHỨC NĂNG SỬA =====
  Future<void> _editNotification(Map<String, dynamic> notif) async {
    final titleController = TextEditingController(text: notif['title']);
    final messageController = TextEditingController(text: notif['message']);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa Thông báo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sửa thông báo sẽ cập nhật cho ${notif['recipient_count']} người',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng điền đầy đủ thông tin'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'title': titleController.text.trim(),
                'message': messageController.text.trim(),
              });
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (result == null) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // ✅ GỌI API MỚI - Không cần ID nữa
    final updateResult = await _apiService.updateBroadcastNotification({
      'title': result['title'],
      'message': result['message'],
      'old_title': notif['title'],
      'old_message': notif['message'],
      'sent_date': notif['sent_at'].split(' ')[0],
    });

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (updateResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật ${updateResult['data']['updated_count']} thông báo',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadSentHistory(); // Reload list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${updateResult['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
                Navigator.pop(context);
                _navigateToSender(context, NotificationType.broadcast);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('Gửi Cá nhân (Theo ID)'),
              onTap: () {
                Navigator.pop(context);
                _navigateToSender(context, NotificationType.single);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: const Text('Tải lại Lịch sử Thông báo'),
              onTap: () {
                Navigator.pop(context);
                _loadSentHistory();
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
        builder: (context) => SendNotificationScreen(initialType: type),
      ),
    ).then((result) {
      if (result == true) {
        _loadSentHistory();
      }
    });
  }

  Widget _buildNotificationList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Lỗi: $_errorMessage', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSentHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
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
      onRefresh: _loadSentHistory,
      child: ListView.builder(
        itemCount: _sentNotifications.length,
        itemBuilder: (context, index) {
          final notif = _sentNotifications[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child:
                    const Icon(Icons.notifications_active, color: Colors.blue),
              ),
              title: Text(
                notif['title'] ?? 'Không có tiêu đề',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    notif['message'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${_getTargetRoleText(notif['target_role'])} (${notif['recipient_count'] ?? 0} người)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Gửi bởi: ${notif['sender_name'] ?? 'System'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editNotification(notif);
                  } else if (value == 'delete') {
                    _deleteNotification(notif);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa'),
                      ],
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSentHistory,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gửi Thông báo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showSendOption(context),
              icon: const Icon(Icons.send),
              label: const Text('Tạo/Gửi Thông báo'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử Thông báo Đã gửi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_sentNotifications.length} thông báo',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildNotificationList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSendOption(context),
        label: const Text('Tạo mới'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
