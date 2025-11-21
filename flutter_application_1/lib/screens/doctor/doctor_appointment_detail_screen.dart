// doctor_appointment_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'doctor_medical_record_form_screen.dart';

class DoctorAppointmentDetailScreen extends StatefulWidget {
  final int appointmentId;
  const DoctorAppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  State<DoctorAppointmentDetailScreen> createState() =>
      _DoctorAppointmentDetailScreenState();
}

class _DoctorAppointmentDetailScreenState
    extends State<DoctorAppointmentDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _appointmentDetail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAppointmentDetail();
  }

  Future<void> _loadAppointmentDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Gọi API GET /doctor/appointments/<id>
      final result =
          await _apiService.getAppointmentDetail(widget.appointmentId);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _appointmentDetail = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Không thể tải chi tiết lịch hẹn';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToMedicalRecordForm() {
    if (_appointmentDetail == null) return;

    // Đảm bảo chỉ tạo hồ sơ khi đã check-in
    final status = _appointmentDetail!['status'];
    if (status != 'checked_in') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chỉ có thể tạo Hồ sơ khi bệnh nhân đã Check-in.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorMedicalRecordFormScreen(
          appointmentId: widget.appointmentId,
          patientId: _appointmentDetail!['patient']['id'],
          patientName: _appointmentDetail!['patient']['full_name'],
          // Có thể truyền thêm dữ liệu khác như symptoms, reason
        ),
      ),
    ).then((_) =>
        _loadAppointmentDetail()); // Tải lại chi tiết sau khi quay về (để cập nhật status)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Lịch hẹn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointmentDetail,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Lỗi: $_errorMessage'))
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final appt = _appointmentDetail!;
    final patient = appt['patient'];
    final status = appt['status'];

    final Color statusColor =
        status == 'checked_in' ? Colors.teal : Colors.blueGrey;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Lịch hẹn
          Card(
            color: statusColor.withOpacity(0.1),
            child: ListTile(
              title: Text(appt['appointment_code'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(
                  '${appt['appointment_date']} lúc ${appt['appointment_time']}'),
              trailing: Text(status.toUpperCase(),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),

          // Thông tin Bệnh nhân
          Text('Thông tin Bệnh nhân',
              style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(Icons.person, 'Họ tên', patient['full_name']),
                  _buildDetailRow(
                      Icons.vpn_key, 'Mã BN', patient['patient_code']),
                  _buildDetailRow(Icons.phone, 'SĐT', patient['phone']),
                  _buildDetailRow(Icons.calendar_today, 'Ngày sinh',
                      patient['date_of_birth'] ?? 'N/A'),
                  _buildDetailRow(
                      Icons.wc, 'Giới tính', patient['gender'] ?? 'N/A'),
                  _buildDetailRow(Icons.bloodtype, 'Nhóm máu',
                      patient['blood_type'] ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Chi tiết Khám bệnh
          Text('Nội dung Khám', style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                      Icons.info, 'Lý do khám', appt['reason'] ?? 'Không rõ'),
                  _buildDetailRow(Icons.sick, 'Triệu chứng',
                      appt['symptoms'] ?? 'Không rõ'),
                  _buildDetailRow(
                      Icons.note_alt, 'Ghi chú', appt['notes'] ?? 'Không có'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Nút hành động chính
          Center(
            child: ElevatedButton.icon(
              onPressed: _navigateToMedicalRecordForm,
              icon: const Icon(Icons.add_box),
              label: Text(status == 'completed'
                  ? 'XEM HỒ SƠ ĐÃ TẠO'
                  : 'TẠO HỒ SƠ BỆNH ÁN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'completed'
                    ? Colors.green.shade700
                    : Colors.blue.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 3,
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
