import 'package:flutter/material.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử thanh toán')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: 8,
          itemBuilder: (context, index) => Card(
            child: ListTile(
              title: Text('Thanh toán #${index + 1}'),
              subtitle:
                  Text('Số tiền: ${(100000 + index * 50000).toString()} ₫'),
              trailing: Text(index.isEven ? 'Hoàn tất' : 'Hủy',
                  style: TextStyle(
                      color: index.isEven ? Colors.green : Colors.red)),
            ),
          ),
        ),
      ),
    );
  }
}
