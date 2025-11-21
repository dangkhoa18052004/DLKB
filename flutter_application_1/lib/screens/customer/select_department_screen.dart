import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'select_doctor_screen.dart';

class Department {
  final int id;
  final String name;
  final String description;

  Department.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        description = json['description'];
}

class SelectDepartmentScreen extends StatelessWidget {
  const SelectDepartmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1. Chọn Chuyên khoa'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getDepartments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.data!['success']) {
            return Center(
              child: Text(
                  'Lỗi tải dữ liệu: ${snapshot.data?['error'] ?? snapshot.error}'),
            );
          }

          final List<Department> departments = (snapshot.data!['data'] as List)
              .map((json) => Department.fromJson(json))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: departments.length,
            itemBuilder: (context, index) {
              final dept = departments[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: Icon(Icons.medication_liquid, color: Colors.white),
                  ),
                  title: Text(
                    dept.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    dept.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectDoctorScreen(
                          departmentId: dept.id,
                          departmentName: dept.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
