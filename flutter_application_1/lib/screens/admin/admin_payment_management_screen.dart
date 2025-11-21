// admin_payment_management_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class AdminPaymentManagementScreen extends StatefulWidget {
  const AdminPaymentManagementScreen({super.key});

  @override
  State<AdminPaymentManagementScreen> createState() =>
      _AdminPaymentManagementScreenState();
}

class _AdminPaymentManagementScreenState
    extends State<AdminPaymentManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _payments = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;

  String? _selectedStatus; // Filter
  DateTime? _dateFrom; // Filter
  DateTime? _dateTo; // Filter

  final List<String> _statuses = [
    'completed',
    'pending',
    'failed',
    'processing'
  ];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments({int page = 1}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateFromStr =
        _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null;
    final dateToStr =
        _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null;

    final result = await _apiService.getAdminPaymentRecords(
      page: page,
      perPage: 20,
      status: _selectedStatus,
      dateFrom: dateFromStr,
      dateTo: dateToStr,
    );

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _payments = result['data']['payments'] ?? [];
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

  // Phương thức chọn ngày
  Future<void> _selectDate(bool isDateFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isDateFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
      _loadPayments();
    }
  }

  // Phương thức reset filters
  void _resetFilters() {
    setState(() {
      _selectedStatus = null;
      _dateFrom = null;
      _dateTo = null;
    });
    _loadPayments();
  }

  // Helper để format tiền tệ
  String _formatCurrency(String? amountStr) {
    if (amountStr == null) return '0 ₫';
    final num = double.tryParse(amountStr) ?? 0;
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(num)} ₫';
  }

  // Helper để lấy màu trạng thái
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thanh Toán'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadPayments(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                            'Lỗi khi tải dữ liệu: $_errorMessage. Vui lòng thử lại.'),
                      )
                    : _payments.isEmpty
                        ? const Center(child: Text('Không có giao dịch nào.'))
                        : _buildPaymentList(),
          ),
          // Pagination
          if (!_isLoading && _totalPages > 1) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          // Filter theo Trạng thái
          DropdownButton<String>(
            hint: const Text('Trạng thái'),
            value: _selectedStatus,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Tất cả Trạng thái'),
              ),
              ..._statuses.map((status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status.toUpperCase()),
                  )),
            ],
            onChanged: (String? newValue) {
              setState(() {
                _selectedStatus = newValue;
              });
              _loadPayments();
            },
          ),
          // Filter theo Ngày từ
          ActionChip(
            label: Text(_dateFrom == null
                ? 'Ngày từ'
                : 'Từ: ${DateFormat('dd/MM/yyyy').format(_dateFrom!)}'),
            onPressed: () => _selectDate(true),
            backgroundColor: _dateFrom != null ? Colors.blue.shade100 : null,
          ),
          // Filter theo Ngày đến
          ActionChip(
            label: Text(_dateTo == null
                ? 'Ngày đến'
                : 'Đến: ${DateFormat('dd/MM/yyyy').format(_dateTo!)}'),
            onPressed: () => _selectDate(false),
            backgroundColor: _dateTo != null ? Colors.blue.shade100 : null,
          ),
          // Nút Reset
          if (_selectedStatus != null || _dateFrom != null || _dateTo != null)
            ActionChip(
              avatar: const Icon(Icons.close, size: 18),
              label: const Text('Xóa lọc'),
              onPressed: _resetFilters,
              backgroundColor: Colors.red.shade100,
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    return ListView.builder(
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(Icons.credit_card,
                color: _getStatusColor(payment['payment_status'])),
            title: Text(
              '${payment['payment_code']} - ${payment['patient_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                '${payment['appointment_code']}\n${payment['payment_method'].toUpperCase()} | Giao dịch: ${payment['transaction_id'] ?? 'N/A'}'),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatCurrency(payment['amount']),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(payment['payment_status'])),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(payment['payment_status'])
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment['payment_status'].toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(payment['payment_status'])),
                  ),
                ),
              ],
            ),
            onTap: () {
              // TODO: Mở chi tiết giao dịch nếu cần
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
                ? () => _loadPayments(page: _currentPage - 1)
                : null,
          ),
          Text('Trang $_currentPage / $_totalPages ($_totalItems Giao dịch)'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _loadPayments(page: _currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
