// models/department_model.dart
class Department {
  final int id;
  final String name;
  final String description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;

  Department({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['icon_url'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}
