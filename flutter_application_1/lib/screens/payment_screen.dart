import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'home_screen.dart';

class PaymentScreen extends StatefulWidget {
  final int appointmentId;
  final String appointmentCode;
  final double amount;
  final int paymentId;
  final String doctorName;

  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentCode,
    required this.amount,
    required this.paymentId,
    required this.doctorName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  bool _isInitiatingMomo = false;
  String _paymentStatus = 'pending';
  String? _momoPaymentUrl;

  final formatCurrency = NumberFormat('#,##0', 'vi_VN');

  // Các field để lưu thông tin giao dịch
  String? _paymentCode;
  int? _currentPaymentId; // ✅ Lưu payment ID hiện tại
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Bắt đầu tạo bản ghi thanh toán ngay khi vào màn hình
    _createPaymentRecord();
  }

  // Hàm tạo bản ghi thanh toán ban đầu (từ code cũ của bạn)
  Future<void> _createPaymentRecord() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final result = await _apiService.createPaymentRecord(
      widget.appointmentId,
      widget.amount, // Sử dụng double amount
      'momo',
    );

    if (result['success']) {
      setState(() {
        // ✅ CẬP NHẬT: Lưu payment_id mới từ response
        _currentPaymentId = result['data']['payment_id'];
        _paymentCode = result['data']['payment_code'];
        _isProcessing = false;
        // Kiểm tra trạng thái lần đầu
        _checkInitialPaymentStatus();
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Không thể tạo bản ghi thanh toán.';
        _isProcessing = false;
      });
    }
  }

  Future<void> _checkInitialPaymentStatus() async {
    if (_paymentCode == null) return;

    setState(() => _isProcessing = true);

    final result = await _apiService.checkPaymentStatus(_paymentCode!);

    if (result['success']) {
      setState(() {
        _paymentStatus = result['data']['payment_status'] ?? 'pending';
        _isProcessing = false;
      });
    } else {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _initiateMomoPayment() async {
    if (_isInitiatingMomo ||
        _paymentStatus == 'completed' ||
        (_currentPaymentId == null && widget.paymentId == 0)) return;

    setState(() {
      _isInitiatingMomo = true;
      _errorMessage = null;
    });

    // Gọi API để lấy URL thanh toán MoMo
    // ✅ FIX: Sử dụng _currentPaymentId (payment ID mới) thay vì widget.paymentId
    final paymentIdToUse = _currentPaymentId ?? widget.paymentId;
    final result = await _apiService.initiateMomoPayment(paymentIdToUse);

    if (result['success'] && mounted) {
      final payUrl = result['data']['payment_url'];
      final qrUrl = result['data']['qr_code_url'];

      setState(() {
        _isInitiatingMomo = false;
        _paymentStatus = 'processing';
      });

      // ✅ Mở dialog hiển thị QR code
      if (mounted) {
        _showQRCodeDialog(qrUrl, payUrl);
      }
    } else if (mounted) {
      setState(() {
        _isInitiatingMomo = false;
        _paymentStatus = 'failed';
        _errorMessage = result['error'] ?? 'Khởi tạo MoMo thất bại';
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
                  'Quét mã QR để thanh toán (Mã: ${widget.appointmentCode})',
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
                    size: 200, // Kích thước nhỏ hơn để vừa với màn hình
                    backgroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // Nút hành động
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Nút Mở link
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchUrl(payUrl),
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Mở MoMo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Nút Tiếp tục (Chuyển sang màn hình kiểm tra trạng thái)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // Đóng dialog
                          // Chuyển sang màn hình check status
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentStatusScreen(
                                paymentCode:
                                    _paymentCode ?? widget.appointmentCode,
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Không thể mở cổng thanh toán MoMo.', Colors.red);
    }
  }

  Future<void> _checkStatusManually() async {
    await _checkInitialPaymentStatus();
    if (_paymentStatus == 'completed') {
      _showSnackBar(
          'Thanh toán thành công! Lịch hẹn đã được xác nhận.', Colors.green);
      // Điều hướng đến màn hình trạng thái cuối cùng
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => PaymentStatusScreen(
                  paymentCode: _paymentCode ?? widget.appointmentCode)),
          (Route<dynamic> route) => false,
        );
      }
    } else if (_paymentStatus == 'failed') {
      _showSnackBar('Thanh toán thất bại. Vui lòng thử lại.', Colors.red);
    } else {
      _showSnackBar('Trạng thái vẫn đang chờ xử lý.', Colors.orange);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatAmount(double amount) {
    return '${NumberFormat('#,##0', 'vi_VN').format(amount)} ₫';
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
                color: isAmount ? Colors.red.shade700 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('4. Thanh toán Lịch hẹn'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị loading khi đang tạo bản ghi thanh toán
            if (_isProcessing && _paymentCode == null)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Đang tạo bản ghi thanh toán...',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else ...[
              _buildPaymentSummary(),
              const Divider(height: 32),
              _buildPaymentStatusIndicator(),
              const Divider(height: 32),
              _buildPaymentOptions(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin Thanh toán',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Mã lịch hẹn', widget.appointmentCode),
            _buildDetailRow('Bác sĩ', widget.doctorName),
            _buildDetailRow(
                'Số tiền cần thanh toán', _formatAmount(widget.amount),
                isAmount: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusIndicator() {
    Color color;
    String text;
    IconData icon;

    switch (_paymentStatus) {
      case 'completed':
        color = Colors.green;
        text = 'Đã thanh toán thành công';
        icon = Icons.check_circle;
        break;
      case 'processing':
        color = Colors.orange;
        text = 'Đang chờ xác nhận từ cổng thanh toán';
        icon = Icons.access_time;
        break;
      case 'failed':
        color = Colors.red;
        text = 'Thanh toán thất bại. Vui lòng thử lại.';
        icon = Icons.error;
        break;
      case 'pending':
      default:
        color = Colors.grey;
        text = 'Chờ thanh toán';
        icon = Icons.credit_card;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trạng thái Thanh toán',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
        ),

        // Nút kiểm tra trạng thái thủ công (chỉ khi đang processing/pending)
        if (_paymentStatus != 'completed')
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _checkStatusManually,
                icon: const Icon(Icons.refresh),
                label: const Text('Kiểm tra trạng thái'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentOptions() {
    // Nếu đã thanh toán, không hiển thị tùy chọn
    if (_paymentStatus == 'completed') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chọn Phương thức Thanh toán',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // 1. THANH TOÁN BẰNG MOMO (Nút đẹp hơn)
        _buildMomoButton(),

        const SizedBox(height: 16),

        // 2. THANH TOÁN TẠI QUẦY
        _buildQueuePaymentCard(),
      ],
    );
  }

  Widget _buildMomoButton() {
    // Màu hồng đậm của MoMo
    const momoColor = Color(0xFFaf2073);

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _isInitiatingMomo ||
                _isProcessing ||
                (_currentPaymentId == null && widget.paymentId == 0)
            ? null
            : _initiateMomoPayment,
        icon: _isInitiatingMomo
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.payments_outlined, size: 24),
        label: Text(
          _isInitiatingMomo ? 'Đang kết nối MoMo...' : 'Thanh toán bằng MoMo',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: momoColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildQueuePaymentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showSnackBar(
              'Vui lòng đến quầy thanh toán của bệnh viện trong vòng 24 giờ.',
              Colors.blue);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.person_pin, color: Colors.grey.shade600, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thanh toán tại Quầy',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Thanh toán bằng tiền mặt hoặc thẻ tại quầy y tế.',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
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
