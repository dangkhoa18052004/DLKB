import 'package:flutter/material.dart';
import 'package:hospital_admin_app/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DoctorStatsScreen extends StatefulWidget {
  const DoctorStatsScreen({super.key});

  @override
  State<DoctorStatsScreen> createState() => _DoctorStatsScreenState();
}

class _DoctorStatsScreenState extends State<DoctorStatsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = '7days'; // 7days, 30days, 3months

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DateTime endDate = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case '7days':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case '30days':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case '3months':
          startDate = endDate.subtract(const Duration(days: 90));
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 7));
      }

      final appointmentsResult = await _apiService.getDoctorAppointments();

      if (!mounted) return;

      if (appointmentsResult['success']) {
        final appointments = appointmentsResult['data']['appointments'] as List;

        // Tính toán thống kê
        int totalAppointments = appointments.length;
        int completedCount =
            appointments.where((a) => a['status'] == 'completed').length;
        int cancelledCount =
            appointments.where((a) => a['status'] == 'cancelled').length;
        int pendingCount =
            appointments.where((a) => a['status'] == 'pending').length;

        double completionRate =
            totalAppointments > 0 ? completedCount / totalAppointments : 0;

        setState(() {
          _stats = {
            'total': totalAppointments,
            'completed': completedCount,
            'cancelled': cancelledCount,
            'pending': pendingCount,
            'completion_rate': completionRate,
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              appointmentsResult['error'] ?? 'Không thể tải dữ liệu';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê Cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(_errorMessage!),
                      ElevatedButton(
                        onPressed: _loadStats,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Period Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPeriodChip('7 ngày', '7days'),
                _buildPeriodChip('30 ngày', '30days'),
                _buildPeriodChip('3 tháng', '3months'),
              ],
            ),
          ),

          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng quan Hiệu suất',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tổng lịch hẹn',
                        _stats!['total'].toString(),
                        Icons.event_note,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Hoàn thành',
                        _stats!['completed'].toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Hủy bỏ',
                        _stats!['cancelled'].toString(),
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Đang chờ',
                        _stats!['pending'].toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Completion Rate Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade600,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Tỷ lệ hoàn thành',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(_stats!['completion_rate'] * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _stats!['completion_rate'],
                          backgroundColor: Colors.white30,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Pie Chart
                Text(
                  'Phân bổ Trạng thái',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: _buildPieChart(),
                ),

                const SizedBox(height: 24),

                // Performance Tips
                _buildTipsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriod = value;
          });
          _loadStats();
        }
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: _stats!['completed'].toDouble(),
            title: 'Hoàn thành\n${_stats!['completed']}',
            color: Colors.green,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: _stats!['cancelled'].toDouble(),
            title: 'Hủy\n${_stats!['cancelled']}',
            color: Colors.red,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            value: _stats!['pending'].toDouble(),
            title: 'Chờ\n${_stats!['pending']}',
            color: Colors.orange,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Gợi ý Cải thiện',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              'Giảm tỷ lệ hủy bỏ bằng cách xác nhận lịch hẹn sớm',
            ),
            _buildTipItem(
              'Cập nhật hồ sơ bệnh án ngay sau khi khám',
            ),
            _buildTipItem(
              'Phản hồi nhanh các lịch hẹn pending',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
