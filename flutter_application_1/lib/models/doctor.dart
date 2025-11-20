class Doctor {
  final int id;
  final String fullName;
  final String specialization;
  final double rating;
  final String consultationFee; // Giả định là String để dễ hiển thị tiền tệ

  const Doctor({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.rating,
    required this.consultationFee,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'],
      fullName: json['full_name'],
      specialization: json['specialization'],
      // Đảm bảo rating là double
      rating: double.tryParse(json['rating'].toString()) ?? 0.0,
      consultationFee: json['consultation_fee'],
    );
  }
}
