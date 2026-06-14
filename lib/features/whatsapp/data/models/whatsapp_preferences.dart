import 'whatsapp_recipient.dart';

/// A company's daily-report WhatsApp preferences.
///
/// Mirrors the `whatsapp_preferences` table (migration 057). [recipients] is
/// stored as a JSONB array of {name, phone} objects. [sendHour] is the local
/// (IST) hour 0–23 the daily report is dispatched at; defaults to 19 (7 PM).
class WhatsAppPreferences {
  final String? id;
  final String companyId;
  final bool dailyReportEnabled;
  final List<WhatsAppRecipient> recipients;
  final int sendHour;

  const WhatsAppPreferences({
    this.id,
    required this.companyId,
    required this.dailyReportEnabled,
    required this.recipients,
    required this.sendHour,
  });

  factory WhatsAppPreferences.fromJson(Map<String, dynamic> json) {
    final rawRecipients = json['recipients'];
    final list = <WhatsAppRecipient>[];
    if (rawRecipients is List) {
      for (final item in rawRecipients) {
        if (item is Map) {
          list.add(WhatsAppRecipient.fromJson(
              Map<String, dynamic>.from(item)));
        }
      }
    }
    return WhatsAppPreferences(
      id: json['id'] as String?,
      companyId: json['company_id'] as String,
      dailyReportEnabled: json['daily_report_enabled'] as bool? ?? false,
      recipients: list,
      sendHour: (json['send_hour'] as num?)?.toInt() ?? 19,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'company_id': companyId,
        'daily_report_enabled': dailyReportEnabled,
        'recipients': recipients.map((r) => r.toJson()).toList(),
        'send_hour': sendHour,
      };

  /// Safe default when no preferences row exists yet for the company.
  factory WhatsAppPreferences.empty(String companyId) => WhatsAppPreferences(
        companyId: companyId,
        dailyReportEnabled: false,
        recipients: const [],
        sendHour: 19,
      );

  WhatsAppPreferences copyWith({
    String? id,
    String? companyId,
    bool? dailyReportEnabled,
    List<WhatsAppRecipient>? recipients,
    int? sendHour,
  }) =>
      WhatsAppPreferences(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        dailyReportEnabled: dailyReportEnabled ?? this.dailyReportEnabled,
        recipients: recipients ?? this.recipients,
        sendHour: sendHour ?? this.sendHour,
      );
}
