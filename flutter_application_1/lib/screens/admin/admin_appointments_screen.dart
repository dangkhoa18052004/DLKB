import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState extends State<AdminAppointmentsScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter states
  String? _selectedStatus;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalAppointments = 0;

  // Status options
  final List<Map<String, dynamic>> _statusOptions = [
    {'value': null, 'label': 'Tất cả', 'color': Colors.grey},
    {'value': 'pending', 'label': 'Chờ xác nhận', 'color': Colors.orange},
    {'value': 'confirmed', 'label': 'Đã xác nhận', 'color': Colors.blue},
    {'value': 'completed', 'label': 'Hoàn thành', 'color': Colors.green},
    {'value': 'cancelled', 'label': 'Đã hủy', 'color': Colors.red},
    {'value': 'no_show', 'label': 'Không đến', 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getAdminAppointments(
      page: _currentPage,
      perPage: 20,
      status: _selectedStatus,
      dateFrom: _dateFrom?.toIso8601String().split('T')[0],
      dateTo: _dateTo?.toIso8601String().split('T')[0],
    );

    if (result['success']) {
      setState(() {
        _appointments = result['data']['appointments'] ?? [];
        _totalPages = result['data']['pages'] ?? 1;
        _totalAppointments = result['data']['total'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'];
        _isLoading = false;
      });
    }
  }

  Future<void> _showStatusUpdateDialog(Map<String, dynamic> appointment) async {
    final currentStatus = appointment['status'];
    String? newStatus;

    List<String> allowedStatuses = _getAllowedNextStatuses(currentStatus);

    if (allowedStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể thay đổi trạng thái từ "$currentStatus"'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật trạng thái'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã: ${appointment['appointment_code']}'),
            Text('BN: ${appointment['patient_name']}'),
            const SizedBox(height: 16),
            Text('Hiện tại: ${_getStatusLabel(currentStatus)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Chọn trạng thái mới:'),
            const SizedBox(height: 8),
            ...allowedStatuses.map((status) {
              return RadioListTile<String>(
                title: Text(_getStatusLabel(status)),
                value: status,
                groupValue: newStatus,
                onChanged: (value) => Navigator.pop(context, value),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateAppointmentStatus(appointment['id'], result);
    }
  }

  List<String> _getAllowedNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'pending':
        return ['confirmed', 'cancelled'];
      case 'confirmed':
        return ['checked_in', 'cancelled', 'no_show'];
      case 'checked_in':
        return ['completed', 'cancelled'];
      default:
        return [];
    }
  }

  Future<void> _updateAppointmentStatus(
      int appointmentId, String newStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String? reason;
    if (newStatus == 'cancelled') {
      Navigator.pop(context);
      reason = await _showCancelReasonDialog();
      if (reason == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    final result = await _apiService.updateAppointmentStatus(
      appointmentId,
      newStatus,
      reason: reason,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật trạng thái'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAppointments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showCancelReasonDialog() async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lý do hủy'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nhập lý do...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    return _statusOptions.firstWhere(
      (s) => s['value'] == status,
      orElse: () => {'label': status},
    )['label'];
  }

  Color _getStatusColor(String status) {
    return _statusOptions.firstWhere(
      (s) => s['value'] == status,
      orElse: () => {'color': Colors.grey},
    )['color'];
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Bộ lọc',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedStatus != null ||
                    _dateFrom != null ||
                    _dateTo != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _dateFrom = null;
                        _dateTo = null;
                        _currentPage = 1;
                      });
                      _loadAppointments();
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Xóa'),
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Status chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusOptions.map((option) {
                final isSelected = _selectedStatus == option['value'];
                return FilterChip(
                  label: Text(option['label']),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatus = selected ? option['value'] : null;
                      _currentPage = 1;
                    });
                    _loadAppointments();
                  },
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: (option['color'] as Color).withOpacity(0.2),
                  checkmarkColor: option['color'],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date range
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _dateFrom = date;
                          _currentPage = 1;
                        });
                        _loadAppointments();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Từ ngày',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dateFrom != null
                            ? DateFormat('dd/MM/yyyy').format(_dateFrom!)
                            : 'Chọn ngày',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dateTo ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() {
                          _dateTo = date;
                          _currentPage = 1;
                        });
                        _loadAppointments();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Đến ngày',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _dateTo != null
                            ? DateFormat('dd/MM/yyyy').format(_dateTo!)
                            : 'Chọn ngày',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
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
            Text('Lỗi: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAppointments,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_appointments.isEmpty) {
      return const Center(child: Text('Không có lịch hẹn'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng: $_totalAppointments',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Trang $_currentPage/$_totalPages'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAppointments,
            child: ListView.builder(
              itemCount: _appointments.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                return _buildAppointmentCard(_appointments[index]);
              },
            ),
          ),
        ),
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> apt) {
    final status = apt['status'];
    final color = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(apt['appointment_code'] ?? ''),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(apt['patient_name'] ?? '')),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.medical_services, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('BS. ${apt['doctor_name'] ?? ''}')),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Text(apt['appointment_date'] ?? ''),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(apt['appointment_time'] ?? ''),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_getAllowedNextStatuses(status).isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _showStatusUpdateDialog(apt),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Cập nhật'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadAppointments();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$_currentPage / $_totalPages'),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadAppointments();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lịch hẹn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
        ],
      ),
      // ✅ THÊM SafeArea BỌC BODY
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterSection(),
            Expanded(child: _buildAppointmentsList()),
          ],
        ),
      ),
    );
  }
}
