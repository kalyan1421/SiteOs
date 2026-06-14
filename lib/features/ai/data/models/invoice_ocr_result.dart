/// Parsed invoice returned by the `ai-invoice-ocr` Edge Function.
class InvoiceLineItem {
  final String description;
  final double? quantity;
  final String? unit;
  final double? rate;
  final double? amount;

  const InvoiceLineItem({
    required this.description,
    this.quantity,
    this.unit,
    this.rate,
    this.amount,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      InvoiceLineItem(
        description: (json['description'] ?? '').toString(),
        quantity: _toDouble(json['quantity']),
        unit: json['unit'] as String?,
        rate: _toDouble(json['rate']),
        amount: _toDouble(json['amount']),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'amount': amount,
      };

  InvoiceLineItem copyWith({
    String? description,
    double? quantity,
    String? unit,
    double? rate,
    double? amount,
  }) =>
      InvoiceLineItem(
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        rate: rate ?? this.rate,
        amount: amount ?? this.amount,
      );
}

class InvoiceOcrResult {
  final String? vendor;
  final String? gstin;
  final String? invoiceNo;
  final String? invoiceDate;
  final List<InvoiceLineItem> lineItems;
  final double? taxAmount;
  final double? total;
  final String currency;

  const InvoiceOcrResult({
    this.vendor,
    this.gstin,
    this.invoiceNo,
    this.invoiceDate,
    this.lineItems = const [],
    this.taxAmount,
    this.total,
    this.currency = 'INR',
  });

  factory InvoiceOcrResult.fromJson(Map<String, dynamic> json) =>
      InvoiceOcrResult(
        vendor: json['vendor'] as String?,
        gstin: json['gstin'] as String?,
        invoiceNo: json['invoice_no'] as String?,
        invoiceDate: json['invoice_date'] as String?,
        lineItems: (json['line_items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => InvoiceLineItem.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(),
        taxAmount: _toDouble(json['tax_amount']),
        total: _toDouble(json['total']),
        currency: (json['currency'] as String?) ?? 'INR',
      );

  Map<String, dynamic> toJson() => {
        'vendor': vendor,
        'gstin': gstin,
        'invoice_no': invoiceNo,
        'invoice_date': invoiceDate,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
        'tax_amount': taxAmount,
        'total': total,
        'currency': currency,
      };

  InvoiceOcrResult copyWith({
    String? vendor,
    String? gstin,
    String? invoiceNo,
    String? invoiceDate,
    List<InvoiceLineItem>? lineItems,
    double? taxAmount,
    double? total,
    String? currency,
  }) =>
      InvoiceOcrResult(
        vendor: vendor ?? this.vendor,
        gstin: gstin ?? this.gstin,
        invoiceNo: invoiceNo ?? this.invoiceNo,
        invoiceDate: invoiceDate ?? this.invoiceDate,
        lineItems: lineItems ?? this.lineItems,
        taxAmount: taxAmount ?? this.taxAmount,
        total: total ?? this.total,
        currency: currency ?? this.currency,
      );
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '').trim());
}
