import 'package:flutter/material.dart';

class AppointmentManagementScreen extends StatelessWidget {
  const AppointmentManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý lịch khám')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Danh sách lịch hẹn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: 12,
                itemBuilder: (context, index) => Card(
                  child: ListTile(
                    title: Text('Mã hẹn: APPT-${1000 + index}'),
                    subtitle:
                        Text('Bệnh nhân #${index + 1} • 05/12/2025 10:00'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {},
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'view', child: Text('Xem')),
                        const PopupMenuItem(
                            value: 'reschedule', child: Text('Dời lịch')),
                        const PopupMenuItem(
                            value: 'cancel', child: Text('Hủy')),
                      ],
                    ),
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
