/// A subcontractor — the firm or individual a company awards work to.
///
/// Maps to the `subcontractors` table (migration 062_subcontractor.sql).
class SubcontractorModel {
  final String id;
  final String companyId;
  final String name;
  final String? gstin;
  final String? pan;
  final String? specialization;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SubcontractorModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.gstin,
    this.pan,
    this.specialization,
    this.phone,
    this.email,
    this.address,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory SubcontractorModel.fromJson(Map<String, dynamic> json) {
    return SubcontractorModel(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      gstin: json['gstin'] as String?,
      pan: json['pan'] as String?,
      specialization: json['specialization'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Payload for insert/update. Excludes server-managed columns.
  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'name': name,
      'gstin': gstin,
      'pan': pan,
      'specialization': specialization,
      'phone': phone,
      'email': email,
      'address': address,
      'is_active': isActive,
    };
  }

  SubcontractorModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? gstin,
    String? pan,
    String? specialization,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubcontractorModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubcontractorModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
