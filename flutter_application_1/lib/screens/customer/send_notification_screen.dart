import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ĐỊNH NGHĨA ENUM ĐƯỢC CHIA SẺ GIỮA CÁC FILE
enum NotificationType { single, broadcast }

class SendNotificationScreen extends StatefulWidget {
  final NotificationType initialType;
  const SendNotificationScreen({super.key, required this.initialType});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _recipientIdController = TextEditingController();

  NotificationType? _currentType;
  String? _selectedTargetRole; // Cho Broadcast
  bool _isLoading = false;

  final List<String> _targetRoles = ['all', 'patient', 'doctor', 'staff'];

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    if (_currentType == NotificationType.broadcast) {
      _selectedTargetRole = 'all';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _recipientIdController.dispose();
    super.dispose();
  }

  void _switchType(NotificationType type) {
    setState(() {
      _currentType = type;
      if (type == NotificationType.broadcast) {
        _selectedTargetRole = 'all';
        _recipientIdController.clear();
      } else {
        _selectedTargetRole = null;
      }
    });
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    Map<String, dynamic> response;

    try {
      if (_currentType == NotificationType.single) {
        final int? recipientId =
            int.tryParse(_recipientIdController.text.trim());
        if (recipientId == null) throw Exception("ID người nhận không hợp lệ.");

        final data = {
          'recipient_id': recipientId,
          'title': title,
          'message': message,
        };
        response = await _apiService.sendNotification(data);
      } else {
        // Broadcast
        final data = {
          'title': title,
          'message': message,
          'target_role': _selectedTargetRole,
        };
        response = await _apiService.broadcastNotification(data);
      }

      setState(() => _isLoading = false);

      if (response['success']) {
        if (mounted) {
          final count = response['data']['sent_count'] ?? 1;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gửi thông báo thành công! (${count} người nhận)'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Gửi thông báo thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentType == NotificationType.single
            ? 'Gửi Thông báo Cá nhân'
            : 'Gửi Thông báo Hàng loạt'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nút chuyển đổi chế độ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTypeButton(NotificationType.single, 'Cá nhân'),
                  const SizedBox(width: 16),
                  _buildTypeButton(NotificationType.broadcast, 'Hàng loạt'),
                ],
              ),
              const SizedBox(height: 32),

              // === Form Content ===

              // Tiêu đề
              TextFormField(
                controller: _titleController,
                decoration:
                    _inputDecoration('Tiêu đề thông báo *', Icons.title),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập tiêu đề'
                    : null,
              ),
              const SizedBox(height: 16),

              // Nội dung
              TextFormField(
                controller: _messageController,
                decoration:
                    _inputDecoration('Nội dung thông báo *', Icons.message),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập nội dung'
                    : null,
              ),
              const SizedBox(height: 32),

              if (_currentType == NotificationType.single) ...[
                // ID người nhận
                TextFormField(
                  controller: _recipientIdController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                      'ID Người nhận * (VD: 1, 2)', Icons.person_search),
                  validator: (value) =>
                      value == null || int.tryParse(value) == null
                          ? 'Vui lòng nhập ID người nhận hợp lệ'
                          : null,
                ),
                const SizedBox(height: 16),
              ],

              if (_currentType == NotificationType.broadcast) ...[
                // Vai trò mục tiêu
                DropdownButtonFormField<String>(
                  value: _selectedTargetRole,
                  decoration:
                      _inputDecoration('Gửi đến Vai trò *', Icons.group),
                  items: _targetRoles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_getRoleText(role)),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedTargetRole = value),
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn vai trò' : null,
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 40),

              // Nút Gửi
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendNotification,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Icon(Icons.send, size: 20),
                  label: Text('Gửi thông báo',
                      style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(NotificationType type, String label) {
    final bool isSelected = _currentType == type;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _switchType(type),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.white,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade700,
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'all':
        return 'Tất cả người dùng';
      case 'patient':
        return 'Bệnh nhân';
      case 'doctor':
        return 'Bác sĩ';
      case 'staff':
        return 'Nhân viên';
      default:
        return role;
    }
  }
}
