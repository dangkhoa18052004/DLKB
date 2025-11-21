// admin_doctors_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/doctor_model.dart';
import '../../models/department_model.dart';

class AdminDoctorsScreen extends StatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  State<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends State<AdminDoctorsScreen> {
  final ApiService _apiService = ApiService();

  List<Doctor> _doctors = [];
  List<Department> _departments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter và phân trang
  int _currentPage = 1;
  final int _perPage = 20;
  int? _selectedDepartmentId;
  bool? _isAvailableFilter;
  String _searchQuery = '';

  // Thống kê
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadDoctors(),
      _loadDepartments(),
    ]);
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getAdminDoctors(
      page: _currentPage,
      perPage: _perPage,
      departmentId: _selectedDepartmentId,
      isAvailable: _isAvailableFilter,
    );

    if (!mounted) return;

    if (result['success']) {
      final data = result['data'];
      setState(() {
        _doctors = (data['doctors'] as List)
            .map((doctorJson) => Doctor.fromJson(doctorJson))
            .toList();
        _isLoading = false;
      });
      _calculateStats();
    } else {
      setState(() {
        _errorMessage = result['error'];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDepartments() async {
    final result = await _apiService.getAllDepartments();
    if (result['success']) {
      setState(() {
        _departments = (result['data'] as List)
            .map((deptJson) => Department.fromJson(deptJson))
            .toList();
      });
    }
  }

  void _calculateStats() {
    final stats = {
      'total': _doctors.length,
      'available': _doctors.where((d) => d.isAvailable).length,
      'averageRating': _doctors.isEmpty
          ? 0.0
          : _doctors.map((d) => d.rating).reduce((a, b) => a + b) /
              _doctors.length,
      'totalReviews':
          _doctors.map((d) => d.totalReviews).reduce((a, b) => a + b),
    };
    setState(() {
      _stats = stats;
    });
  }

  void _applyFilters() {
    _currentPage = 1;
    _loadDoctors();
  }

  void _resetFilters() {
    setState(() {
      _selectedDepartmentId = null;
      _isAvailableFilter = null;
      _searchQuery = '';
      _currentPage = 1;
    });
    _loadDoctors();
  }

  Future<void> _updateDoctorStatus(int doctorId, bool isAvailable) async {
    final result = await _apiService.updateDoctor(doctorId, {
      'is_available': isAvailable,
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Đã ${isAvailable ? 'kích hoạt' : 'vô hiệu hóa'} bác sĩ')),
      );
      _loadDoctors();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${result['error']}')),
      );
    }
  }

  void _showDoctorDetails(Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => DoctorDetailDialog(doctor: doctor),
    );
  }

  void _showEditDoctorDialog(Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => EditDoctorDialog(
        doctor: doctor,
        departments: _departments,
        onSaved: _loadDoctors,
      ),
    );
  }

  void _showDoctorSchedule(int doctorId) {
    showDialog(
      context: context,
      builder: (context) => DoctorScheduleDialog(doctorId: doctorId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Bác sĩ'),
        actions: [
          IconButton(
            onPressed: _loadDoctors,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bộ lọc
          _buildFilters(),

          // Thống kê
          _buildStatsCard(),

          // Danh sách bác sĩ
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _doctors.isEmpty
                        ? _buildEmptyWidget()
                        : _buildDoctorsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Lọc theo khoa
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedDepartmentId,
                    decoration: const InputDecoration(
                      labelText: 'Chuyên khoa',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả khoa'),
                      ),
                      ..._departments.map((dept) => DropdownMenuItem(
                            value: dept.id,
                            child: Text(dept.name),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDepartmentId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Lọc trạng thái
                Expanded(
                  child: DropdownButtonFormField<bool?>(
                    value: _isAvailableFilter,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      const DropdownMenuItem(
                        value: true,
                        child: Text('Đang hoạt động'),
                      ),
                      const DropdownMenuItem(
                        value: false,
                        child: Text('Không hoạt động'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _isAvailableFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.search),
                    label: const Text('Áp dụng bộ lọc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Đặt lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Tổng số', _stats['total']?.toString() ?? '0'),
            _buildStatItem(
                'Đang hoạt động', _stats['available']?.toString() ?? '0'),
            _buildStatItem('Đánh giá TB',
                (_stats['averageRating'] ?? 0).toStringAsFixed(1)),
            _buildStatItem(
                'Tổng review', _stats['totalReviews']?.toString() ?? '0'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('Lỗi: $_errorMessage', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDoctors,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Không có bác sĩ nào'),
        ],
      ),
    );
  }

  Widget _buildDoctorsList() {
    return ListView.builder(
      itemCount: _doctors.length,
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.person, color: Colors.blue.shade800),
            ),
            title: Text(
              doctor.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chuyên môn: ${doctor.specialization}'),
                Text('Khoa: ${_getDepartmentName(doctor.departmentId)}'),
                Text(
                    'Phí khám: ${doctor.consultationFee.toStringAsFixed(0)} ₫'),
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    Text(' ${doctor.rating.toStringAsFixed(1)}'),
                    Text(' (${doctor.totalReviews} reviews)'),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  doctor.isAvailable ? Icons.check_circle : Icons.remove_circle,
                  color: doctor.isAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleDoctorAction(value, doctor),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'details', child: Text('Xem chi tiết')),
                    const PopupMenuItem(
                        value: 'edit', child: Text('Chỉnh sửa')),
                    const PopupMenuItem(
                        value: 'schedule', child: Text('Lịch làm việc')),
                    PopupMenuItem(
                      value: doctor.isAvailable ? 'deactivate' : 'activate',
                      child: Text(
                          doctor.isAvailable ? 'Vô hiệu hóa' : 'Kích hoạt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getDepartmentName(int departmentId) {
    try {
      return _departments.firstWhere((dept) => dept.id == departmentId).name;
    } catch (e) {
      return 'Không xác định';
    }
  }

  void _handleDoctorAction(String action, Doctor doctor) {
    switch (action) {
      case 'details':
        _showDoctorDetails(doctor);
        break;
      case 'edit':
        _showEditDoctorDialog(doctor);
        break;
      case 'schedule':
        _showDoctorSchedule(doctor.id);
        break;
      case 'activate':
        _updateDoctorStatus(doctor.id, true);
        break;
      case 'deactivate':
        _updateDoctorStatus(doctor.id, false);
        break;
    }
  }
}

// Dialog chi tiết bác sĩ
class DoctorDetailDialog extends StatelessWidget {
  final Doctor doctor;

  const DoctorDetailDialog({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Chi tiết Bác sĩ: ${doctor.fullName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem('Họ tên', doctor.fullName),
            _buildDetailItem('Số giấy phép', doctor.licenseNumber),
            _buildDetailItem('Chuyên môn', doctor.specialization),
            _buildDetailItem('Kinh nghiệm', '${doctor.experienceYears} năm'),
            _buildDetailItem(
                'Phí khám', '${doctor.consultationFee.toStringAsFixed(0)} ₫'),
            _buildDetailItem(
                'Đánh giá', '${doctor.rating.toStringAsFixed(1)} ⭐'),
            _buildDetailItem('Tổng đánh giá', '${doctor.totalReviews} reviews'),
            _buildDetailItem('Trạng thái',
                doctor.isAvailable ? 'Đang hoạt động' : 'Không hoạt động'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// Dialog chỉnh sửa bác sĩ
class EditDoctorDialog extends StatefulWidget {
  final Doctor doctor;
  final List<Department> departments;
  final VoidCallback onSaved;

  const EditDoctorDialog({
    super.key,
    required this.doctor,
    required this.departments,
    required this.onSaved,
  });

  @override
  State<EditDoctorDialog> createState() => _EditDoctorDialogState();
}

class _EditDoctorDialogState extends State<EditDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late String _specialization;
  late int _experienceYears;
  late double _consultationFee;
  late int _departmentId;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _specialization = widget.doctor.specialization;
    _experienceYears = widget.doctor.experienceYears;
    _consultationFee = widget.doctor.consultationFee;
    _departmentId = widget.doctor.departmentId;
    _isAvailable = widget.doctor.isAvailable;
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final result = await _apiService.updateDoctor(widget.doctor.id, {
        'specialization': _specialization,
        'experience_years': _experienceYears,
        'consultation_fee': _consultationFee,
        'department_id': _departmentId,
        'is_available': _isAvailable,
      });

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công')),
        );
        widget.onSaved();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${result['error']}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa thông tin Bác sĩ'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _specialization,
                decoration: const InputDecoration(labelText: 'Chuyên môn'),
                onChanged: (value) => _specialization = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập chuyên môn';
                  }
                  return null;
                },
              ),
              TextFormField(
                initialValue: _experienceYears.toString(),
                decoration:
                    const InputDecoration(labelText: 'Số năm kinh nghiệm'),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    _experienceYears = int.tryParse(value) ?? 0,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số năm kinh nghiệm';
                  }
                  return null;
                },
              ),
              TextFormField(
                initialValue: _consultationFee.toStringAsFixed(0),
                decoration: const InputDecoration(labelText: 'Phí khám (VNĐ)'),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    _consultationFee = double.tryParse(value) ?? 0,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập phí khám';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<int>(
                value: _departmentId,
                decoration: const InputDecoration(labelText: 'Khoa'),
                items: widget.departments
                    .map((dept) => DropdownMenuItem(
                          value: dept.id,
                          child: Text(dept.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _departmentId = value;
                    });
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Đang hoạt động'),
                value: _isAvailable,
                onChanged: (value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Lưu thay đổi'),
        ),
      ],
    );
  }
}

// Dialog lịch làm việc
class DoctorScheduleDialog extends StatefulWidget {
  final int doctorId;

  const DoctorScheduleDialog({super.key, required this.doctorId});

  @override
  State<DoctorScheduleDialog> createState() => _DoctorScheduleDialogState();
}

class _DoctorScheduleDialogState extends State<DoctorScheduleDialog> {
  final ApiService _apiService = ApiService();
  List<dynamic> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final result = await _apiService.getDoctorSchedule(widget.doctorId);

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _schedules = result['data'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lịch làm việc'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Text('Lỗi: $_errorMessage')
              : _schedules.isEmpty
                  ? const Text('Chưa có lịch làm việc')
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _schedules.length,
                        itemBuilder: (context, index) {
                          final schedule = _schedules[index];
                          return Card(
                            child: ListTile(
                              title: Text('${schedule['day_of_week']}'),
                              subtitle: Text(
                                  '${schedule['start_time']} - ${schedule['end_time']}'),
                              trailing: Text(schedule['is_active']
                                  ? 'Hoạt động'
                                  : 'Không hoạt động'),
                            ),
                          );
                        },
                      ),
                    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
