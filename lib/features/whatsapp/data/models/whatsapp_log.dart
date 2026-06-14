/// Status of an outbound WhatsApp message.
enum WhatsAppLogStatus {
  queued('queued', 'Queued'),
  sent('sent', 'Sent'),
  failed('failed', 'Failed');

  final String value;
  final String label;
  const WhatsAppLogStatus(this.value, this.label);

  static WhatsAppLogStatus fromValue(String? value) =>
      WhatsAppLogStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => WhatsAppLogStatus.queued,
      );
}

/// One row from the `whatsapp_logs` audit table (migration 057).
class WhatsAppLog {
  final String id;
  final String companyId;
  final String template;
  final String to;
  final WhatsAppLogStatus status;
  final Map<String, dynamic>? payload;
  final DateTime? sentAt;
  final DateTime createdAt;

  const WhatsAppLog({
    required this.id,
    required this.companyId,
    required this.template,
    required this.to,
    required this.status,
    this.payload,
    this.sentAt,
    required this.createdAt,
  });

  factory WhatsAppLog.fromJson(Map<String, dynamic> json) => WhatsAppLog(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        template: json['template'] as String? ?? '',
        to: json['to'] as String? ?? '',
        status: WhatsAppLogStatus.fromValue(json['status'] as String?),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : null,
        sentAt: json['sent_at'] != null
            ? DateTime.tryParse(json['sent_at'] as String)
            : null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'template': template,
        'to': to,
        'status': status.value,
        'payload': payload,
        'sent_at': sentAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
