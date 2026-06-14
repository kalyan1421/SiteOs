/// Connection status for a company's WhatsApp Cloud API integration.
///
/// Mirrors the `whatsapp_config` table (migration 057). The Meta access token
/// is NEVER stored here — only a [configured] flag plus non-secret display
/// fields. The token + phone-number id live as edge-function secrets.
class WhatsAppConfig {
  final String? id;
  final String companyId;
  final bool configured;
  final String? phoneNumberId;
  final String? displayPhone;
  final String? businessName;

  const WhatsAppConfig({
    this.id,
    required this.companyId,
    required this.configured,
    this.phoneNumberId,
    this.displayPhone,
    this.businessName,
  });

  factory WhatsAppConfig.fromJson(Map<String, dynamic> json) => WhatsAppConfig(
        id: json['id'] as String?,
        companyId: json['company_id'] as String,
        configured: json['configured'] as bool? ?? false,
        phoneNumberId: json['phone_number_id'] as String?,
        displayPhone: json['display_phone'] as String?,
        businessName: json['business_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'company_id': companyId,
        'configured': configured,
        'phone_number_id': phoneNumberId,
        'display_phone': displayPhone,
        'business_name': businessName,
      };

  /// Safe default when no config row exists yet for the company.
  factory WhatsAppConfig.empty(String companyId) =>
      WhatsAppConfig(companyId: companyId, configured: false);

  WhatsAppConfig copyWith({
    String? id,
    String? companyId,
    bool? configured,
    String? phoneNumberId,
    String? displayPhone,
    String? businessName,
  }) =>
      WhatsAppConfig(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        configured: configured ?? this.configured,
        phoneNumberId: phoneNumberId ?? this.phoneNumberId,
        displayPhone: displayPhone ?? this.displayPhone,
        businessName: businessName ?? this.businessName,
      );
}
