import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'package:intl/intl.dart';
import 'register_schedule_screen.dart';

class DoctorScheduleManagementScreen extends StatefulWidget {
  const DoctorScheduleManagementScreen({super.key});

  @override
  State<DoctorScheduleManagementScreen> createState() =>
      _DoctorScheduleManagementScreenState();
}

class _DoctorScheduleManagementScreenState
    extends State<DoctorScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<dynamic> _schedules = [];
  List<dynamic> _leaves = [];
  bool _isLoadingSchedules = true;
  bool _isLoadingLeaves = true;
  String? _errorMessage;

  final Map<int, String> _dayNames = {
    0: 'Chủ Nhật',
    1: 'Thứ Hai',
    2: 'Thứ Ba',
    3: 'Thứ Tư',
    4: 'Thứ Năm',
    5: 'Thứ Sáu',
    6: 'Thứ Bảy',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchedules();
    _loadLeaves();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoadingSchedules = true;
      _errorMessage = null;
    });

    // ✅ GỌI API ĐÚNG: GET /doctor/schedules (lịch của chính bác sĩ)
    final result = await _apiService.getDoctorSchedules();

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        // ✅ Backend trả về list trực tiếp, không có key 'data'
        _schedules = result['data'] is List
            ? result['data']
            : (result['data'] as List? ?? []);
        _isLoadingSchedules = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Không thể tải lịch làm việc';
        _isLoadingSchedules = false;
      });
    }
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _isLoadingLeaves = true;
    });

    final result = await _apiService.get('/doctor/leaves', {});

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _leaves = result['data'] ?? [];
        _isLoadingLeaves = false;
      });
    } else {
      setState(() {
        _isLoadingLeaves = false;
      });
    }
  }

  Future<void> _deleteSchedule(int scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ca làm việc này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _apiService.delete('/doctor/schedules/$scheduleId');

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Xóa ca làm việc thành công'),
            backgroundColor: Colors.green),
      );
      _loadSchedules();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Lỗi: ${result['error']}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _registerLeave() async {
    final dateController = TextEditingController();
    final reasonController = TextEditingController();
    bool isFullDay = true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đăng ký Nghỉ phép'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Ngày nghỉ',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      dateController.text =
                          DateFormat('yyyy-MM-dd').format(date);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Lý do',
                    prefixIcon: Icon(Icons.note),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Nghỉ cả ngày'),
                  value: isFullDay,
                  onChanged: (value) {
                    setDialogState(() {
                      isFullDay = value;
                    });
                  },
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
                if (dateController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn ngày')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'leave_date': dateController.text,
                  'reason': reasonController.text,
                  'is_full_day': isFullDay,
                });
              },
              child: const Text('Đăng ký'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    final apiResult = await _apiService.post('/doctor/leaves', result);

    if (!mounted) return;

    if (apiResult['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đăng ký nghỉ phép thành công'),
            backgroundColor: Colors.green),
      );
      _loadLeaves();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Lỗi: ${apiResult['error']}'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lịch làm việc'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.schedule), text: 'Lịch định kỳ'),
            Tab(icon: Icon(Icons.event_busy), text: 'Ngày nghỉ'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const RegisterScheduleScreen()),
            ).then((_) => _loadSchedules());
          } else {
            _registerLeave();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Thêm ca' : 'Đăng ký nghỉ'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleTab(),
          _buildLeaveTab(),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    if (_isLoadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            ElevatedButton(
              onPressed: _loadSchedules,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Chưa có lịch làm việc định kỳ',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const RegisterScheduleScreen()),
                ).then((_) => _loadSchedules());
              },
              icon: const Icon(Icons.add),
              label: const Text('Tạo ca làm việc đầu tiên'),
            ),
          ],
        ),
      );
    }

    // Nhóm lịch theo ngày
    Map<int, List<dynamic>> schedulesByDay = {};
    for (var schedule in _schedules) {
      int dayOfWeek = schedule['day_of_week'];
      if (!schedulesByDay.containsKey(dayOfWeek)) {
        schedulesByDay[dayOfWeek] = [];
      }
      schedulesByDay[dayOfWeek]!.add(schedule);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final daySchedules = schedulesByDay[index] ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: daySchedules.isNotEmpty
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Icon(
                Icons.calendar_today,
                color: daySchedules.isNotEmpty
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
            title: Text(
              _dayNames[index]!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              daySchedules.isEmpty
                  ? 'Không có ca làm việc'
                  : '${daySchedules.length} ca làm việc',
              style: TextStyle(
                color: daySchedules.isEmpty
                    ? Colors.grey.shade600
                    : Colors.green.shade700,
              ),
            ),
            children: daySchedules.isEmpty
                ? []
                : daySchedules.map<Widget>((schedule) {
                    return ListTile(
                      leading: Icon(Icons.access_time,
                          color: schedule['is_active']
                              ? Colors.blue.shade700
                              : Colors.grey),
                      title: Text(
                        '${schedule['start_time']} - ${schedule['end_time']}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: schedule['is_active']
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        'Tối đa: ${schedule['max_patients']} bệnh nhân',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: schedule['is_active']
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: schedule['is_active']
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                            child: Text(
                              schedule['is_active'] ? 'Hoạt động' : 'Tạm dừng',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: schedule['is_active']
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSchedule(schedule['id']),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLeaveTab() {
    if (_isLoadingLeaves) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaves.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Chưa có ngày nghỉ nào',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _registerLeave,
              icon: const Icon(Icons.add),
              label: const Text('Đăng ký nghỉ phép'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaves.length,
      itemBuilder: (context, index) {
        final leave = _leaves[index];
        final leaveDate = DateTime.parse(leave['leave_date']);
        final isPast = leaveDate.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isPast ? Colors.grey.shade200 : Colors.orange.shade100,
              child: Icon(
                isPast ? Icons.event_busy : Icons.event_note,
                color: isPast ? Colors.grey.shade600 : Colors.orange.shade700,
              ),
            ),
            title: Text(
              DateFormat('dd/MM/yyyy').format(leaveDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leave['is_full_day']
                      ? 'Nghỉ cả ngày'
                      : '${leave['start_time']} - ${leave['end_time']}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (leave['reason'] != null && leave['reason'].isNotEmpty)
                  Text(
                    'Lý do: ${leave['reason']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            trailing: isPast
                ? const Chip(
                    label: Text('Đã qua', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.grey,
                    labelStyle: TextStyle(color: Colors.white),
                  )
                : const Chip(
                    label: Text('Sắp tới', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.orange,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
          ),
        );
      },
    );
  }
}
