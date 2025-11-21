// doctor_medical_record_form_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'package:intl/intl.dart';

class DoctorMedicalRecordFormScreen extends StatefulWidget {
  final int appointmentId;
  final int patientId;
  final String patientName;

  const DoctorMedicalRecordFormScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorMedicalRecordFormScreen> createState() =>
      _DoctorMedicalRecordFormScreenState();
}

class _DoctorMedicalRecordFormScreenState
    extends State<DoctorMedicalRecordFormScreen> {
  final ApiService _apiService = ApiService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers cho Medical Record
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _treatmentController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Biến cho Prescription
  List<Map<String, dynamic>> _medications = [];

  // Biến cho Follow-up
  DateTime? _nextVisitDate;
  bool _isFollowUp = false;

  bool _isSaving = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _symptomsController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Phương thức thêm thuốc
  void _addMedication() {
    setState(() {
      _medications.add({
        'medication_name': '',
        'dosage': '',
        'frequency': '',
        'duration': '',
        'quantity': 1,
        'instructions': '',
      });
    });
  }

  // Phương thức chọn ngày tái khám
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() {
        _nextVisitDate = picked;
      });
    }
  }

  // === HÀM LƯU CHÍNH ===
  Future<void> _saveMedicalRecord() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. TẠO HỒ SƠ BỆNH ÁN (API POST /doctor/medical-records)
      final recordData = {
        'appointment_id': widget.appointmentId,
        'patient_id': widget.patientId,
        'diagnosis': _diagnosisController.text,
        'symptoms': _symptomsController.text,
        'treatment': _treatmentController.text,
        'notes': _notesController.text,
        'next_visit_date': _nextVisitDate != null
            ? DateFormat('yyyy-MM-dd').format(_nextVisitDate!)
            : null,
        'is_follow_up': _isFollowUp,
      };

      final recordResult =
          await _apiService.post('/doctor/medical-records', recordData);

      if (!recordResult['success']) {
        throw Exception(recordResult['error'] ?? 'Lỗi tạo hồ sơ bệnh án.');
      }

      final medicalRecordId = recordResult['data']['record_id'];

      // 2. KÊ ĐƠN THUỐC (API POST /doctor/prescriptions/bulk)
      if (_medications.isNotEmpty) {
        final prescriptionData = {
          'medical_record_id': medicalRecordId,
          'medications': _medications,
        };

        final prescriptionResult = await _apiService.post(
            '/doctor/prescriptions/bulk', prescriptionData);

        if (!prescriptionResult['success']) {
          // Lỗi kê đơn thuốc là lỗi nhẹ hơn, có thể log và tiếp tục
          print(
              'Cảnh báo: Lỗi khi kê đơn thuốc: ${prescriptionResult['error']}');
        }
      }

      // 3. TẠO NHẮC TÁI KHÁM (API POST /doctor/follow-up-reminders)
      if (_isFollowUp && _nextVisitDate != null) {
        final reminderData = {
          'medical_record_id': medicalRecordId,
          'patient_id': widget.patientId,
          'follow_up_date': DateFormat('yyyy-MM-dd').format(_nextVisitDate!),
          // reminder_date có thể tự động tính ở backend (ví dụ: follow_up_date - 1 ngày)
        };
        final reminderResult =
            await _apiService.post('/doctor/follow-up-reminders', reminderData);

        if (!reminderResult['success']) {
          print(
              'Cảnh báo: Lỗi khi tạo nhắc tái khám: ${reminderResult['error']}');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo Hồ sơ & Kê đơn thành công!')),
      );
      Navigator.of(context).pop(); // Quay lại màn hình chi tiết lịch hẹn
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LỖI: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hồ sơ BN: ${widget.patientName}'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === 1. CHẨN ĐOÁN VÀ ĐIỀU TRỊ ===
              Text('1. Chẩn đoán & Điều trị',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),

              _buildTextInput(_diagnosisController, 'Chẩn đoán chính',
                  required: true, maxLines: 2),
              _buildTextInput(
                  _symptomsController, 'Mô tả triệu chứng (Tóm tắt)',
                  maxLines: 3),
              _buildTextInput(
                  _treatmentController, 'Phương pháp điều trị/Phác đồ',
                  maxLines: 5),
              _buildTextInput(_notesController, 'Ghi chú khác', maxLines: 4),

              const Divider(height: 32),

              // === 2. KÊ ĐƠN THUỐC ===
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('2. Kê Đơn Thuốc',
                      style: Theme.of(context).textTheme.titleLarge),
                  ElevatedButton.icon(
                    onPressed: _addMedication,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm Thuốc'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_medications.isEmpty)
                const Center(child: Text('Chưa có đơn thuốc nào.')),

              ..._medications.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> med = entry.value;
                return _buildMedicationItem(index, med);
              }).toList(),

              const Divider(height: 32),

              // === 3. TÁI KHÁM & NHẮC NHỞ ===
              Text('3. Lịch Tái Khám',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),

              SwitchListTile(
                title: const Text('Cần hẹn Tái khám'),
                value: _isFollowUp,
                onChanged: (bool value) {
                  setState(() {
                    _isFollowUp = value;
                  });
                },
              ),

              if (_isFollowUp)
                ListTile(
                  title: const Text('Ngày dự kiến Tái khám'),
                  subtitle: Text(
                    _nextVisitDate != null
                        ? DateFormat('dd/MM/yyyy').format(_nextVisitDate!)
                        : 'Chưa chọn ngày',
                    style: TextStyle(
                        color: _nextVisitDate == null ? Colors.red : null),
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () => _selectDate(context),
                ),

              const SizedBox(height: 32),

              // === NÚT LƯU ===
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveMedicalRecord,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle),
                  label: Text(
                      _isSaving ? 'Đang lưu...' : 'HOÀN TẤT KHÁM VÀ LƯU HỒ SƠ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInput(TextEditingController controller, String label,
      {bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Vui lòng nhập ${label.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMedicationItem(int index, Map<String, dynamic> med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đơn thuốc #${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _medications.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            TextFormField(
              initialValue: med['medication_name'],
              decoration:
                  const InputDecoration(labelText: 'Tên Thuốc', isDense: true),
              onChanged: (value) => med['medication_name'] = value,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Cần tên thuốc' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: med['dosage'],
                    decoration: const InputDecoration(
                        labelText: 'Liều dùng', isDense: true),
                    onChanged: (value) => med['dosage'] = value,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: med['frequency'],
                    decoration: const InputDecoration(
                        labelText: 'Tần suất', isDense: true),
                    onChanged: (value) => med['frequency'] = value,
                  ),
                ),
              ],
            ),
            TextFormField(
              initialValue: med['instructions'],
              decoration: const InputDecoration(
                  labelText: 'Hướng dẫn sử dụng', isDense: true),
              onChanged: (value) => med['instructions'] = value,
            ),
          ],
        ),
      ),
    );
  }
}
