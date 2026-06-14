/// An RA / progress bill as seen read-only by a client.
///
/// Maps to `public.bills` rows the client may read via RLS (migration 058).
/// RA bills in this schema live on `bills` with bill_type in
/// ('invoice','income'); the client billing screen shows their status only.
/// Plain Dart class — no codegen.
class ClientBill {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final num amount;
  final String billType; // expense | income | invoice
  final String status; // pending | approved | paid | rejected
  final DateTime? billDate;
  final DateTime? dueDate;

  const ClientBill({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.amount,
    required this.billType,
    required this.status,
    this.billDate,
    this.dueDate,
  });

  factory ClientBill.fromJson(Map<String, dynamic> json) {
    return ClientBill(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Bill',
      description: json['description'] as String?,
      amount: (json['amount'] as num?) ?? 0,
      billType: json['bill_type'] as String? ?? 'invoice',
      status: json['status'] as String? ?? 'pending',
      billDate: _parseDate(json['bill_date']),
      dueDate: _parseDate(json['due_date']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'description': description,
        'amount': amount,
        'bill_type': billType,
        'status': status,
        'bill_date': billDate?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
      };

  ClientBill copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    num? amount,
    String? billType,
    String? status,
    DateTime? billDate,
    DateTime? dueDate,
  }) {
    return ClientBill(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      billType: billType ?? this.billType,
      status: status ?? this.status,
      billDate: billDate ?? this.billDate,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  String get statusLabel => switch (status) {
        'pending' => 'Pending',
        'approved' => 'Approved',
        'paid' => 'Paid',
        'rejected' => 'Rejected',
        _ => status,
      };

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
