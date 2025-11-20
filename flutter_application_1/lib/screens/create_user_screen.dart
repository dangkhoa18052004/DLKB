import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Doctor/Patient specific fields
  final _licenseController = TextEditingController();
  final _specializationController = TextEditingController();
  final _feeController = TextEditingController();

  String _selectedRole = 'patient';
  String? _selectedGender;
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _specializationController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userData = {
      'username': _usernameController.text.trim(),
      'password': _passwordController.text,
      'email': _emailController.text.trim(),
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'role': _selectedRole,
      'gender': _selectedGender,
      'date_of_birth': _dateOfBirth?.toIso8601String().split('T')[0],
      // Thêm các trường Doctor/Patient nếu có
      if (_selectedRole == 'doctor') ...{
        'license_number': _licenseController.text.trim(),
        'department_id': 1, // Tạm thời để 1, cần có Dropdown Department thực tế
        'specialization': _specializationController.text.trim(),
        'consultation_fee': num.tryParse(_feeController.text.trim()) ?? 0,
      }
      // Các trường patient khác (blood_type, insurance,...) có thể bổ sung sau
    };

    try {
      final response = await _apiService.createUser(userData);

      setState(() => _isLoading = false);

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tạo tài khoản ${_selectedRole} thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Trả về true để load lại list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Tạo tài khoản thất bại'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Người dùng mới'),
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
              // Chọn Vai trò
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'Vai trò *',
                  prefixIcon: const Icon(Icons.security),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'patient', child: Text('Bệnh nhân')),
                  DropdownMenuItem(value: 'doctor', child: Text('Bác sĩ')),
                  DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                  DropdownMenuItem(
                      value: 'admin', child: Text('Quản trị viên')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value!),
                validator: (value) =>
                    value == null ? 'Vui lòng chọn vai trò' : null,
              ),
              const SizedBox(height: 24),

              // === THÔNG TIN CƠ BẢN ===
              Text('Thông tin cơ bản',
                  style: Theme.of(context).textTheme.titleLarge),
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

              // Tên đăng nhập
              TextFormField(
                controller: _usernameController,
                decoration:
                    _inputDecoration('Tên đăng nhập *', Icons.account_circle),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập tên đăng nhập'
                    : null,
              ),
              const SizedBox(height: 16),

              // Mật khẩu
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu *',
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
                  if (value == null || value.isEmpty)
                    return 'Vui lòng nhập mật khẩu';
                  if (value.length < 6)
                    return 'Mật khẩu phải có ít nhất 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email *', Icons.email),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Vui lòng nhập email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
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
                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                        : 'Chọn ngày sinh',
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // === THÔNG TIN CHUYÊN MÔN (Nếu là Doctor) ===
              if (_selectedRole == 'doctor') ...[
                Text('Thông tin Bác sĩ',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                // License Number
                TextFormField(
                  controller: _licenseController,
                  decoration:
                      _inputDecoration('Số giấy phép *', Icons.card_membership),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập số giấy phép'
                      : null,
                ),
                const SizedBox(height: 16),

                // Specialization
                TextFormField(
                  controller: _specializationController,
                  decoration: _inputDecoration('Chuyên khoa', Icons.healing),
                ),
                const SizedBox(height: 16),

                // Consultation Fee
                TextFormField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  decoration:
                      _inputDecoration('Phí tư vấn', Icons.attach_money),
                ),
                const SizedBox(height: 32),
              ],

              // Register Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createUser,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                      : Text(
                          'Tạo tài khoản ${_selectedRole}',
                          style: const TextStyle(fontSize: 16),
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
