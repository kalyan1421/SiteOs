/// A single WhatsApp daily-report recipient (name + E.164 phone).
///
/// Stored inside `whatsapp_preferences.recipients` as a JSON array of these
/// objects, e.g. `[{"name":"Site Owner","phone":"+919876543210"}]`.
class WhatsAppRecipient {
  final String name;
  final String phone;

  const WhatsAppRecipient({required this.name, required this.phone});

  factory WhatsAppRecipient.fromJson(Map<String, dynamic> json) =>
      WhatsAppRecipient(
        name: (json['name'] as String?)?.trim() ?? '',
        phone: (json['phone'] as String?)?.trim() ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  WhatsAppRecipient copyWith({String? name, String? phone}) =>
      WhatsAppRecipient(name: name ?? this.name, phone: phone ?? this.phone);

  @override
  bool operator ==(Object other) =>
      other is WhatsAppRecipient && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);
}
