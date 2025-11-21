import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
  String _searchQuery = '';
  int? _filterDepartmentId;
  bool? _filterIsActive;

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

  List<dynamic> get _filteredServices {
    return _services.where((service) {
      final matchesSearch = _searchQuery.isEmpty ||
          (service['name']?.toString().toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase()) ||
          (service['description']?.toString().toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase());

      final matchesDept = _filterDepartmentId == null ||
          service['department_id'] == _filterDepartmentId;

      final matchesActive =
          _filterIsActive == null || service['is_active'] == _filterIsActive;

      return matchesSearch && matchesDept && matchesActive;
    }).toList();
  }

  String _getDepartmentName(int? deptId) {
    if (deptId == null) return 'Chưa phân khoa';
    final dept = _departments.firstWhere(
      (d) => d['id'] == deptId,
      orElse: () => {'name': 'Không xác định'},
    );
    return dept['name'] ?? 'Không xác định';
  }

  Future<void> _showAddServiceDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    int? selectedDeptId;
    bool isActive = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Thêm Dịch vụ mới'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên dịch vụ *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá (VNĐ) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: '₫',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian (phút)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                      suffixText: 'phút',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Chuyên khoa',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_hospital),
                    ),
                    value: selectedDeptId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('-- Chọn chuyên khoa --'),
                      ),
                      ..._departments.map<DropdownMenuItem<int>>((dept) {
                        return DropdownMenuItem<int>(
                          value: dept['id'],
                          child: Text(dept['name']),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedDeptId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Trạng thái hoạt động'),
                    subtitle: Text(isActive ? 'Đang hoạt động' : 'Đã tắt'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                    secondary: Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền tên và giá dịch vụ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _createService(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  price: double.tryParse(priceController.text) ?? 0,
                  duration: int.tryParse(durationController.text) ?? 30,
                  departmentId: selectedDeptId,
                  isActive: isActive,
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createService({
    required String name,
    required String description,
    required double price,
    required int duration,
    int? departmentId,
    required bool isActive,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _apiService.createService({
      'name': name,
      'description': description,
      'price': price,
      'duration_minutes': duration,
      'department_id': departmentId,
      'is_active': isActive,
    });

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm dịch vụ thành công'),
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

  Future<void> _showEditServiceDialog(Map<String, dynamic> service) async {
    final nameController = TextEditingController(text: service['name']);
    final descController =
        TextEditingController(text: service['description'] ?? '');
    final priceStr =
        service['price']?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '0';
    final priceController = TextEditingController(text: priceStr);
    final durationController = TextEditingController(
      text: service['duration_minutes']?.toString() ?? '30',
    );
    int? selectedDeptId = service['department_id'];
    bool isActive = service['is_active'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Sửa Dịch vụ'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên dịch vụ *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.medical_services),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá (VNĐ) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: '₫',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian (phút)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                      suffixText: 'phút',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Chuyên khoa',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_hospital),
                    ),
                    value: selectedDeptId,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('-- Chọn chuyên khoa --'),
                      ),
                      ..._departments.map<DropdownMenuItem<int>>((dept) {
                        return DropdownMenuItem<int>(
                          value: dept['id'],
                          child: Text(dept['name']),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() => selectedDeptId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Trạng thái hoạt động'),
                    subtitle: Text(isActive ? 'Đang hoạt động' : 'Đã tắt'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                    secondary: Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền tên và giá dịch vụ'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _updateService(
                  service['id'],
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  price: double.tryParse(priceController.text) ?? 0,
                  duration: int.tryParse(durationController.text) ?? 30,
                  departmentId: selectedDeptId,
                  isActive: isActive,
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateService(
    int serviceId, {
    required String name,
    required String description,
    required double price,
    required int duration,
    int? departmentId,
    required bool isActive,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _apiService.updateService(serviceId, {
      'name': name,
      'description': description,
      'price': price,
      'duration_minutes': duration,
      'department_id': departmentId,
      'is_active': isActive,
    });

    if (!mounted) return;
    Navigator.pop(context);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật dịch vụ'),
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

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Xác nhận xóa'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc muốn xóa dịch vụ:'),
            const SizedBox(height: 8),
            Text(
              '"${service['name']}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Lưu ý: Dịch vụ sẽ bị vô hiệu hóa thay vì xóa hoàn toàn.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
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
    final priceStr = price.toString().replaceAll(RegExp(r'[^\d.]'), '');
    final priceNum = double.tryParse(priceStr) ?? 0;
    final formatted = priceNum.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$formatted ₫';
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm dịch vụ...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Chuyên khoa',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    value: _filterDepartmentId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      ..._departments.map<DropdownMenuItem<int>>((dept) {
                        return DropdownMenuItem<int>(
                          value: dept['id'],
                          child: Text(
                            dept['name'],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _filterDepartmentId = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    decoration: InputDecoration(
                      labelText: 'Trạng thái',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    value: _filterIsActive,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tất cả')),
                      DropdownMenuItem(value: true, child: Text('Hoạt động')),
                      DropdownMenuItem(value: false, child: Text('Đã tắt')),
                    ],
                    onChanged: (value) {
                      setState(() => _filterIsActive = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isActive = service['is_active'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isActive ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: isActive ? Colors.green : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
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
                              color: isActive
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'Hoạt động' : 'Đã tắt',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (service['description'] != null &&
                          service['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            service['description'],
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.attach_money,
                    'Giá',
                    _formatPrice(service['price']),
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.timer,
                    'Thời gian',
                    '${service['duration_minutes'] ?? 30} phút',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    Icons.local_hospital,
                    'Khoa',
                    _getDepartmentName(service['department_id']),
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditServiceDialog(service),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Sửa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteService(service),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Xóa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredServices = _filteredServices;

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
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildFilterSection(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          Text(
                            'Tổng: ${filteredServices.length} dịch vụ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '(${_services.where((s) => s['is_active'] == true).length} hoạt động)',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredServices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Không có dịch vụ nào'),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredServices.length,
                                itemBuilder: (context, index) {
                                  return _buildServiceCard(
                                      filteredServices[index]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm dịch vụ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}
