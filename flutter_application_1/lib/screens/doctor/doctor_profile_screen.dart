// doctor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEditing = false;

  // Controllers cho các trường có thể chỉnh sửa
  late TextEditingController _bioController;
  late TextEditingController _specController;
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _specController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getDoctorProfile(); // Dùng API có sẵn

    if (!mounted) return;

    if (result['success'] && result['data'] != null) {
      final data = result['data'];
      // Giả định API trả về cấu trúc {user: {...}, doctor: {...}}
      // Hiện tại API getMyProfile() chỉ dành cho patient.
      // Ta cần giả định API /doctor/profile (như trong doctor_routers.py) tồn tại và hoạt động.

      // Khởi tạo các controller sau khi có dữ liệu
      _bioController = TextEditingController(text: data['doctor']['bio'] ?? '');
      _specController =
          TextEditingController(text: data['doctor']['specialization'] ?? '');
      _isAvailable = data['doctor']['is_available'] ?? true;

      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Không thể tải hồ sơ bác sĩ';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    final updateData = {
      'bio': _bioController.text,
      'specialization': _specController.text,
      'is_available': _isAvailable,
      // Thêm các trường khác cần chỉnh sửa (experience_years, education, consultation_fee)
    };

    final result =
        await _apiService.put('/doctor/profile', updateData); // Gọi API PUT

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
      _loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error'] ?? 'Lỗi khi cập nhật.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $_errorMessage')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _profileData?['user'];
    final doctor = _profileData?['doctor'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Bác sĩ'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Lỗi: $_errorMessage'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Thông tin cơ bản (Không chỉnh sửa)
                      _buildInfoTile(
                          Icons.person, 'Họ tên', user?['full_name'] ?? 'N/A'),
                      _buildInfoTile(
                          Icons.email, 'Email', user?['email'] ?? 'N/A'),
                      _buildInfoTile(
                          Icons.phone, 'Điện thoại', user?['phone'] ?? 'N/A'),
                      const Divider(),

                      // Thông tin chuyên môn (Có thể chỉnh sửa)
                      _buildEditableTile(
                          Icons.star_rate,
                          'Chuyên môn',
                          _isEditing ? _specController : null,
                          doctor?['specialization'] ?? 'N/A',
                          readOnly: !_isEditing),
                      _buildEditableTile(
                          Icons.description,
                          'Tiểu sử (Bio)',
                          _isEditing ? _bioController : null,
                          doctor?['bio'] ?? 'Chưa có',
                          maxLines: 5,
                          readOnly: !_isEditing),
                      _buildInfoTile(Icons.badge, 'Mã số GP',
                          doctor?['license_number'] ?? 'N/A'),
                      _buildInfoTile(Icons.grade, 'Rating TB',
                          '${doctor?['rating'] ?? 0.0} / 5.0'),

                      const Divider(),

                      // Trạng thái sẵn có (Toggle)
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Sẵn có để khám'),
                        trailing: Switch(
                          value: _isAvailable,
                          onChanged: _isEditing
                              ? (bool value) {
                                  setState(() {
                                    _isAvailable = value;
                                  });
                                }
                              : null,
                        ),
                        subtitle: Text(
                            _isAvailable ? 'Đang hoạt động' : 'Đã tạm khóa'),
                      ),
                      const Divider(),

                      // Nút lưu (chỉ khi đang chỉnh sửa)
                      if (_isEditing)
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            child: const Text('Lưu Thay Đổi'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildEditableTile(IconData icon, String title,
      TextEditingController? controller, String currentValue,
      {int maxLines = 1, required bool readOnly}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: TextFormField(
          controller: controller ?? TextEditingController(text: currentValue),
          maxLines: maxLines,
          readOnly: readOnly,
          decoration: InputDecoration(
            border: readOnly ? InputBorder.none : const OutlineInputBorder(),
            hintText: title,
          ),
          style: TextStyle(color: readOnly ? Colors.black : null),
        ),
      ),
    );
  }
}
