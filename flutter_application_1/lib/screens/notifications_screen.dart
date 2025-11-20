import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await _apiService.getMyNotifications();
    if (res['success']) {
      setState(() {
        _notifications = res['data']['notifications'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = res['error'] ?? 'Không thể tải thông báo';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final isRead = notif['is_read'] == true;
                      return ListTile(
                        leading: Icon(
                          isRead
                              ? Icons.notifications
                              : Icons.notifications_active,
                          color: isRead
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(notif['title'] ?? 'Thông báo'),
                        subtitle: Text(notif['message'] ?? ''),
                        trailing: isRead
                            ? TextButton(
                                onPressed: () async {
                                  // allow deleting read notifications
                                  final id = notif['id'];
                                  final r = await _apiService
                                      .deleteNotification(id as int);
                                  if (r['success']) {
                                    await _loadNotifications();
                                  } else {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              r['error'] ?? 'Xoá thất bại'),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: const Text('Xoá'),
                              )
                            : TextButton(
                                onPressed: () async {
                                  final id = notif['id'];
                                  final r = await _apiService
                                      .markNotificationAsRead(id as int);
                                  if (r['success']) {
                                    await _loadNotifications();
                                  } else {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(r['error'] ??
                                              'Thao tác thất bại'),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: const Text('Đánh dấu'),
                              ),
                        onTap: () {
                          // Open detail or mark as read locally
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar:
                                    AppBar(title: Text(notif['title'] ?? '')),
                                body: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(notif['message'] ?? ''),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
