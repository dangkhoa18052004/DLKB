// feedback_review_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../services/api_service.dart';

class FeedbackReviewScreen extends StatefulWidget {
  // appointmentId là bắt buộc cho việc gửi đánh giá
  final int? appointmentId;
  final String? appointmentCode;
  final String? doctorName;

  const FeedbackReviewScreen({
    super.key,
    this.appointmentId,
    this.appointmentCode,
    this.doctorName,
  });

  @override
  State<FeedbackReviewScreen> createState() => _FeedbackReviewScreenState();
}

class _FeedbackReviewScreenState extends State<FeedbackReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // Feedback Form
  final _feedbackFormKey = GlobalKey<FormState>();
  final _feedbackSubjectController = TextEditingController();
  final _feedbackMessageController = TextEditingController();
  String _feedbackType = 'suggestion';
  String _feedbackPriority = 'normal';
  bool _isSubmittingFeedback = false;

  // Review Form
  final _reviewFormKey = GlobalKey<FormState>();
  final _reviewCommentController = TextEditingController();
  double _overallRating = 5.0;
  double _serviceRating = 5.0;
  double _facilityRating = 5.0;
  bool _isAnonymous = false;
  bool _isSubmittingReview = false;

  // My Reviews
  List<dynamic> _myReviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    // Chuyển sang tab Đánh giá (index 1) nếu có sẵn appointmentId
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.appointmentId != null ? 1 : 0,
    );
    _loadMyReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackSubjectController.dispose();
    _feedbackMessageController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadMyReviews() async {
    setState(() => _isLoadingReviews = true);

    final result = await _apiService.getMyReviews();

    if (result['success']) {
      setState(() {
        _myReviews = result['data'] ?? [];
        _isLoadingReviews = false;
      });
    } else {
      setState(() => _isLoadingReviews = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Không thể tải đánh giá'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (!_feedbackFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingFeedback = true);

    final feedbackData = {
      'type': _feedbackType,
      'subject': _feedbackSubjectController.text.trim(),
      'message': _feedbackMessageController.text.trim(),
      'priority': _feedbackPriority,
    };

    final result = await _apiService.submitFeedback(feedbackData);

    setState(() => _isSubmittingFeedback = false);

    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gửi phản hồi thành công! Cảm ơn bạn.'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _feedbackSubjectController.clear();
      _feedbackMessageController.clear();
      setState(() {
        _feedbackType = 'suggestion';
        _feedbackPriority = 'normal';
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Gửi phản hồi thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitReview() async {
    if (widget.appointmentId == null) {
      // HIỂN THỊ LỖI NẾU KHÔNG CÓ LỊCH HẸN ĐỂ ĐÁNH GIÁ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn lịch hẹn đã hoàn thành để đánh giá'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_reviewFormKey.currentState!.validate()) return;

    setState(() => _isSubmittingReview = true);

    final reviewData = {
      'appointment_id': widget.appointmentId,
      'rating': _overallRating.toInt(),
      'service_rating': _serviceRating.toInt(),
      'facility_rating': _facilityRating.toInt(),
      'comment': _reviewCommentController.text.trim(),
      'is_anonymous': _isAnonymous,
    };

    final result = await _apiService.submitReview(reviewData);

    setState(() => _isSubmittingReview = false);

    if (result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gửi đánh giá thành công! Cảm ơn bạn.'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload reviews
      _loadMyReviews();

      // Clear form
      _reviewCommentController.clear();
      setState(() {
        _overallRating = 5.0;
        _serviceRating = 5.0;
        _facilityRating = 5.0;
        _isAnonymous = false;
      });

      // Chuyển sang tab Đã đánh giá
      _tabController.animateTo(2);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Gửi đánh giá thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phản hồi & Đánh giá'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.feedback), text: 'Phản hồi'),
            Tab(icon: Icon(Icons.star), text: 'Đánh giá'),
            Tab(icon: Icon(Icons.history), text: 'Đã đánh giá'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedbackTab(),
          _buildReviewTab(),
          _buildMyReviewsTab(),
        ],
      ),
    );
  }

  // TAB 1: Gửi Phản hồi
  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _feedbackFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Chia sẻ trải nghiệm của bạn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ý kiến của bạn giúp chúng tôi cải thiện chất lượng dịch vụ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Feedback Type
            const Text(
              'Loại phản hồi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _feedbackType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.category),
              ),
              items: const [
                DropdownMenuItem(value: 'suggestion', child: Text('Đề xuất')),
                DropdownMenuItem(value: 'complaint', child: Text('Khiếu nại')),
                DropdownMenuItem(value: 'compliment', child: Text('Khen ngợi')),
                DropdownMenuItem(value: 'question', child: Text('Câu hỏi')),
                DropdownMenuItem(value: 'other', child: Text('Khác')),
              ],
              onChanged: (value) {
                setState(() {
                  _feedbackType = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            // Priority
            const Text(
              'Mức độ ưu tiên',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'low',
                  label: Text('Thấp'),
                  icon: Icon(Icons.arrow_downward, size: 16),
                ),
                ButtonSegment(
                  value: 'normal',
                  label: Text('Bình thường'),
                  icon: Icon(Icons.horizontal_rule, size: 16),
                ),
                ButtonSegment(
                  value: 'high',
                  label: Text('Cao'),
                  icon: Icon(Icons.arrow_upward, size: 16),
                ),
              ],
              selected: {_feedbackPriority},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _feedbackPriority = newSelection.first;
                });
              },
            ),

            const SizedBox(height: 20),

            // Subject
            const Text(
              'Tiêu đề',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _feedbackSubjectController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
                hintText: 'Nhập tiêu đề phản hồi...',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tiêu đề';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Message
            const Text(
              'Nội dung phản hồi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _feedbackMessageController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Chia sẻ chi tiết ý kiến của bạn...',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập nội dung phản hồi';
                }
                if (value.length < 10) {
                  return 'Nội dung phải có ít nhất 10 ký tự';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingFeedback ? null : _submitFeedback,
                icon: _isSubmittingFeedback
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSubmittingFeedback ? 'Đang gửi...' : 'Gửi phản hồi',
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: Đánh giá
  Widget _buildReviewTab() {
    // Nếu không có appointmentId, hiển thị thông báo hướng dẫn
    if (widget.appointmentId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_late_outlined,
                  size: 60, color: Colors.orange.shade400),
              const SizedBox(height: 16),
              const Text(
                'Chưa chọn Lịch hẹn để đánh giá',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng quay lại màn hình "Lịch hẹn của tôi", chọn một cuộc hẹn đã hoàn thành và nhấn nút "Đánh giá".',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Nếu có appointmentId, hiển thị form đánh giá
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _reviewFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appointment Info
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Đánh giá lịch khám',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Mã lịch hẹn: ${widget.appointmentCode ?? 'N/A'}'),
                    if (widget.doctorName != null)
                      Text('Bác sĩ: ${widget.doctorName}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Overall Rating
            const Text(
              'Đánh giá tổng thể',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  RatingBar.builder(
                    initialRating: _overallRating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemSize: 45,
                    itemBuilder: (context, _) => const Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      setState(() {
                        _overallRating = rating;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRatingText(_overallRating),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getRatingColor(_overallRating),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Service Rating
            _buildRatingRow(
              'Chất lượng dịch vụ',
              _serviceRating,
              (rating) => setState(() => _serviceRating = rating),
            ),

            const SizedBox(height: 20),

            // Facility Rating
            _buildRatingRow(
              'Cơ sở vật chất',
              _facilityRating,
              (rating) => setState(() => _facilityRating = rating),
            ),

            const SizedBox(height: 32),

            // Comment
            const Text(
              'Nhận xét chi tiết',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reviewCommentController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintText: 'Chia sẻ trải nghiệm của bạn...',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),

            const SizedBox(height: 20),

            // Anonymous Option
            CheckboxListTile(
              value: _isAnonymous,
              onChanged: (value) {
                setState(() {
                  _isAnonymous = value!;
                });
              },
              title: const Text('Đánh giá ẩn danh'),
              subtitle: const Text('Tên của bạn sẽ không được hiển thị'),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingReview ? null : _submitReview,
                icon: _isSubmittingReview
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSubmittingReview ? 'Đang gửi...' : 'Gửi đánh giá',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 3: My Reviews
  Widget _buildMyReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Chưa có đánh giá nào',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyReviews,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _myReviews.length,
        itemBuilder: (context, index) {
          final review = _myReviews[index] as Map<String, dynamic>;
          return _buildReviewCard(review);
        },
      ),
    );
  }

  Widget _buildRatingRow(
    String label,
    double rating,
    Function(double) onRatingUpdate,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        RatingBar.builder(
          initialRating: rating,
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: false,
          itemCount: 5,
          itemSize: 30,
          itemBuilder: (context, _) => const Icon(
            Icons.star,
            color: Colors.amber,
          ),
          onRatingUpdate: onRatingUpdate,
        ),
        const SizedBox(width: 8),
        Text(
          '${rating.toInt()}/5',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    // Ép kiểu an toàn hơn và cung cấp giá trị mặc định nếu null
    final isApproved = review['is_approved'] == true;
    final rating = (review['rating'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Mã lịch: ${review['appointment_code'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isApproved ? 'Đã duyệt' : 'Chờ duyệt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isApproved
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bác sĩ: ${review['doctor_name'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                RatingBarIndicator(
                  rating: rating,
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  itemCount: 5,
                  itemSize: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${rating.toInt()}/5',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (review['comment'] != null && review['comment'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review['comment'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Ngày đánh giá: ${review['created_at'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Tuyệt vời';
    if (rating >= 4) return 'Tốt';
    if (rating >= 3) return 'Trung bình';
    if (rating >= 2) return 'Kém';
    return 'Rất kém';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}
