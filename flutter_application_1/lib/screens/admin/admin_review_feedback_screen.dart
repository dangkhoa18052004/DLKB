// admin_review_feedback_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminReviewFeedbackScreen extends StatefulWidget {
  const AdminReviewFeedbackScreen({super.key});

  @override
  State<AdminReviewFeedbackScreen> createState() =>
      _AdminReviewFeedbackScreenState();
}

class _AdminReviewFeedbackScreenState extends State<AdminReviewFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đánh giá & Phản hồi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Đánh giá (Reviews)', icon: Icon(Icons.star_half)),
            Tab(text: 'Phản hồi (Feedback)', icon: Icon(Icons.comment)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ReviewListView(),
          _FeedbackListView(),
        ],
      ),
    );
  }
}

// ===================================
// === Sub-Widget: Review List View ===
// ===================================

class _ReviewListView extends StatefulWidget {
  const _ReviewListView();

  @override
  State<_ReviewListView> createState() => _ReviewListViewState();
}

class _ReviewListViewState extends State<_ReviewListView> {
  final ApiService _apiService = ApiService();
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  bool? _isApprovedFilter; // Filter: null (all), true, false

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews({int page = 1}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getAdminReviews(
      page: page,
      perPage: 20,
      isApproved: _isApprovedFilter,
    );

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _reviews = result['data']['reviews'] ?? [];
        _currentPage = result['data']['current_page'] ?? 1;
        _totalPages = result['data']['pages'] ?? 1;
        _totalItems = result['data']['total'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Lỗi không xác định.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReviewAction(
      int reviewId, String action, int index) async {
    String message = '';
    Map<String, dynamic> result;

    if (action == 'approve') {
      result = await _apiService.approveReview(reviewId);
      message = 'Đã duyệt đánh giá.';
    } else if (action == 'delete') {
      result = await _apiService.deleteReview(reviewId);
      message = 'Đã xóa đánh giá.';
    } else {
      return;
    }

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      // Tải lại trang hiện tại để cập nhật danh sách
      _loadReviews(page: _currentPage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Thất bại: ${result['error'] ?? 'Lỗi không xác định'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        _buildReviewFilterBar(),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text('Lỗi: $_errorMessage'))
                  : _reviews.isEmpty
                      ? const Center(child: Text('Không có đánh giá nào.'))
                      : _buildReviewList(),
        ),
        if (!_isLoading && _totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildReviewFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: DropdownButton<bool?>(
        hint: const Text('Trạng thái duyệt'),
        value: _isApprovedFilter,
        items: const [
          DropdownMenuItem<bool?>(
            value: null,
            child: Text('Tất cả'),
          ),
          DropdownMenuItem<bool>(
            value: false,
            child: Text('Chưa duyệt (PENDING)'),
          ),
          DropdownMenuItem<bool>(
            value: true,
            child: Text('Đã duyệt (APPROVED)'),
          ),
        ],
        onChanged: (bool? newValue) {
          setState(() {
            _isApprovedFilter = newValue;
          });
          _loadReviews();
        },
      ),
    );
  }

  Widget _buildReviewList() {
    return ListView.builder(
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        final isApproved = review['is_approved'] as bool;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isApproved ? null : Colors.yellow.shade50,
          child: ListTile(
            isThreeLine: true,
            leading: Icon(Icons.star,
                color: isApproved ? Colors.amber : Colors.grey),
            title: Text(
              '${review['patient_name']} (BS. ${review['doctor_name']})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating Bar mô phỏng
                Row(
                  children: [
                    const Text('Rating: ', style: TextStyle(fontSize: 12)),
                    ...List.generate(5, (i) {
                      return Icon(
                        i < review['rating'] ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text('(${review['rating']} sao)',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                Text(
                  review['comment'] ?? 'Không có bình luận',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ngày: ${review['created_at'].split(' ')[0]}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isApproved)
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Duyệt',
                    onPressed: () => _handleReviewAction(
                        review['id'] as int, 'approve', index),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Xóa',
                  onPressed: () =>
                      _handleReviewAction(review['id'] as int, 'delete', index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _loadReviews(page: _currentPage - 1)
                : null,
          ),
          Text('Trang $_currentPage / $_totalPages ($_totalItems Đánh giá)'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _loadReviews(page: _currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

// ===================================
// === Sub-Widget: Feedback List View ===
// ===================================

class _FeedbackListView extends StatefulWidget {
  const _FeedbackListView();

  @override
  State<_FeedbackListView> createState() => _FeedbackListViewState();
}

class _FeedbackListViewState extends State<_FeedbackListView> {
  final ApiService _apiService = ApiService();
  List<dynamic> _feedback = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  String? _selectedStatus; // Filter
  // ✅ ĐÃ THÊM TRẠNG THÁI 'pending'
  final List<String> _statuses = [
    'pending',
    'new',
    'in_progress',
    'resolved',
    'closed'
  ];

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback({int page = 1}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getAdminFeedback(
      page: page,
      perPage: 20,
      status: _selectedStatus,
    );

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _feedback = result['data']['feedback'] ?? [];
        _currentPage = result['data']['current_page'] ?? 1;
        _totalPages = result['data']['pages'] ?? 1;
        _totalItems = result['data']['total'] ?? 0;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Lỗi không xác định.';
        _isLoading = false;
      });
    }
  }

  void _showRespondDialog(int feedbackId, String currentStatus) {
    final TextEditingController responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // ✅ SỬ DỤNG StatefulBuilder ĐỂ KHẮC PHỤC LỖI ASSERTION
        return StatefulBuilder(
          builder: (context, setInnerState) {
            String newStatus = currentStatus; // Biến trạng thái cục bộ

            return AlertDialog(
              title: const Text('Phản hồi Phản hồi'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextField(
                      controller: responseController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung phản hồi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      // Giá trị phải khớp chính xác với một item trong danh sách
                      value: newStatus,
                      decoration:
                          const InputDecoration(labelText: 'Trạng thái mới'),
                      items: _statuses
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setInnerState(() {
                            // Cập nhật trạng thái cục bộ
                            newStatus = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Hủy'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Gửi'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _handleRespondAction(
                        feedbackId, responseController.text, newStatus);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleRespondAction(
      int feedbackId, String response, String newStatus) async {
    if (response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung phản hồi.')),
      );
      return;
    }

    final result =
        await _apiService.respondToFeedback(feedbackId, response, newStatus);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi phản hồi thành công.')),
      );
      _loadFeedback(page: _currentPage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Thất bại: ${result['error'] ?? 'Lỗi không xác định'}')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange; // Thêm màu cho pending
      case 'new':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Bar
        _buildFeedbackFilterBar(),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text('Lỗi: $_errorMessage'))
                  : _feedback.isEmpty
                      ? const Center(child: Text('Không có phản hồi nào.'))
                      : _buildFeedbackList(),
        ),
        if (!_isLoading && _totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildFeedbackFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: DropdownButton<String?>(
        // ✅ Thay đổi thành String?
        hint: const Text('Trạng thái'),
        value: _selectedStatus,
        items: [
          const DropdownMenuItem<String?>(
            // ✅ Thay đổi thành String?
            value: null,
            child: Text('Tất cả Trạng thái'),
          ),
          ..._statuses.map((status) => DropdownMenuItem<String?>(
                // ✅ Thay đổi thành String?
                value: status,
                child: Text(status.toUpperCase()),
              )),
        ],
        onChanged: (String? newValue) {
          setState(() {
            _selectedStatus = newValue;
          });
          _loadFeedback();
        },
      ),
    );
  }

  Widget _buildFeedbackList() {
    return ListView.builder(
      itemCount: _feedback.length,
      itemBuilder: (context, index) {
        final feedback = _feedback[index];
        final statusColor = _getStatusColor(feedback['status']);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            isThreeLine: true,
            leading: Icon(Icons.comment, color: statusColor),
            title: Text(
              '${feedback['subject']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Người gửi: ${feedback['user_name'] ?? 'Ẩn danh'}'),
                Text(
                  feedback['message'] ?? 'Nội dung trống',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Phân loại: ${feedback['type'] ?? 'Khác'} | Ưu tiên: ${feedback['priority'] ?? 'Thấp'}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Giữ min cho chiều cao
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    feedback['status'].toUpperCase(),
                    style: TextStyle(fontSize: 10, color: statusColor),
                  ),
                ),
                // const SizedBox(height: 4), // Xóa hoặc giảm bớt khoảng cách này
                // Giảm kích thước của IconButton để tiết kiệm không gian
                SizedBox(
                  height: 32, // Giảm chiều cao IconButton mặc định 48 xuống 32
                  child: IconButton(
                    icon: const Icon(Icons.reply,
                        color: Colors.blue, size: 20), // Giảm size icon
                    tooltip: 'Phản hồi',
                    onPressed: () => _showRespondDialog(
                        feedback['id'] as int, feedback['status'] as String),
                  ),
                ),
              ],
            ),
            onTap: () {
              // TODO: Mở chi tiết phản hồi
            },
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _loadFeedback(page: _currentPage - 1)
                : null,
          ),
          Text('Trang $_currentPage / $_totalPages ($_totalItems Phản hồi)'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _loadFeedback(page: _currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
