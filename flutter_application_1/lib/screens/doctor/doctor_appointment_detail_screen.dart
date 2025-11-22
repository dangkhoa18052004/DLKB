// doctor_appointment_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'doctor_medical_record_form_screen.dart';
import 'view_medical_record_screen.dart';

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
      final result =
          await _apiService.getDoctorAppointmentDetail(widget.appointmentId);

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

    final status = _appointmentDetail!['status'];

    // ✅ NẾU ĐÃ COMPLETED → Mở màn hình xem hồ sơ bệnh án
    if (status == 'completed') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ViewMedicalRecordScreen(appointmentId: widget.appointmentId),
        ),
      );
      return;
    }

    // ✅ CHỈ CHO TẠO KHI CHECKED_IN
    if (status != 'checked_in') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ có thể tạo Hồ sơ khi bệnh nhân đã Check-in.'),
        ),
      );
      return;
    }

    // Điều hướng đến màn hình tạo hồ sơ
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorMedicalRecordFormScreen(
          appointmentId: widget.appointmentId,
          patientId: _appointmentDetail!['patient']['id'],
          patientName: _appointmentDetail!['patient']['full_name'],
        ),
      ),
    ).then((_) => _loadAppointmentDetail());
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Lỗi: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loadAppointmentDetail,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final appt = _appointmentDetail!;
    final patient = appt['patient'];
    final status = appt['status'];

    Color statusColor;
    switch (status) {
      case 'checked_in':
        statusColor = Colors.teal;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Lịch hẹn
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: statusColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        appt['appointment_code'] ?? 'N/A',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${appt['appointment_date']} lúc ${appt['appointment_time']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Thông tin Bệnh nhân
          Text('Thông tin Bệnh nhân',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                      Icons.person, 'Họ tên', patient['full_name'] ?? 'N/A'),
                  _buildDetailRow(
                      Icons.vpn_key, 'Mã BN', patient['patient_code'] ?? 'N/A'),
                  _buildDetailRow(
                      Icons.phone, 'SĐT', patient['phone'] ?? 'N/A'),
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
          const SizedBox(height: 20),

          // Chi tiết Khám bệnh
          Text('Nội dung Khám',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              icon: Icon(status == 'completed'
                  ? Icons.visibility
                  : Icons.medical_services),
              label: Text(status == 'completed'
                  ? 'XEM HỒ SƠ ĐÃ TẠO'
                  : 'TẠO HỒ SƠ BỆNH ÁN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'completed'
                    ? Colors.green.shade700
                    : Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
