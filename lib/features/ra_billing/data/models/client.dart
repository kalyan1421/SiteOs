/// A billable party (employer / customer) for RA bills.
/// Maps to the `clients` table (migration 056_ra_billing.sql).
class BillingClient {
  final String id;
  final String companyId;
  final String name;
  final String? gstin;
  final String? stateCode;
  final String? address;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BillingClient({
    required this.id,
    required this.companyId,
    required this.name,
    this.gstin,
    this.stateCode,
    this.address,
    this.contactPerson,
    this.contactPhone,
    this.contactEmail,
    this.createdAt,
    this.updatedAt,
  });

  factory BillingClient.fromJson(Map<String, dynamic> json) => BillingClient(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        name: json['name'] as String? ?? '',
        gstin: json['gstin'] as String?,
        stateCode: json['state_code'] as String?,
        address: json['address'] as String?,
        contactPerson: json['contact_person'] as String?,
        contactPhone: json['contact_phone'] as String?,
        contactEmail: json['contact_email'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'gstin': gstin,
        'state_code': stateCode,
        'address': address,
        'contact_person': contactPerson,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
      };

  BillingClient copyWith({
    String? id,
    String? companyId,
    String? name,
    String? gstin,
    String? stateCode,
    String? address,
    String? contactPerson,
    String? contactPhone,
    String? contactEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      BillingClient(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        name: name ?? this.name,
        gstin: gstin ?? this.gstin,
        stateCode: stateCode ?? this.stateCode,
        address: address ?? this.address,
        contactPerson: contactPerson ?? this.contactPerson,
        contactPhone: contactPhone ?? this.contactPhone,
        contactEmail: contactEmail ?? this.contactEmail,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
