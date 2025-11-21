// admin_reports_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // Data states
  Map<String, dynamic>? _overviewData;
  bool _isLoading = true;
  String? _errorMessage;

  // Chart states
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadOverviewData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverviewData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.getDashboardOverview();
      if (result['success']) {
        setState(() {
          _overviewData = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'];
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

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final num = double.tryParse(value.toString()) ?? 0;
    return num.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 ₫';
    final num = double.tryParse(value.toString()) ?? 0;
    return '${_formatNumber(num)} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê & Báo cáo'),
        actions: [
          IconButton(
            onPressed: _loadOverviewData,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Lịch hẹn'),
            Tab(text: 'Doanh thu'),
            Tab(text: 'Bệnh nhân'),
            Tab(text: 'Hiệu suất BS'),
            Tab(text: 'Chuyên khoa'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAppointmentsTab(),
          _buildRevenueTab(),
          _buildPatientsTab(),
          _buildDoctorPerformanceTab(),
          _buildDepartmentsTab(),
        ],
      ),
    );
  }

  // =============================================
  // TAB 1: DASHBOARD TỔNG QUAN
  // =============================================
  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    final data = _overviewData!;
    final patients = data['patients'];
    final doctors = data['doctors'];
    final appointments = data['appointments'];
    final revenue = data['revenue'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Thống kê nhanh - Responsive Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    'Tổng bệnh nhân',
                    patients['total'].toString(),
                    Icons.people,
                    Colors.blue,
                    'Mới: ${patients['new_this_month']}',
                  ),
                  _buildStatCard(
                    'Tổng bác sĩ',
                    doctors['total'].toString(),
                    Icons.medical_services,
                    Colors.green,
                    'Đang hoạt động',
                  ),
                  _buildStatCard(
                    'Lịch hẹn hôm nay',
                    appointments['today'].toString(),
                    Icons.calendar_today,
                    Colors.orange,
                    'Tổng: ${appointments['total']}',
                  ),
                  _buildStatCard(
                    'Doanh thu tháng',
                    _formatCurrency(revenue['this_month']),
                    Icons.monetization_on,
                    Colors.purple,
                    'Thay đổi: ${revenue['change_percent']}%',
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Biểu đồ doanh thu với fl_chart
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xu hướng Doanh thu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildRevenueLineChart(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Biểu đồ lịch hẹn
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lịch hẹn theo Trạng thái',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildAppointmentsPieChart(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Top bác sĩ
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Bác sĩ theo Lượt khám',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTopDoctorsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // CÁC TAB KHÁC (GIỮ NGUYÊN)
  // =============================================
  Widget _buildAppointmentsTab() {
    return const Center(child: Text('Báo cáo Lịch hẹn - Đang phát triển'));
  }

  Widget _buildRevenueTab() {
    return const Center(child: Text('Báo cáo Doanh thu - Đang phát triển'));
  }

  Widget _buildPatientsTab() {
    return const Center(child: Text('Báo cáo Bệnh nhân - Đang phát triển'));
  }

  Widget _buildDoctorPerformanceTab() {
    return const Center(child: Text('Hiệu suất Bác sĩ - Đang phát triển'));
  }

  Widget _buildDepartmentsTab() {
    return const Center(child: Text('Báo cáo Chuyên khoa - Đang phát triển'));
  }

  // =============================================
  // WIDGET BUILDERS
  // =============================================

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadOverviewData,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  // =============================================
  // FL_CHART BUILDERS
  // =============================================

  Widget _buildRevenueLineChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        minX: 0,
        maxX: 11,
        minY: 0,
        maxY: 6,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(2.6, 2),
              FlSpot(4.9, 5),
              FlSpot(6.8, 3.1),
              FlSpot(8, 4),
              FlSpot(9.5, 3),
              FlSpot(11, 4),
            ],
            isCurved: true,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsPieChart() {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 0,
        centerSpaceRadius: 40,
        sections: showingSections(),
      ),
    );
  }

  List<PieChartSectionData> showingSections() {
    return List.generate(4, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 20.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;
      const shadows = [Shadow(color: Colors.black, blurRadius: 2)];

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: Colors.blue,
            value: 40,
            title: '40%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 1:
          return PieChartSectionData(
            color: Colors.green,
            value: 30,
            title: '30%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 2:
          return PieChartSectionData(
            color: Colors.orange,
            value: 15,
            title: '15%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 3:
          return PieChartSectionData(
            color: Colors.red,
            value: 15,
            title: '15%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        default:
          throw Error();
      }
    });
  }

  Widget _buildTopDoctorsList() {
    final doctors = [
      {'name': 'BS. Nguyễn Văn A', 'appointments': 45, 'rating': 4.8},
      {'name': 'BS. Trần Thị B', 'appointments': 38, 'rating': 4.9},
      {'name': 'BS. Lê Văn C', 'appointments': 32, 'rating': 4.7},
      {'name': 'BS. Phạm Thị D', 'appointments': 28, 'rating': 4.6},
    ];

    return Column(
      children: doctors
          .map((doctor) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                title: Text(doctor['name'].toString()),
                subtitle: Text('${doctor['appointments']} lượt khám'),
                trailing: Chip(
                  label: Text('${doctor['rating']} ⭐'),
                  backgroundColor: Colors.orange.shade100,
                ),
              ))
          .toList(),
    );
  }
}
