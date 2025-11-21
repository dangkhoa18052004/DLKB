import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'package:intl/intl.dart';

class DoctorAppointmentListScreen extends StatefulWidget {
  const DoctorAppointmentListScreen({super.key});

  @override
  State<DoctorAppointmentListScreen> createState() =>
      _DoctorAppointmentListScreenState();
}

class _DoctorAppointmentListScreenState
    extends State<DoctorAppointmentListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  String? _selectedStatus;

  final List<String> _statuses = [
    'pending',
    'confirmed',
    'checked_in',
    'completed',
    'cancelled'
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

    final dateFilter = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Giả định hàm getMyAppointments() trong api_service.dart có thể nhận date và endpoint đã được ánh xạ đúng tới /doctor/appointments
    final result = await _apiService.getMyAppointments(
      date: dateFilter,
      status: _selectedStatus,
    );

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _appointments = result['data']['appointments'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Lỗi tải lịch hẹn';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAppointments();
    }
  }

  Future<void> _handleCheckIn(int appointmentId, String currentStatus) async {
    if (currentStatus != 'confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Chỉ có thể Check-in lịch hẹn ở trạng thái Confirmed.')),
      );
      return;
    }

    // Gọi API PUT /doctor/appointments/<id>/check-in
    final result = await _apiService
        .put('/doctor/appointments/$appointmentId/check-in', {});

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in thành công!')),
      );
      _loadAppointments(); // Tải lại danh sách
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi Check-in: ${result['error']}')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue.shade600;
      case 'checked_in':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch hẹn Hôm nay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ActionChip(
                    label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    avatar: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Trạng thái'),
                    value: _selectedStatus,
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Tất cả')),
                      ..._statuses.map((status) => DropdownMenuItem(
                          value: status, child: Text(status.toUpperCase()))),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedStatus = newValue;
                      });
                      _loadAppointments();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Danh sách
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Lỗi: $_errorMessage'))
                    : _appointments.isEmpty
                        ? const Center(child: Text('Không có lịch hẹn nào.'))
                        : ListView.builder(
                            itemCount: _appointments.length,
                            itemBuilder: (context, index) {
                              final app = _appointments[index];
                              final statusColor =
                                  _getStatusColor(app['status']);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading:
                                      Icon(Icons.timer, color: statusColor),
                                  title: Text(
                                    '${app['appointment_time']} - ${app['patient_name']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Mã: ${app['appointment_code']} | SĐT: ${app['patient_phone'] ?? 'N/A'}\nTrạng thái: ${app['status'].toUpperCase()}',
                                  ),
                                  trailing: app['status'] == 'confirmed'
                                      ? ElevatedButton(
                                          onPressed: () => _handleCheckIn(
                                              app['id'], app['status']),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal),
                                          child: const Text('Check-in',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        )
                                      : app['status'] == 'checked_in'
                                          ? const Icon(Icons.pending_actions,
                                              color: Colors.orange)
                                          : null,
                                  isThreeLine: true,
                                  onTap: () {
                                    // TODO: Điều hướng đến màn hình Khám & Hồ sơ Bệnh án
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
