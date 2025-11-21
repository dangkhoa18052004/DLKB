import 'package:flutter/material.dart';
import '../../services/api_service.dart';
// Sử dụng prefix để tham chiếu BookAppointmentScreen (Đã đúng)
import 'book_appointment_screen.dart' as BAS;
// THAY THẾ: Import model Doctor chung (Đã đúng)
import '../../models/doctor.dart';

// XÓA ĐỊNH NGHĨA CLASS DOCTOR NẾU NÓ VẪN TỒN TẠI TRONG FILE NÀY

class SelectDoctorScreen extends StatelessWidget {
  final int departmentId;
  final String departmentName;
  const SelectDoctorScreen(
      {super.key, required this.departmentId, required this.departmentName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('2. Chọn Bác sĩ (${departmentName})'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getDoctors(departmentId: departmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.data!['success']) {
            return Center(
              child: Text(
                  'Lỗi tải danh sách bác sĩ: ${snapshot.data?['error'] ?? snapshot.error}'),
            );
          }

          final List<Doctor> doctors = (snapshot.data!['data'] as List)
              // SỬ DỤNG Doctor.fromJson từ model chung
              .map((json) => Doctor.fromJson(json))
              .toList();

          if (doctors.isEmpty) {
            return const Center(
                child: Text(
                    'Không có bác sĩ nào đang hoạt động trong chuyên khoa này.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: ClipOval(
                      child: Image.network(
                        'https://via.placeholder.com/100',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person, size: 28),
                      ),
                    ),
                  ),
                  title: Text(
                    'BS. ${doctor.fullName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor.specialization),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(
                              '${doctor.rating} | Phí: ${doctor.consultationFee} ₫'),
                        ],
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BAS.BookAppointmentScreen(
                            // SỬ DỤNG PREFIX
                            // TRUYỀN ĐÚNG OBJECT DOCTOR TỪ MODEL CHUNG
                            doctor: doctor,
                            departmentId: departmentId,
                            departmentName: departmentName,
                          ),
                        ),
                      );
                    },
                    child: const Text('Đặt lịch'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
