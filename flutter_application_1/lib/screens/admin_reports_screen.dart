import 'package:flutter/material.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo & Thống kê')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn báo cáo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.pie_chart),
              label: const Text('Báo cáo lượt khám theo ngày'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.bar_chart),
              label: const Text('Báo cáo doanh thu'),
            ),
            const SizedBox(height: 20),
            const Expanded(
                child:
                    Center(child: Text('Biểu đồ/Thống kê sẽ hiển thị ở đây'))),
          ],
        ),
      ),
    );
  }
}
