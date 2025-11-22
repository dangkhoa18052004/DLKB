// file: screens/doctor/register_schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class RegisterScheduleScreen extends StatefulWidget {
  const RegisterScheduleScreen({super.key});

  @override
  State<RegisterScheduleScreen> createState() => _RegisterScheduleScreenState();
}

class _RegisterScheduleScreenState extends State<RegisterScheduleScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Danh sách các ngày trong tuần (giá trị gửi lên Backend)
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  // Tên hiển thị tiếng Việt
  final Map<String, String> _dayDisplayNames = {
    'Monday': 'Thứ Hai',
    'Tuesday': 'Thứ Ba',
    'Wednesday': 'Thứ Tư',
    'Thursday': 'Thứ Năm',
    'Friday': 'Thứ Sáu',
    'Saturday': 'Thứ Bảy',
    'Sunday': 'Chủ Nhật',
  };

  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isActive = true; // Mặc định là Hoạt động

  // Phương thức chọn giờ
  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 17, minute: 0)),
      builder: (BuildContext context, Widget? child) {
        // Đảm bảo dùng định dạng 24h
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // Phương thức gửi dữ liệu lên API
  Future<void> _submitSchedule() async {
    if (!_formKey.currentState!.validate() ||
        _selectedDay == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin.')),
      );
      return;
    }

    // Kiểm tra Giờ kết thúc phải sau Giờ bắt đầu
    final now = DateTime.now();
    final dtStart = DateTime(
        now.year, now.month, now.day, _startTime!.hour, _startTime!.minute);
    final dtEnd = DateTime(
        now.year, now.month, now.day, _endTime!.hour, _endTime!.minute);

    if (dtEnd.isBefore(dtStart) || dtEnd.isAtSameMomentAs(dtStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Chuẩn bị dữ liệu gửi (dùng định dạng HH:mm)
    final String startTimeStr = DateFormat('HH:mm').format(DateTime(0)
        .add(Duration(hours: _startTime!.hour, minutes: _startTime!.minute)));
    final String endTimeStr = DateFormat('HH:mm').format(DateTime(0)
        .add(Duration(hours: _endTime!.hour, minutes: _endTime!.minute)));

    final result = await _apiService.post('/doctor/schedules', {
      'day_of_week': _selectedDay, // Ex: 'Monday'
      'start_time': startTimeStr, // Ex: '08:00'
      'end_time': endTimeStr, // Ex: '17:00'
      'is_active': _isActive,
    });

    if (!mounted) return;
    Navigator.pop(context); // Đóng loading dialog

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đăng ký ca làm việc định kỳ thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      // Xóa form sau khi thành công (optional)
      setState(() {
        _selectedDay = null;
        _startTime = null;
        _endTime = null;
        _isActive = true;
      });
    } else {
      // Xử lý lỗi trùng lặp (lỗi bạn gặp trước đó)
      String errorMessage = result['error'] ?? 'Không thể đăng ký lịch.';
      if (errorMessage.contains('Schedule already exists for this time slot')) {
        errorMessage =
            'Lỗi: Ca làm việc này đã bị trùng lặp với một ca đã đăng ký.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký Ca làm việc Định kỳ'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Chọn Ngày trong tuần
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ngày trong tuần *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                value: _selectedDay,
                hint: const Text('Chọn ngày'),
                items: _daysOfWeek.map((String day) {
                  return DropdownMenuItem<String>(
                    value: day,
                    child: Text(_dayDisplayNames[day]!),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDay = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Vui lòng chọn ngày.' : null,
              ),
              const SizedBox(height: 20),

              // 2. Chọn Giờ Bắt đầu và Giờ Kết thúc
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Giờ Bắt đầu *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _startTime == null
                              ? 'Chọn giờ'
                              : _startTime!.format(context),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Giờ Kết thúc *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_filled),
                        ),
                        child: Text(
                          _endTime == null
                              ? 'Chọn giờ'
                              : _endTime!.format(context),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3. Trạng thái Hoạt động
              SwitchListTile(
                title: const Text('Ca làm việc đang Hoạt động'),
                subtitle: const Text(
                    'Nếu tắt, ca làm việc này sẽ không xuất hiện cho bệnh nhân đặt lịch.'),
                value: _isActive,
                onChanged: (bool value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                secondary: Icon(
                    _isActive ? Icons.check_circle : Icons.pause_circle_outline,
                    color: _isActive ? Colors.green : Colors.grey),
              ),

              const SizedBox(height: 30),

              // 4. Nút Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitSchedule,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Đăng ký Ca làm việc'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text('Lưu ý: Ca làm việc này sẽ được lặp lại hàng tuần.'),
            ],
          ),
        ),
      ),
    );
  }
}
