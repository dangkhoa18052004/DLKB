import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'payment_screen.dart';
import 'select_doctor_screen.dart';

// [Giữ nguyên class Doctor, SelectDoctorScreen]

class BookAppointmentScreen extends StatefulWidget {
  final Doctor doctor;
  final int departmentId;
  final String departmentName;

  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    required this.departmentId,
    required this.departmentName,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final ApiService _apiService = ApiService();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTimeSlot;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  Future<Map<String, dynamic>>? _slotsFuture;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots();
  }

  void _loadAvailableSlots() {
    setState(() {
      _selectedTimeSlot = null;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _slotsFuture = _apiService.getAvailableSlots(widget.doctor.id, dateStr);
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

  Future<void> _handleBooking() async {
    if (_selectedTimeSlot == null) {
      _showSnackBar('Vui lòng chọn khung giờ khám.', Colors.orange);
      return;
    }
    if (_reasonController.text.isEmpty) {
      _showSnackBar('Vui lòng nhập lý do khám.', Colors.orange);
      return;
    }

    setState(() {
      _isBooking = true;
    });

    final reasonText = _reasonController.text.trim();
    final symptomsText = _symptomsController.text.trim();

    final appointmentData = {
      'doctor_id': widget.doctor.id,
      'service_id': 1,
      'appointment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'appointment_time': _selectedTimeSlot,
      'reason': reasonText.isEmpty ? null : reasonText,
      'symptoms': symptomsText.isEmpty ? null : symptomsText,
    };

    appointmentData.removeWhere((key, value) => value == null);

    final result = await _apiService.createAppointment(appointmentData);

    setState(() {
      _isBooking = false;
    });

    if (result['success']) {
      final appointmentCode = result['data']['appointment_code'];
      final appointmentId = result['data']['appointment_id'];
      final requiredPayment = result['data']['required_payment'];

      // CHUYỂN HƯỚNG SANG MÀN HÌNH THANH TOÁN
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              appointmentId: appointmentId,
              appointmentCode: appointmentCode,
              amount: requiredPayment,
            ),
          ),
        );
      }
    } else {
      _showSnackBar(result['error'] ?? 'Đặt lịch thất bại', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // HÀM _showBookingSuccess ĐÃ ĐƯỢC XÓA

  @override
  Widget build(BuildContext context) {
    // [Giữ nguyên phần build]
    return Scaffold(
      appBar: AppBar(
        title: const Text('3. Xác nhận đặt lịch'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDoctorSummary(),
            const Divider(height: 32),
            _buildDateSelection(context),
            const Divider(height: 32),
            _buildTimeSlotSelection(),
            const Divider(height: 32),
            _buildDetailsForm(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isBooking ? null : _handleBooking,
                icon: _isBooking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle),
                label: Text(_isBooking ? 'Đang xử lý...' : 'Xác nhận Đặt lịch'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bác sĩ: BS. ${widget.doctor.fullName}',
                style: Theme.of(context).textTheme.headlineSmall),
            Text('Chuyên khoa: ${widget.departmentName}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Phí tư vấn: ${widget.doctor.consultationFee} ₫',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn Ngày Khám', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_selectedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _selectDate(context),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Đổi Ngày'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSlotSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chọn Giờ Khám', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        FutureBuilder<Map<String, dynamic>>(
          future: _slotsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.data!['success']) {
              final errorMsg = snapshot.data?['error'] ??
                  snapshot.error?.toString() ??
                  'Lỗi kết nối';
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Không có lịch trống: $errorMsg',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final List<dynamic> slots = snapshot.data!['data'];

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
                final time = slot['start_time'] as String;
                final capacity = slot['capacity'] as int;
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

  Widget _buildDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chi tiết Khám bệnh',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextFormField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: 'Lý do khám (Bắt buộc)',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            hintText: 'VD: Khám tổng quát, kiểm tra sức khỏe định kỳ...',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _symptomsController,
          decoration: const InputDecoration(
            labelText: 'Triệu chứng (Nếu có)',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12))),
            hintText: 'VD: Sốt 38 độ, ho, đau họng...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}
