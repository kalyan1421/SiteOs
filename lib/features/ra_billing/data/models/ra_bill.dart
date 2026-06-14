import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Lifecycle status of an RA bill.
enum RaBillStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  paid('paid', 'Paid');

  final String value;
  final String label;
  const RaBillStatus(this.value, this.label);

  static RaBillStatus fromString(String? value) => RaBillStatus.values
      .firstWhere((s) => s.value == value, orElse: () => RaBillStatus.pending);

  Color get color {
    switch (this) {
      case RaBillStatus.pending:
        return AppColors.statusPending;
      case RaBillStatus.approved:
        return AppColors.statusCompleted;
      case RaBillStatus.paid:
        return AppColors.statusActive;
    }
  }
}

/// A Running-Account (RA) bill with the full GST / retention / advance / TDS
/// breakdown. Maps to the `ra_bills` table (migration 056_ra_billing.sql).
class RaBill {
  final String id;
  final String companyId;
  final String contractId;
  final String number;
  final DateTime billDate;
  final double cumulativeWorkDone;
  final double previousWorkDone;
  final double thisBillValue;
  final double advanceRecovery;
  final double retention;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double tds;
  final double netPayable;
  final String? notes;
  final RaBillStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined (read-only) fields for display.
  final String? contractName;
  final String? clientName;

  const RaBill({
    required this.id,
    required this.companyId,
    required this.contractId,
    required this.number,
    required this.billDate,
    this.cumulativeWorkDone = 0,
    this.previousWorkDone = 0,
    this.thisBillValue = 0,
    this.advanceRecovery = 0,
    this.retention = 0,
    this.taxableValue = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.tds = 0,
    this.netPayable = 0,
    this.notes,
    this.status = RaBillStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.contractName,
    this.clientName,
  });

  /// True when intra-state (CGST + SGST) rather than inter-state (IGST).
  bool get isIntraState => igst == 0 && (cgst > 0 || sgst > 0);

  double get totalGst => cgst + sgst + igst;

  factory RaBill.fromJson(Map<String, dynamic> json) {
    final contract = json['project_contracts'] as Map<String, dynamic>?;
    final client = contract?['clients'] as Map<String, dynamic>?;
    return RaBill(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      contractId: json['contract_id'] as String,
      number: json['number'] as String? ?? '',
      billDate: json['bill_date'] != null
          ? DateTime.tryParse(json['bill_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      cumulativeWorkDone:
          (json['cumulative_work_done'] as num?)?.toDouble() ?? 0,
      previousWorkDone: (json['previous_work_done'] as num?)?.toDouble() ?? 0,
      thisBillValue: (json['this_bill_value'] as num?)?.toDouble() ?? 0,
      advanceRecovery: (json['advance_recovery'] as num?)?.toDouble() ?? 0,
      retention: (json['retention'] as num?)?.toDouble() ?? 0,
      taxableValue: (json['taxable_value'] as num?)?.toDouble() ?? 0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0,
      tds: (json['tds'] as num?)?.toDouble() ?? 0,
      netPayable: (json['net_payable'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      status: RaBillStatus.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      contractName: contract?['name'] as String?,
      clientName: client?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'contract_id': contractId,
        'number': number,
        'bill_date':
            '${billDate.year.toString().padLeft(4, '0')}-${billDate.month.toString().padLeft(2, '0')}-${billDate.day.toString().padLeft(2, '0')}',
        'cumulative_work_done': cumulativeWorkDone,
        'previous_work_done': previousWorkDone,
        'this_bill_value': thisBillValue,
        'advance_recovery': advanceRecovery,
        'retention': retention,
        'taxable_value': taxableValue,
        'cgst': cgst,
        'sgst': sgst,
        'igst': igst,
        'tds': tds,
        'net_payable': netPayable,
        'notes': notes,
        'status': status.value,
      };

  RaBill copyWith({
    String? id,
    String? companyId,
    String? contractId,
    String? number,
    DateTime? billDate,
    double? cumulativeWorkDone,
    double? previousWorkDone,
    double? thisBillValue,
    double? advanceRecovery,
    double? retention,
    double? taxableValue,
    double? cgst,
    double? sgst,
    double? igst,
    double? tds,
    double? netPayable,
    String? notes,
    RaBillStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? contractName,
    String? clientName,
  }) =>
      RaBill(
        id: id ?? this.id,
        companyId: companyId ?? this.companyId,
        contractId: contractId ?? this.contractId,
        number: number ?? this.number,
        billDate: billDate ?? this.billDate,
        cumulativeWorkDone: cumulativeWorkDone ?? this.cumulativeWorkDone,
        previousWorkDone: previousWorkDone ?? this.previousWorkDone,
        thisBillValue: thisBillValue ?? this.thisBillValue,
        advanceRecovery: advanceRecovery ?? this.advanceRecovery,
        retention: retention ?? this.retention,
        taxableValue: taxableValue ?? this.taxableValue,
        cgst: cgst ?? this.cgst,
        sgst: sgst ?? this.sgst,
        igst: igst ?? this.igst,
        tds: tds ?? this.tds,
        netPayable: netPayable ?? this.netPayable,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        contractName: contractName ?? this.contractName,
        clientName: clientName ?? this.clientName,
      );
}
