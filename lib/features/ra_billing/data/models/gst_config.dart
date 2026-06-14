/// Per-company GST and bank profile used on RA bills and Tally exports.
/// Maps to the `company_gst_config` table (migration 056_ra_billing.sql).
class GstConfig {
  final String id;
  final String companyId;
  final String? legalName;
  final String? gstin;
  final String? stateCode;
  final String? pan;
  final String? address;
  final String? bankName;
  final String? bankAccountNo;
  final String? bankIfsc;
  final String? bankBranch;
  final double defaultTdsPct;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GstConfig({
    required this.id,
    required this.companyId,
    this.legalName,
    this.gstin,
    this.stateCode,
    this.pan,
    this.address,
    this.bankName,
    this.bankAccountNo,
    this.bankIfsc,
    this.bankBranch,
    this.defaultTdsPct = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory GstConfig.fromJson(Map<String, dynamic> json) => GstConfig(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        legalName: json['legal_name'] as String?,
        gstin: json['gstin'] as String?,
        stateCode: json['state_code'] as String?,
        pan: json['pan'] as String?,
        address: json['address'] as String?,
        bankName: json['bank_name'] as String?,
        bankAccountNo: json['bank_account_no'] as String?,
        bankIfsc: json['bank_ifsc'] as String?,
        bankBranch: json['bank_branch'] as String?,
        defaultTdsPct: (json['default_tds_pct'] as num?)?.toDouble() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  /// Columns the client owns on write. `company_id` is set by the repository.
  Map<String, dynamic> toJson() => {
        'legal_name': legalName,
        'gstin': gstin,
        'state_code': stateCode,
        'pan': pan,
        'address': address,
        'bank_name': bankName,
        'bank_account_no': bankAccountNo,
        'bank_ifsc': bankIfsc,
        'bank_branch': bankBranch,
        'default_tds_pct': defaultTdsPct,
      };

  GstConfig copyWith({
    String? id,
    String? companyId,
    String? legalName,
    String? gstin,
    String? stateCode,
    String? pan,
    String? address,
    String? bankName,
    String? bankAccountNo,
    String? bankIfsc,
    String? bankBranch,
    double? defaultTdsPct,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      GstConfig(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        legalName: legalName ?? this.legalName,
        gstin: gstin ?? this.gstin,
        stateCode: stateCode ?? this.stateCode,
        pan: pan ?? this.pan,
        address: address ?? this.address,
        bankName: bankName ?? this.bankName,
        bankAccountNo: bankAccountNo ?? this.bankAccountNo,
        bankIfsc: bankIfsc ?? this.bankIfsc,
        bankBranch: bankBranch ?? this.bankBranch,
        defaultTdsPct: defaultTdsPct ?? this.defaultTdsPct,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
