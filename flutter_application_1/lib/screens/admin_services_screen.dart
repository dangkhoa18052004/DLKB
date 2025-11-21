import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _services = [];
  List<dynamic> _departments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Load services và departments cùng lúc
    final servicesResult = await _apiService.getAllServices();
    final deptsResult = await _apiService.getAllDepartments();

    if (servicesResult['success'] && deptsResult['success']) {
      setState(() {
        _services = servicesResult['data'] ?? [];
        _departments = deptsResult['data'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = servicesResult['error'] ?? deptsResult['error'];
        _isLoading = false;
      });
    }
  }

  // ===== THÊM DỊCH VỤ =====
  Future<void> _showAddServiceDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    int? selectedDeptId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm Dịch vụ mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên dịch vụ *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá (VNĐ) *',
                    border: OutlineInputBorder(),
                    prefixText: '₫ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian (phút)',
                    border: OutlineInputBorder(),
                    suffixText: 'phút',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Chuyên khoa',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedDeptId,
                  items: _departments.map<DropdownMenuItem<int>>((dept) {
                    return DropdownMenuItem<int>(
                      value: dept['id'],
                      child: Text(dept['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedDeptId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền đầy đủ thông tin'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                final result = await _apiService.createService({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0,
                  'duration_minutes': int.tryParse(durationController.text) ?? 30,
                  'department_id': selectedDeptId,
                  'is_active': true,
                });

                if (!mounted) return;
                Navigator.pop(context);

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã thêm dịch vụ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${result['error']}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== SỬA DỊCH VỤ =====
  Future<void> _showEditServiceDialog(Map<String, dynamic> service) async {
    final nameController = TextEditingController(text: service['name']);
    final descController = TextEditingController(text: service['description']);
    final priceController = TextEditingController(
      text: service['price']?.toString().replaceAll('₫', '').trim(),
    );
    final durationController = TextEditingController(
      text: service['duration_minutes']?.toString() ?? '30',
    );
    int? selectedDeptId = service['department_id'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sửa Dịch vụ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên dịch vụ *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá (VNĐ) *',
                    border: OutlineInputBorder(),
                    prefixText: '₫ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian (phút)',
                    border: OutlineInputBorder(),
                    suffixText: 'phút',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Chuyên khoa',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedDeptId,
                  items: _departments.map<DropdownMenuItem<int>>((dept) {
                    return DropdownMenuItem<int>(
                      value: dept['id'],
                      child: Text(dept['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedDeptId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng điền đủ thông tin')),
                  );
                  return;
                }

                Navigator.pop(context);
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                final result = await _apiService.updateService(
                  service['id'],
                  {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'price': double.tryParse(priceController.text) ?? 0,
                    'duration_minutes': int.tryParse(durationController.text) ?? 30,
                    'department_id': selectedDeptId,
                  },
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${result['error']}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  // ===== XÓA DỊCH VỤ =====
  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa dịch vụ "${service['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _apiService.deleteService(service['id']);

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa dịch vụ'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0 ₫';
    final priceStr = price.toString().replaceAll('₫', '').trim();
    final priceNum = double.tryParse(priceStr) ?? 0;
    return '${priceNum.toStringAsFixed(0)} ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Dịch vụ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
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
                      Icon(Icons.error, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Lỗi: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _services.isEmpty
                  ? const Center(child: Text('Chưa có dịch vụ nào'))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: const Icon(
                                  Icons.medical_services,
                                  color: Colors.green,
                                ),