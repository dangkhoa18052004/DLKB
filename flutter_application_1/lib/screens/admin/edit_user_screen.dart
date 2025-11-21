import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  final _newPasswordController = TextEditingController();

  String? _selectedGender;
  DateTime? _dateOfBirth;
  late bool _isActive;
  late bool _isVerified;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fullNameController =
        TextEditingController(text: widget.user['full_name'] ?? '');
    _emailController = TextEditingController(text: widget.user['email'] ?? '');
    _phoneController = TextEditingController(text: widget.user['phone'] ?? '');
    _addressController =
        TextEditingController(text: widget.user['address'] ?? '');
    _selectedGender = widget.user['gender'];
    _isActive = widget.user['is_active'] ?? true;
    _isVerified = widget.user['is_verified'] ?? false;

    final dobString = widget.user['date_of_birth'];
    if (dobString != null) {
      try {
        _dateOfBirth = DateFormat('yyyy-MM-dd HH:mm:ss').parse(dobString);
      } catch (e) {
        // Handle cases where datetime string is not full format (e.g., only date)
        try {
          _dateOfBirth = DateFormat('yyyy-MM-dd').parse(dobString);
        } catch (e) {
          _dateOfBirth = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updateData = {
      'full_name': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'gender': _selectedGender,
      'is_active': _isActive,
      'is_verified': _isVerified,
      'date_of_birth': _dateOfBirth?.toIso8601String().split('T')[0],
      if (_newPasswordController.text.isNotEmpty)
        'password': _newPasswordController.text,
    };

    try {
      final response =
          await _apiService.updateUser(widget.user['id'], updateData);

      setState(() => _isLoading = false);

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật người dùng thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Trả về true để load lại list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Cập nhật thất bại'),
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
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'admin':
        return 'Quản trị viên';
      case 'doctor':
        return 'Bác sĩ';
      case 'staff':
        return 'Nhân viên';
      case 'patient':
        return 'Bệnh nhân';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sửa User: ${widget.user['username']}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin vai trò
              Text(
                'Vai trò: ${_getRoleText(widget.user['role'])}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple),
              ),
              const SizedBox(height: 16),

              // === THÔNG TIN CƠ BẢN ===
              _buildSectionTitle('Thông tin cá nhân', Icons.person),
              const SizedBox(height: 16),

              // Họ và tên
              TextFormField(
                controller: _fullNameController,
                decoration:
                    _inputDecoration('Họ và tên *', Icons.person_outline),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email *', Icons.email),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập email'
                    : null,
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Số điện thoại *', Icons.phone),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập số điện thoại'
                    : null,
              ),
              const SizedBox(height: 16),

              // Địa chỉ
              TextFormField(
                controller: _addressController,
                decoration: _inputDecoration('Địa chỉ', Icons.home),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Giới tính
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _inputDecoration('Giới tính', Icons.wc),
                items: const [
                  DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                  DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                  DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                ],
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 16),

              // Ngày sinh
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration:
                      _inputDecoration('Ngày sinh', Icons.calendar_today),
                  child: Text(
                    _dateOfBirth != null
                        ? DateFormat('dd/MM/yyyy').format(_dateOfBirth!)
                        : 'Chọn ngày sinh',
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // === BẢO MẬT & TRẠNG THÁI ===
              _buildSectionTitle('Bảo mật & Trạng thái', Icons.security),
              const SizedBox(height: 16),

              // Mật khẩu mới
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới (Bỏ trống nếu không đổi)',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kích hoạt/Vô hiệu hóa
              SwitchListTile(
                title: const Text('Kích hoạt tài khoản'),
                subtitle: Text(_isActive ? 'Hoạt động' : 'Vô hiệu hóa'),
                value: _isActive,
                onChanged: (bool value) {
                  setState(() => _isActive = value);
                },
              ),

              // Xác thực Email
              SwitchListTile(
                title: const Text('Đã xác thực Email'),
                subtitle: Text(_isVerified ? 'Đã xác thực' : 'Chưa xác thực'),
                value: _isVerified,
                onChanged: (bool value) {
                  setState(() => _isVerified = value);
                },
              ),
              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateUser,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text(
                          'Lưu Thay Đổi',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
}
