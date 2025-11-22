import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'package:intl/intl.dart';

class ViewMedicalRecordScreen extends StatefulWidget {
  final int appointmentId;
  const ViewMedicalRecordScreen({super.key, required this.appointmentId});

  @override
  State<ViewMedicalRecordScreen> createState() =>
      _ViewMedicalRecordScreenState();
}

class _ViewMedicalRecordScreenState extends State<ViewMedicalRecordScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _medicalRecord;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMedicalRecord();
  }

  Future<void> _loadMedicalRecord() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result =
          await _apiService.getMedicalRecordByAppointment(widget.appointmentId);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _medicalRecord = result['data']['medical_record'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Không thể tải hồ sơ';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ Bệnh án'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMedicalRecord,
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
                        onPressed: _loadMedicalRecord,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final record = _medicalRecord!;
    final patient = record['patient'];
    final prescriptions = record['prescriptions'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thông tin bệnh nhân
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

          // Chẩn đoán và điều trị
          Text('Chẩn đoán & Điều trị',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            color: Colors.blue.shade50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(Icons.medical_information, 'Chẩn đoán',
                      record['diagnosis'] ?? 'N/A'),
                  _buildDetailRow(
                      Icons.sick, 'Triệu chứng', record['symptoms'] ?? 'N/A'),
                  _buildDetailRow(Icons.healing, 'Phương pháp điều trị',
                      record['treatment'] ?? 'N/A'),
                  _buildDetailRow(
                      Icons.note, 'Ghi chú', record['notes'] ?? 'Không có'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Đơn thuốc
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Đơn thuốc',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Chip(
                label: Text('${prescriptions.length} loại'),
                backgroundColor: Colors.orange.shade100,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (prescriptions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text('Không có đơn thuốc',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              ),
            )
          else
            ...prescriptions.map((med) => _buildMedicationCard(med)).toList(),

          const SizedBox(height: 20),

          // Tái khám
          if (record['is_follow_up'] == true) ...[
            Text('Lịch tái khám',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.event, color: Colors.green.shade700, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ngày tái khám',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          record['next_visit_date'] != null
                              ? DateFormat('dd/MM/yyyy').format(
                                  DateTime.parse(record['next_visit_date']))
                              : 'Chưa xác định',
                          style: TextStyle(
                              fontSize: 16, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Ngày tạo
          Center(
            child: Text(
              'Ngày tạo: ${record['created_at'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(record['created_at'])) : 'N/A'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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

  Widget _buildMedicationCard(Map<String, dynamic> med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.medication, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    med['medication_name'] ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMedInfo(
                      Icons.medication_liquid, 'Liều dùng', med['dosage']),
                ),
                Expanded(
                  child: _buildMedInfo(
                      Icons.schedule, 'Tần suất', med['frequency']),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child:
                      _buildMedInfo(Icons.timer, 'Thời gian', med['duration']),
                ),
                Expanded(
                  child: _buildMedInfo(
                      Icons.inventory, 'Số lượng', med['quantity']?.toString()),
                ),
              ],
            ),
            if (med['instructions'] != null &&
                med['instructions'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        med['instructions'],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedInfo(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            Text(value ?? 'N/A',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
