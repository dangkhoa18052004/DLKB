import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'auth/change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;
  String? _userRole;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _allergiesController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactPhoneController;
  late TextEditingController _specializationController;
  late TextEditingController _bioController;

  String? _selectedGender;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _initControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _initControllers() {
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _bloodTypeController = TextEditingController();
    _allergiesController = TextEditingController();
    _emergencyContactNameController = TextEditingController();
    _emergencyContactPhoneController = TextEditingController();
    _specializationController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bloodTypeController.dispose();
    _allergiesController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = authService.user?['role'] ?? 'patient';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userRole = role;
    });

    try {
      Map<String, dynamic> result;

      if (role == 'doctor') {
        result = await _apiService.getDoctorProfile();
      } else {
        result = await _apiService.getMyProfile();
      }

      print("🔍 LOAD PROFILE RESPONSE ($role): $result");

      if (result['success']) {
        Map<String, dynamic> profileData;

        if (result['data'] is Map<String, dynamic>) {
          profileData = result['data'];
        } else {
          profileData = result;
        }

        print("🔍 PROFILE DATA: $profileData");

        setState(() {
          _profile = profileData;
          _populateControllers();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Không thể tải thông tin';
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ LOAD PROFILE ERROR: $e");
      setState(() {
        _errorMessage = 'Lỗi kết nối: $e';
        _isLoading = false;
      });
    }
  }

  void _populateControllers() {
    if (_profile == null) return;

    print("🔍 POPULATING CONTROLLERS - Role: $_userRole");
    print("🔍 PROFILE STRUCTURE: ${_profile!.keys}");

    Map<String, dynamic> user;
    Map<String, dynamic> specificInfo;

    if (_userRole == 'doctor') {
      user = _profile!['user'] ?? {};
      specificInfo = _profile!['doctor'] ?? {};
      print("🔍 DOCTOR USER: $user");
      print("🔍 DOCTOR INFO: $specificInfo");
    } else {
      user = _profile!['user'] ?? {};
      specificInfo = _profile!['patient'] ?? {};
      print("🔍 PATIENT USER: $user");
      print("🔍 PATIENT INFO: $specificInfo");
    }

    _fullNameController.text = user['full_name'] ?? '';
    _phoneController.text = user['phone'] ?? '';
    _emailController.text = user['email'] ?? '';
    _addressController.text = user['address'] ?? '';

    _selectedGender = _normalizeGenderValue(user['gender']);

    if (user['date_of_birth'] != null) {
      try {
        _dateOfBirth = DateTime.parse(user['date_of_birth']);
        print("🔍 DATE OF BIRTH: $_dateOfBirth");
      } catch (e) {
        print("❌ PARSE DATE ERROR: $e");
        _dateOfBirth = null;
      }
    } else {
      _dateOfBirth = null;
    }

    if (_userRole != 'doctor') {
      _bloodTypeController.text = specificInfo['blood_type'] ?? '';
      _allergiesController.text = specificInfo['allergies'] ?? '';
      _emergencyContactNameController.text =
          specificInfo['emergency_contact_name'] ?? '';
      _emergencyContactPhoneController.text =
          specificInfo['emergency_contact_phone'] ?? '';
    } else {
      _specializationController.text = specificInfo['specialization'] ?? '';
      _bioController.text = specificInfo['bio'] ?? '';
      print("🔍 SPECIALIZATION: ${_specializationController.text}");
      print("🔍 BIO: ${_bioController.text}");
    }

    print("✅ CONTROLLERS POPULATED");

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updateData = {
      'full_name': _fullNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim(),
      'gender': _selectedGender,
      'date_of_birth': _dateOfBirth?.toIso8601String().split('T')[0],
    };

    if (_userRole != 'doctor') {
      updateData.addAll({
        'blood_type': _bloodTypeController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'emergency_contact_name': _emergencyContactNameController.text.trim(),
        'emergency_contact_phone': _emergencyContactPhoneController.text.trim(),
      });
    } else {
      updateData.addAll({
        'specialization': _specializationController.text.trim(),
        'bio': _bioController.text.trim(),
      });
    }

    print("🔍 SAVE PROFILE - Role: $_userRole");
    print("🔍 UPDATE DATA: $updateData");

    try {
      final result = (_userRole == 'doctor')
          ? await _apiService.updateDoctorProfile(updateData)
          : await _apiService.updateMyProfile(updateData);

      print("🔍 SAVE RESULT: $result");

      if (result['success']) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thông tin thành công'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadProfile();
      } else {
        setState(() => _isLoading = false);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Cập nhật thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("❌ SAVE PROFILE ERROR: $e");
      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _isEditing
                  ? _buildEditForm()
                  : _buildProfileView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    if (_profile == null) return const SizedBox();

    // ✅ SỬA: Lấy đúng cấu trúc cho cả Patient và Doctor
    final user = _profile!['user'] ?? {};
    final specificInfo =
        (_userRole == 'doctor' ? _profile!['doctor'] : _profile!['patient']) ??
            {};

    print("🔍 BUILD PROFILE VIEW - Role: $_userRole");
    print("🔍 USER DATA: ${user['full_name']}");
    print(
        "🔍 SPECIFIC INFO: ${specificInfo['patient_code'] ?? specificInfo['specialization']}");

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context)
                      .colorScheme
                      .primary
                      .withAlpha((0.8 * 255).round()),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: user['avatar_url'] != null
                            ? NetworkImage(user['avatar_url'])
                            : null,
                        child: user['avatar_url'] == null
                            ? Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey.shade400,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withAlpha((0.1 * 255).round()),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  user['full_name'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userRole == 'doctor'
                      ? specificInfo['specialization'] ?? 'Bác sĩ'
                      : specificInfo['patient_code'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Thông tin cá nhân', Icons.person),
                _buildInfoCard([
                  _buildInfoRow(
                      'Họ và tên', user['full_name'] ?? 'Chưa cập nhật'),
                  _buildInfoRow('Giới tính', _getGenderText(user['gender'])),
                  _buildInfoRow(
                      'Ngày sinh', _formatDate(user['date_of_birth'])),
                  _buildInfoRow('Điện thoại', user['phone'] ?? 'Chưa cập nhật'),
                  _buildInfoRow('Email', user['email'] ?? 'Chưa cập nhật'),
                  _buildInfoRow('Địa chỉ', user['address'] ?? 'Chưa cập nhật',
                      maxLines: 2),
                ]),
                const SizedBox(height: 20),
                if (_userRole != 'doctor') ...[
                  _buildSectionTitle('Thông tin y tế', Icons.medical_services),
                  _buildInfoCard([
                    _buildInfoRow('Nhóm máu',
                        specificInfo['blood_type'] ?? 'Chưa cập nhật'),
                    _buildInfoRow(
                        'Dị ứng', specificInfo['allergies'] ?? 'Không',
                        maxLines: 3),
                    _buildInfoRow('Số BHYT',
                        specificInfo['insurance_number'] ?? 'Chưa có'),
                    _buildInfoRow('Đơn vị BH',
                        specificInfo['insurance_provider'] ?? 'Chưa có'),
                  ]),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Liên hệ khẩn cấp', Icons.emergency),
                  _buildInfoCard([
                    _buildInfoRow(
                        'Người liên hệ',
                        specificInfo['emergency_contact_name'] ??
                            'Chưa cập nhật'),
                    _buildInfoRow(
                        'Số điện thoại',
                        specificInfo['emergency_contact_phone'] ??
                            'Chưa cập nhật'),
                  ]),
                ] else ...[
                  _buildSectionTitle('Thông tin công việc', Icons.work),
                  _buildInfoCard([
                    _buildInfoRow('Chuyên môn',
                        specificInfo['specialization'] ?? 'Chưa cập nhật'),
                    _buildInfoRow('Kinh nghiệm',
                        '${specificInfo['experience_years'] ?? '0'} năm'),
                    _buildInfoRow('Phí khám',
                        '${specificInfo['consultation_fee'] ?? '0'} ₫'),
                    _buildInfoRow(
                        'Tiểu sử', specificInfo['bio'] ?? 'Chưa cập nhật',
                        maxLines: 5),
                  ]),
                ],
                const SizedBox(height: 20),
                _buildActionButton(
                  'Đổi mật khẩu',
                  Icons.lock_outline,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Thông tin cá nhân', Icons.person),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Họ và tên *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập họ tên';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: (['Nam', 'Nữ', 'Khác'].contains(_selectedGender))
                  ? _selectedGender
                  : null,
              decoration: const InputDecoration(
                labelText: 'Giới tính',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wc),
              ),
              items: const [
                DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                DropdownMenuItem(value: 'Khác', child: Text('Khác')),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(2010),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _dateOfBirth = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày sinh',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dateOfBirth != null
                      ? DateFormat('dd/MM/yyyy').format(_dateOfBirth!)
                      : 'Chọn ngày sinh',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập số điện thoại';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Email không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            if (_userRole != 'doctor') ...[
              _buildSectionTitle('Thông tin y tế', Icons.medical_services),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bloodTypeController,
                decoration: const InputDecoration(
                  labelText: 'Nhóm máu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bloodtype),
                  hintText: 'Ví dụ: A+, B-, O+, AB+',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(
                  labelText: 'Dị ứng',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning_amber),
                  hintText: 'Ví dụ: Penicillin, hải sản...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Liên hệ khẩn cấp', Icons.emergency),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContactNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên người liên hệ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emergencyContactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ] else ...[
              _buildSectionTitle('Thông tin công việc', Icons.work),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(
                  labelText: 'Chuyên môn',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_services),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập chuyên môn';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Tiểu sử/Bio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 5,
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _populateControllers();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((0.3 * 255).round())),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Chưa cập nhật';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getGenderText(String? gender) {
    if (gender == null) return 'Chưa cập nhật';
    final g = gender.toString().trim().toLowerCase();
    if (g == 'nam' || g == 'male' || g == 'm') return 'Nam';
    if (g == 'nữ' || g == 'nu' || g == 'female' || g == 'f') return 'Nữ';
    if (g == 'khác' || g == 'khac' || g == 'other') return 'Khác';
    return 'Chưa cập nhật';
  }

  String? _normalizeGenderValue(dynamic gender) {
    if (gender == null) return null;
    final g = gender.toString().trim().toLowerCase();
    if (g == 'nam' || g == 'male' || g == 'm') return 'Nam';
    if (g == 'nữ' || g == 'nu' || g == 'female' || g == 'f') return 'Nữ';
    if (g == 'khác' || g == 'khac' || g == 'other') return 'Khác';
    return null;
  }
}
