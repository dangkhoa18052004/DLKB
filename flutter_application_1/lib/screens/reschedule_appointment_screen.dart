import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class RescheduleAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const RescheduleAppointmentScreen({super.key, required this.appointment});

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
  final ApiService _apiService = ApiService();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTimeSlot;
  Future<Map<String, dynamic>>? _slotsFuture;
  bool _isRescheduling = false;

  late final int _appointmentId;
  late final int _doctorId;
  late final String _doctorName;
  late final String _appointmentCode;

  @override
  void initState() {
    super.initState();
    // Defensive reads: appointment payload may have different key types
    _appointmentId = (widget.appointment['id'] is int)
        ? widget.appointment['id'] as int
        : int.tryParse('${widget.appointment['id']}') ?? 0;
    _doctorId = (widget.appointment['doctor_id'] is int)
        ? widget.appointment['doctor_id'] as int
        : int.tryParse('${widget.appointment['doctor_id']}') ?? 0;
    _doctorName = widget.appointment['doctor_name']?.toString() ?? '';
    _appointmentCode = widget.appointment['code']?.toString() ?? '';

    // Khởi tạo ngày khám mới là ngày sớm nhất có thể; safe-parse
    try {
      final parsed = DateTime.parse(widget.appointment['date']);
      _selectedDate = parsed.add(const Duration(days: 1));
    } catch (e) {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
    }

    _loadAvailableSlots();
  }

  void _loadAvailableSlots() {
    setState(() {
      _selectedTimeSlot = null;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _slotsFuture = _apiService.getAvailableSlots(_doctorId, dateStr); //
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _loadAvailableSlots();
      });
    }
  }

  Future<void> _handleReschedule() async {
    if (_selectedTimeSlot == null) {
      _showSnackBar('Vui lòng chọn khung giờ khám mới.', Colors.orange);
      return;
    }

    setState(() => _isRescheduling = true);

    final newDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final result = await _apiService.rescheduleAppointment(
      _appointmentId,
      newDateStr,
      _selectedTimeSlot!,
    ); //

    setState(() => _isRescheduling = false);

    if (result['success'] && mounted) {
      _showSnackBar('Đổi lịch thành công!', Colors.green);
      Navigator.pop(context, true); // Quay lại MyAppointmentsScreen và refresh
    } else if (mounted) {
      _showSnackBar(result['error'] ?? 'Đổi lịch thất bại', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi lịch Khám bệnh'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppointmentSummary(),
            const Divider(height: 32),
            Text('Chọn Ngày Giờ Mới',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildDateSelection(context),
            const Divider(height: 32),
            _buildTimeSlotSelection(),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isRescheduling ? null : _handleReschedule,
                icon: _isRescheduling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle),
                label: Text(
                    _isRescheduling ? 'Đang đổi lịch...' : 'Xác nhận Đổi lịch'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentSummary() {
    final oldDate = DateFormat('dd/MM/yyyy')
        .format(DateTime.parse(widget.appointment['date']));
    final oldTime = widget.appointment['time'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã hẹn: $_appointmentCode',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.red)),
            const SizedBox(height: 8),
            Text('Bác sĩ: BS. $_doctorName',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Lịch hẹn cũ: $oldTime, Ngày $oldDate',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Ngày mới: ${DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_selectedDate)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _selectDate(context),
          icon: const Icon(Icons.calendar_month),
          label: const Text('Chọn Ngày'),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Khung Giờ Khám Mới',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: _slotsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              final err = snapshot.error?.toString() ?? 'Lỗi kết nối';
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Không có lịch trống: $err',
                    style: const TextStyle(color: Colors.red)),
              );
            }

            final data = snapshot.data as Map<String, dynamic>;
            if (data['success'] != true) {
              final errorMsg = data['error'] ?? 'Lỗi kết nối';
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Không có lịch trống: $errorMsg',
                    style: const TextStyle(color: Colors.red)),
              );
            }

            final List<dynamic> slots = (data['data'] is List)
                ? data['data'] as List<dynamic>
                : <dynamic>[];

            if (slots.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                    'Không có khung giờ khám nào được tìm thấy trong ngày này.'),
              );
            }

            return Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: slots.map<Widget>((slot) {
                final time = slot['start_time']?.toString() ?? '';
                // capacity có thể là null hoặc string, xử lý an toàn
                int capacity = 0;
                if (slot['capacity'] is int) {
                  capacity = slot['capacity'] as int;
                } else if (slot['capacity'] != null) {
                  capacity = int.tryParse(slot['capacity'].toString()) ?? 0;
                }

                final isSelected = _selectedTimeSlot == time;

                return ChoiceChip(
                  label: Text('$time (Còn $capacity slot)'),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedTimeSlot = selected ? time : null;
                    });
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
