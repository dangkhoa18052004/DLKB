// models/doctor_model.dart
class Doctor {
  final int id;
  final String fullName;
  final String licenseNumber;
  final String specialization;
  final int departmentId;
  final int experienceYears;
  final double consultationFee;
  final double rating;
  final int totalReviews;
  final bool isAvailable;
  final String email;
  final String phone;

  Doctor({
    required this.id,
    required this.fullName,
    required this.licenseNumber,
    required this.specialization,
    required this.departmentId,
    required this.experienceYears,
    required this.consultationFee,
    required this.rating,
    required this.totalReviews,
    required this.isAvailable,
    required this.email,
    required this.phone,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? '',
      licenseNumber: json['license_number'] ?? '',
      specialization: json['specialization'] ?? '',
      departmentId: json['department_id'] ?? 0,
      experienceYears: json['experience_years'] ?? 0,
      consultationFee:
          double.tryParse(json['consultation_fee']?.toString() ?? '0') ?? 0.0,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      totalReviews: json['total_reviews'] ?? 0,
      isAvailable: json['is_available'] ?? false,
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}
