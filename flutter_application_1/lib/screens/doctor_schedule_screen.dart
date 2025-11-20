import 'package:flutter/material.dart';

class DoctorScheduleScreen extends StatelessWidget {
  const DoctorScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch khám của Bác sĩ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lịch tuần',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (context, index) => Card(
                  child: ListTile(
                    title: Text('Thứ ${index + 1}'),
                    subtitle: const Text('08:00 - 12:00 | 14:00 - 17:00'),
                    trailing: ElevatedButton(
                        onPressed: () {}, child: const Text('Chỉnh sửa')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
