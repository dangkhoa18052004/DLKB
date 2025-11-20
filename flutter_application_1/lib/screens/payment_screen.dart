import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart'; // ← THÊM IMPORT
import '../../services/api_service.dart';
import 'home_screen.dart';

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
  String? _qrCodeUrl; // ← THÊM BIẾN LƯU QR CODE
  String? _paymentUrl; // ← THÊM BIẾN LƯU PAYMENT URL

  @override
  void initState() {
    super.initState();
    _createPaymentRecord();
  }

  Future<void> _createPaymentRecord() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

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

  Future<void> _initiateMomoPayment() async {
    if (_paymentId == null || _paymentCode == null) {
      setState(() {
        _errorMessage = 'Lỗi: Không tìm thấy ID thanh toán.';
      });
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
      final qrUrl = result['data']['qr_code_url'];

      setState(() {
        _paymentUrl = payUrl;
        _qrCodeUrl = qrUrl;
      });

      // ✅ HIỂN thị QR CODE DIALOG
      if (mounted) {
        _showQRCodeDialog(qrUrl, payUrl);
      }
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Khởi tạo MoMo thất bại.';
      });
    }
  }

  // ✅ DIALOG HIỂN THỊ QR CODE
  void _showQRCodeDialog(String qrUrl, String payUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo MoMo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade500,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thanh toán MoMo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quét mã QR để thanh toán',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // ✅ QR CODE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: QrImageView(
                    data: qrUrl,
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Mã thanh toán: $_paymentCode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Nút hành động
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Nút Mở link (nếu có trình duyệt)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(payUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Không thể mở link')),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Mở link'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Nút Tiếp tục
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Chuyển sang màn hình check status
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentStatusScreen(
                                paymentCode: _paymentCode!,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Đã thanh toán'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mã hẹn: ${widget.appointmentCode}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                    Text(
                      _paymentCode != null
                          ? 'Trạng thái: Đang chờ thanh toán'
                          : 'Trạng thái: Đang tạo giao dịch...',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chọn Phương thức Thanh toán',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            _buildPaymentButton(
              'Thanh toán bằng MoMo',
              Colors.pink.shade500,
              _initiateMomoPayment,
            ),
            const SizedBox(height: 32),
            if (_isProcessing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Đang xử lý...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton(String title, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: OutlinedButton(
        onPressed: _isProcessing || _paymentId == null ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              color: color,
              margin: const EdgeInsets.only(right: 10),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// MÀN HÌNH KIỂM TRA TRẠNG THÁI
// ============================================
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
  int _checkCount = 0;

  @override
  void initState() {
    super.initState();
    _startStatusCheck();
  }

  void _startStatusCheck() async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      final result = await _apiService.checkPaymentStatus(widget.paymentCode);

      if (result['success']) {
        final status = result['data']['payment_status'];

        if (status == 'completed') {
          setState(() {
            _statusMessage =
                'Thanh toán thành công! Lịch hẹn đã được xác nhận.';
            _isChecking = false;
          });

          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false,
            );
          }
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
          _checkCount = i + 1;
          _statusMessage = 'Đang chờ xác nhận... ($_checkCount/10)';
        });
      }
    }

    if (mounted && _isChecking) {
      setState(() {
        _statusMessage =
            'Không thể xác nhận trạng thái. Vui lòng kiểm tra lịch hẹn của bạn sau.';
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
              if (!_isChecking)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  child: const Text('Quay về Trang chủ'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
