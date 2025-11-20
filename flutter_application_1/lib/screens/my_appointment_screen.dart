import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'reschedule_appointment_screen.dart';
// THÊM: Import màn hình FeedbackReviewScreen
import 'feedback_review_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<dynamic> _allAppointments = [];
  List<dynamic> _pendingAppointments = [];
  List<dynamic> _confirmedAppointments = [];
  List<dynamic> _completedAppointments = [];
  List<dynamic> _cancelledAppointments = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getMyAppointments(); //

      if (result['success']) {
        final List<dynamic> appointments = result['data'] ?? [];

        setState(() {
          _allAppointments = appointments;
          _pendingAppointments = appointments
              .where((a) =>
                  (a['status'] ?? '').toString().toLowerCase() == 'pending')
              .toList();
          _confirmedAppointments = appointments.where((a) {
            final s = (a['status'] ?? '').toString().toLowerCase();
            return s == 'confirmed' || s == 'checked_in';
          }).toList();
          _completedAppointments = appointments
              .where((a) =>
                  (a['status'] ?? '').toString().toLowerCase() == 'completed')
              .toList();
          _cancelledAppointments = appointments.where((a) {
            final s = (a['status'] ?? '').toString().toLowerCase();
            return s == 'cancelled' || s == 'no_show';
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Không thể tải danh sách lịch hẹn';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi kết nối: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bỏ AppBar ở đây vì nó đã được chuyển sang HomeScreen
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Text('Tất cả'),
                    if (_allAppointments.isNotEmpty)
                      _buildBadge(
                          _allAppointments.length, Colors.grey.shade400),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text('Chờ duyệt'),
                    if (_pendingAppointments.isNotEmpty)
                      _buildBadge(_pendingAppointments.length, Colors.orange),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Text('Đã xác nhận'),
                    if (_confirmedAppointments.isNotEmpty)
                      _buildBadge(_confirmedAppointments.length, Colors.green),
                  ],
                ),
              ),
              const Tab(text: 'Hoàn thành'),
              const Tab(text: 'Đã hủy'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : RefreshIndicator(
                        onRefresh: _loadAppointments,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAppointmentList(_allAppointments),
                            _buildAppointmentList(_pendingAppointments),
                            _buildAppointmentList(_confirmedAppointments),
                            _buildAppointmentList(_completedAppointments),
                            _buildAppointmentList(_cancelledAppointments),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentList(List<dynamic> appointments) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Không có lịch hẹn nào',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildAppointmentCard(appointment);
      },
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final String status =
        (appointment['status'] ?? '').toString().toLowerCase();
    final String code = appointment['code'] ?? 'N/A';
    final String date = appointment['date'] ?? '';
    final String time = appointment['time'] ?? '';
    final String doctorName = appointment['doctor_name'] ?? 'N/A';
    final int? appointmentId =
        appointment['id']; // Lấy ID (có thể null nếu data lỗi)

    Color statusColor = _getStatusColor(status);
    String statusText = _getStatusText(status);
    IconData statusIcon = _getStatusIcon(status);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAppointmentDetail(appointment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Code và Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Doctor Info
              Row(
                children: [
                  Icon(Icons.person, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BS. $doctorName',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date & Time
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time,
                      color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (status == 'pending' || status == 'confirmed') ...[
                      // HỦY LỊCH
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: appointmentId != null
                              ? () => _cancelAppointment(appointmentId, code)
                              : null,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Hủy lịch'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ĐỔI LỊCH
                      Expanded(
                        child: ElevatedButton.icon(
                          // SỬA LỖI: Bọc hàm gọi bên trong hàm ẩn danh
                          onPressed: appointmentId != null
                              ? () => _rescheduleAppointment(appointment)
                              : null,
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label: const Text('Đổi lịch'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],

                    // ĐÁNH GIÁ (CHỈ HIỆN KHI status = 'completed')
                    if (status == 'completed')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: appointmentId != null
                              ? () => _navigateToFeedback(
                                  appointmentId, code, doctorName)
                              : null,
                          icon: const Icon(Icons.star, size: 18),
                          label: const Text('Đánh giá'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // THÊM: Hàm điều hướng sang màn hình đánh giá
  void _navigateToFeedback(
      int appointmentId, String appointmentCode, String doctorName) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackReviewScreen(
          appointmentId: appointmentId,
          appointmentCode: appointmentCode,
          doctorName: doctorName,
        ),
      ),
    );

    // Nếu quay lại từ màn hình đánh giá và có cập nhật, reload danh sách
    if (result == true) {
      _loadAppointments();
    }
  }

  // (Giữ nguyên các hàm _getStatusColor, _getStatusText, _getStatusIcon, _formatDate, _showAppointmentDetail, _buildDetailRow)
  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
      case 'checked_in':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
      case 'no_show':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
        return 'Chờ duyệt';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'checked_in':
        return 'Đã check-in';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      case 'no_show':
        return 'Không đến';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
        return Icons.pending_outlined;
      case 'confirmed':
      case 'checked_in':
        return Icons.check_circle_outline;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
      case 'no_show':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd/MM/yyyy', 'vi').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showAppointmentDetail(Map<String, dynamic> appointment) {
    // Logic hiển thị chi tiết lịch hẹn (giữ nguyên)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chi tiết lịch hẹn',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 24),
              _buildDetailRow('Mã lịch hẹn', appointment['code'] ?? 'N/A'),
              _buildDetailRow(
                  'Bác sĩ', 'BS. ${appointment['doctor_name'] ?? 'N/A'}'),
              _buildDetailRow(
                  'Ngày khám', _formatDate(appointment['date'] ?? '')),
              _buildDetailRow('Giờ khám', appointment['time'] ?? 'N/A'),
              _buildDetailRow(
                  'Trạng thái', _getStatusText(appointment['status'])),
              const SizedBox(height: 20),
              // THÊM NÚT ĐÁNH GIÁ TRONG DETAIL NẾU ĐÃ HOÀN THÀNH
              if ((appointment['status'] ?? '').toString().toLowerCase() ==
                  'completed')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Đóng detail sheet
                        _navigateToFeedback(
                            appointment['id']!,
                            appointment['code'] ?? 'N/A',
                            appointment['doctor_name'] ?? 'N/A');
                      },
                      icon: const Icon(Icons.star, size: 20),
                      label: const Text('Gửi Đánh giá',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAppointment(int appointmentId, String code) async {
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy lịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn hủy lịch hẹn $code?'),
            const SizedBox(height: 10),
            TextField(
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(
                labelText: 'Lý do hủy (Không bắt buộc)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang xử lý hủy lịch...')),
      );

      final result = await _apiService.cancelAppointment(
          appointmentId, reason ?? 'Cancelled by patient via app'); //

      if (result['success'] && mounted) {
        _loadAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Hủy lịch thành công'),
              backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Hủy lịch thất bại: ${result['error'] ?? 'Lỗi không xác định'}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _rescheduleAppointment(Map<String, dynamic> appointment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RescheduleAppointmentScreen(appointment: appointment),
      ),
    );

    if (result == true) {
      _loadAppointments();
    }
  }
}
