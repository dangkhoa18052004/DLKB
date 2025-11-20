import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
// Removed unused imports: provider and auth_service

class PaymentScreen extends StatefulWidget {
  final int appointmentId;
  final String appointmentCode;
  final String amount;

  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentCode,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  int? _paymentId;
  String? _paymentCode;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Bắt đầu bằng việc tạo bản ghi thanh toán nếu chưa có
    _createPaymentRecord();
  }

  // Bước 1: Tạo bản ghi Payment Pending (Endpoint: /api/payment/create)
  Future<void> _createPaymentRecord() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Lỗi có thể xảy ra ở đây nếu bạn chưa tạo Service ID 1 trong DB
    final result = await _apiService.createPaymentRecord(
      widget.appointmentId,
      double.parse(widget.amount),
      'momo',
    );

    if (result['success']) {
      setState(() {
        _paymentId = result['data']['payment_id'];
        _paymentCode = result['data']['payment_code'];
        _isProcessing = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Không thể tạo bản ghi thanh toán.';
        _isProcessing = false;
      });
    }
  }

  // Bước 2 & 3: Khởi tạo và mở cổng MoMo (Endpoint: /api/payment/momo/create)
  Future<void> _initiateMomoPayment() async {
    if (_paymentId == null || _paymentCode == null) {
      _errorMessage = 'Lỗi: Không tìm thấy ID thanh toán.';
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final result = await _apiService.initiateMomoPayment(_paymentId!);

    setState(() {
      _isProcessing = false;
    });

    if (result['success']) {
      final payUrl = result['data']['payment_url'];
      if (await canLaunchUrl(Uri.parse(payUrl))) {
        await launchUrl(Uri.parse(payUrl),
            mode: LaunchMode.externalApplication);
      } else {
        _errorMessage = 'Không thể mở cổng thanh toán MoMo.';
        return;
      }

      // Chuyển sang màn hình chờ xác nhận ngay sau khi mở trình duyệt
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PaymentStatusScreen(paymentCode: _paymentCode!)));
      }
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Khởi tạo MoMo thất bại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán Khám bệnh'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã hẹn: ${widget.appointmentCode}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Dịch vụ: Khám chuyên khoa (Giả định)'),
                    const Divider(),
                    Text(
                      'Tổng cộng: ${widget.amount} ₫',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.red),
                    ),
                    const Text('Trạng thái: Đang chờ thanh toán',
                        style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Chọn Phương thức Thanh toán',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Text(_errorMessage!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Nút Thanh toán MoMo
            _buildPaymentButton(
              'Thanh toán bằng MoMo',
              Colors.pink.shade500,
              _initiateMomoPayment,
            ),

            const SizedBox(height: 32),
            if (_isProcessing || _paymentId == null)
              const Center(
                  child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Đang tải thông tin giao dịch...')
                ],
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton(String title, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: OutlinedButton(
        // Vô hiệu hóa nút nếu đang xử lý hoặc chưa có ID thanh toán
        onPressed: _isProcessing || _paymentId == null ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: BorderSide(color: color, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 30,
                height: 30,
                color: color,
                margin: const EdgeInsets.only(right: 10)),
            Text(
              title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// Màn hình chờ kiểm tra trạng thái thanh toán
class PaymentStatusScreen extends StatefulWidget {
  final String paymentCode;
  const PaymentStatusScreen({super.key, required this.paymentCode});

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  final ApiService _apiService = ApiService();
  String _statusMessage = 'Đang chờ xác nhận thanh toán...';
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _startStatusCheck();
  }

  // Hàm kiểm tra trạng thái lặp lại
  void _startStatusCheck() async {
    // Lặp lại việc kiểm tra trạng thái 5 lần, mỗi lần 5 giây
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(seconds: 5));

      // Gọi API Flask để check trạng thái Payment trong DB
      final result = await _apiService.checkPaymentStatus(widget.paymentCode);

      if (result['success']) {
        final status = result['data']['payment_status'];
        if (status == 'completed') {
          setState(() {
            _statusMessage =
                'Thanh toán thành công! Lịch hẹn đã được xác nhận.';
            _isChecking = false;
          });
          return;
        } else if (status == 'failed') {
          setState(() {
            _statusMessage = 'Thanh toán thất bại. Vui lòng thử lại.';
            _isChecking = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'Đang chờ xác nhận... Lần ${i + 1}/5';
        });
      }
    }

    // Nếu hết 5 lần kiểm tra mà vẫn chưa completed
    if (mounted && _isChecking) {
      setState(() {
        _statusMessage =
            'Không thể xác nhận trạng thái. Vui lòng kiểm tra lịch hẹn của bạn.';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = _statusMessage.contains('thành công');
    final bool isError = _statusMessage.contains('thất bại') ||
        _statusMessage.contains('Không thể xác nhận');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạng thái Thanh toán'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isChecking
                  ? const CircularProgressIndicator()
                  : Icon(
                      isSuccess
                          ? Icons.check_circle_outline
                          : isError
                              ? Icons.error_outline
                              : Icons.info_outline,
                      color: isSuccess
                          ? Colors.green
                          : isError
                              ? Colors.red
                              : Colors.blue,
                      size: 80,
                    ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Quay về màn hình chính
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text('Quay về Trang chủ'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
