import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/supabase_client.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../models/bill_model.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/utils/upload_helper.dart';

class BillRepository {
  final SupabaseClient _client;
  static const String _billSelectQuery = '''
    *,
    creator:user_profiles!bills_created_by_fkey(id, full_name, email),
    raiser:user_profiles!bills_raised_by_fkey(id, full_name, email),
    approver:user_profiles!bills_approved_by_fkey(id, full_name, email),
    project:projects!bills_project_id_fkey(id, name)
  ''';

  BillRepository({SupabaseClient? client}) : _client = client ?? supabase;

  /// Get bills for a specific project (NOT all bills)
  Future<List<BillModel>> getBillsByProject(
    String projectId, {
    String? status,
  }) async {
    try {
      var query = _client
          .from('bills')
          .select(_billSelectQuery)
          .eq('project_id', projectId)
          .isFilter('deleted_at', null);

      if (status != null) {
        query = query.eq('status', status);
      }

      // Apply sort order at the end
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((json) => BillModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to fetch bills: $e');
    }
  }

  /// Get pending bills with pagination
  Future<List<BillModel>> getPendingBills({
    required String projectId,
    required int offset,
    required int limit,
  }) async {
    try {
      final response = await _client
          .from('bills')
          .select(_billSelectQuery)
          .eq('project_id', projectId)
          .eq('status', 'pending')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => BillModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to fetch pending bills: $e');
    }
  }

  /// Create a new bill
  Future<BillModel> createBill({
    required String projectId,
    required String title,
    required double amount,
    required String billType,
    String? description,
    String? vendorName,
    String? paymentType,
    String? paymentStatus,
    List<int>? receiptBytes,
    String? receiptName,
    DateTime? billDate,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      String? receiptUrl;

      // Upload receipt if provided
      if (receiptBytes != null && receiptName != null) {
        try {
          // bills bucket RLS expects first path segment to be project UUID.
          final relativePath = UploadHelper.generateUniquePath(
            'receipts',
            receiptName,
          );
          final filePath = '$projectId/$relativePath';

          receiptUrl = await UploadHelper.uploadWithRetry(
            bucket: AppConstants.bucketBills,
            path: filePath,
            bytes: Uint8List.fromList(receiptBytes),
            contentType: _contentTypeForFile(receiptName),
          );
        } catch (e) {
          logger.d('Receipt upload failed: $e');
          throw Exception('Receipt upload failed. Please retry the upload.');
        }
      }

      final data = {
        'project_id': projectId,
        'title': title,
        'amount': amount,
        'bill_type': billType,
        'description': description,
        'vendor_name': vendorName,
        'payment_type': paymentType,
        'payment_status': paymentStatus ?? 'need_to_pay',
        'status': 'pending',
        'created_by': userId,
        'uploaded_by': userId,
        'raised_by': userId,
        'image_url': receiptUrl,
        'image_path': receiptUrl,
        'bill_date': (billDate ?? DateTime.now())
            .toIso8601String()
            .split('T')
            .first,
      };

      final response = await _client.from('bills').insert(data).select('''
            *,
            creator:user_profiles!bills_created_by_fkey(id, full_name, email),
            raiser:user_profiles!bills_raised_by_fkey(id, full_name, email)
          ''').single();

      final bill = BillModel.fromJson(response);

      // Log operation for activity feed
      try {
        await _client.rpc(
          'log_operation',
          params: {
            'p_operation_type': 'create',
            'p_entity_type': 'bill',
            'p_entity_id': bill.id,
            'p_title': '[BILL] ${bill.title}',
            'p_description': 'Amount: ₹${bill.amount.toStringAsFixed(2)}',
            'p_project_id': bill.projectId,
          },
        );
      } catch (e) {
        logger.d('log_operation failed for bill: $e');
      }

      // Notify all admins that a new bill needs review
      try {
        final admins = await _client
            .from('user_profiles')
            .select('id')
            .inFilter('role', ['admin', 'super_admin']);
        for (final admin in admins as List) {
          await _insertNotification(
            userId: admin['id'] as String,
            type: 'bill_pending',
            title: 'New Bill Submitted',
            body: '${bill.title} — ₹${bill.amount.toStringAsFixed(0)} pending review',
            entityId: bill.id,
            projectId: bill.projectId,
          );
        }
      } catch (e) {
        logger.d('Admin bill notification failed: $e');
      }

      return bill;
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      logger.d('Bill insert failed: $e');
      throw Exception('Failed to create bill: $e');
    }
  }

  /// Fetch bills baseline (non-realtime)
  Future<List<BillModel>> fetchBills(String projectId, {String? status}) async {
    return getBillsByProject(projectId, status: status);
  }

  /// Get role-based bills across accessible projects.
  /// If [onlyAssignedProjects] is true, returns only bills for assigned projects.
  Future<List<BillModel>> getBillsForDashboard({
    String? status,
    bool onlyAssignedProjects = false,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (onlyAssignedProjects && userId == null) {
        return [];
      }

      String selectQuery = _billSelectQuery;

      if (onlyAssignedProjects && userId != null) {
        selectQuery = '''
          *,
          creator:user_profiles!bills_created_by_fkey(id, full_name, email),
          approver:user_profiles!bills_approved_by_fkey(id, full_name, email),
          project:projects!inner(
            id,
            name,
            project_assignments!inner(user_id)
          )
        ''';
      }

      var query = _client.from('bills').select(selectQuery);

      if (onlyAssignedProjects && userId != null) {
        query = query.eq('project.project_assignments.user_id', userId);
      }

      if (status != null) {
        query = query.eq('status', status);
      }

      query = query.isFilter('deleted_at', null);

      final response = await query
          .order('created_at', ascending: false)
          .limit(500); // safety cap — prevents full-table fetch on large datasets
      return (response as List)
          .map((json) => BillModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to fetch dashboard bills: $e');
    }
  }

  Future<List<BillModel>> fetchBillsForDashboard({
    String? status,
    bool onlyAssignedProjects = false,
  }) {
    return getBillsForDashboard(
      status: status,
      onlyAssignedProjects: onlyAssignedProjects,
    );
  }

  /// Update a bill (only pending bills can be updated by site managers)
  Future<BillModel> updateBill(
    String billId,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    try {
      final response = await _client
          .from('bills')
          .update(updates)
          .eq('id', billId)
          .select('''
            *,
            creator:user_profiles!bills_created_by_fkey(id, full_name, email),
            approver:user_profiles!bills_approved_by_fkey(id, full_name, email),
            project:projects!bills_project_id_fkey(id, name)
          ''')
          .single();

      return BillModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to update bill: $e');
    }
  }

  /// Admin approval workflow update:
  /// - payment status: pending / will pay / paid
  /// - mark completed toggles bill completion
  Future<BillModel> updateBillApproval({
    required String billId,
    required PaymentStatus paymentStatus,
    required bool markCompleted,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final now = DateTime.now().toIso8601String();

    try {
      final response = await _client
          .from('bills')
          .update({
            'payment_status': paymentStatus.value,
            'status': markCompleted ? 'paid' : 'pending',
            'approved_by': userId,
            'approved_at': now,
            'updated_at': now,
          })
          .eq('id', billId)
          .select(_billSelectQuery)
          .single();

      final bill = BillModel.fromJson(response);

      try {
        await _client.rpc(
          'log_operation',
          params: {
            'p_operation_type': 'update',
            'p_entity_type': 'bill',
            'p_entity_id': bill.id,
            'p_title': '[BILL] ${bill.title} updated',
            'p_description':
                'Payment: ${bill.paymentStatus.label}, Completion: ${markCompleted ? 'Completed' : 'Pending'}',
            'p_project_id': bill.projectId,
          },
        );
      } catch (e) {
        logger.d('log_operation failed for bill update: $e');
      }

      final recipientId = bill.raisedBy ?? bill.createdBy;
      if (recipientId != null) {
        final notifType = markCompleted ? 'bill_paid' : 'bill_approved';
        final notifTitle = markCompleted ? 'Bill Paid' : 'Bill Approved';
        final notifBody = markCompleted
            ? '${bill.title} has been marked as paid'
            : '${bill.title} has been approved (${paymentStatus.label})';
        await _insertNotification(
          userId: recipientId,
          type: notifType,
          title: notifTitle,
          body: notifBody,
          entityId: bill.id,
          projectId: bill.projectId,
        );
      }

      return bill;
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to update bill approval: $e');
    }
  }

  /// Approve a bill (Admin only)
  Future<BillModel> approveBill(String billId) async {
    final userId = _client.auth.currentUser?.id;

    try {
      final response = await _client
          .from('bills')
          .update({
            'status': 'approved',
            'approved_by': userId,
            'approved_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', billId)
          .select('''
            *,
            creator:user_profiles!bills_created_by_fkey(id, full_name, email),
            approver:user_profiles!bills_approved_by_fkey(id, full_name, email)
          ''')
          .single();

      return BillModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to approve bill: $e');
    }
  }

  /// Reject a bill (Admin only)
  Future<BillModel> rejectBill(String billId, {String? reason}) async {
    final userId = _client.auth.currentUser?.id;

    try {
      final updateData = <String, dynamic>{
        'status': 'rejected',
        'approved_by': userId,
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }
      final response = await _client
          .from('bills')
          .update(updateData)
          .eq('id', billId)
          .select(_billSelectQuery)
          .single();

      final bill = BillModel.fromJson(response);

      final recipientId = bill.raisedBy ?? bill.createdBy;
      if (recipientId != null) {
        await _insertNotification(
          userId: recipientId,
          type: 'bill_rejected',
          title: 'Bill Rejected',
          body: reason != null && reason.isNotEmpty
              ? '${bill.title} was rejected: $reason'
              : '${bill.title} has been rejected',
          entityId: bill.id,
          projectId: bill.projectId,
        );
      }

      return bill;
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to reject bill: $e');
    }
  }

  Future<void> _insertNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String entityId,
    required String projectId,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': {
          'entity_type': 'bill',
          'entity_id': entityId,
          'project_id': projectId,
        },
        'is_read': false,
      });
    } catch (e) {
      logger.d('Notification insert failed: $e');
    }
  }

  /// Soft-delete a bill (sets deleted_at; keeps the record for the admin bin)
  Future<void> softDeleteBill(String billId) async {
    try {
      await _client
          .from('bills')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', billId);
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to delete bill: $e');
    }
  }

  /// Restore a soft-deleted bill (clears deleted_at)
  Future<void> restoreBill(String billId) async {
    try {
      await _client
          .from('bills')
          .update({'deleted_at': null})
          .eq('id', billId);
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to restore bill: $e');
    }
  }

  /// Permanently hard-delete a bill (admin bin only)
  Future<void> permanentlyDeleteBill(String billId) async {
    try {
      await _client.from('bills').delete().eq('id', billId);
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to permanently delete bill: $e');
    }
  }

  /// Fetch all soft-deleted bills (admin bin view)
  Future<List<BillModel>> fetchDeletedBills() async {
    try {
      final response = await _client
          .from('bills')
          .select(_billSelectQuery)
          .not('deleted_at', 'is', null)
          .order('deleted_at', ascending: false)
          .limit(200);
      return (response as List)
          .map((json) => BillModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException.fromPostgrest(e);
    } catch (e) {
      throw Exception('Failed to fetch deleted bills: $e');
    }
  }

  /// Legacy alias kept for compatibility — delegates to softDeleteBill
  Future<void> deleteBill(String billId) => softDeleteBill(billId);

  /// Stream bills for a single project.
  ///
  /// NOTE: Supabase `.stream()` does not support PostgREST joins, so
  /// realtime payloads arrive with FK columns only (no creator/raiser
  /// names). The combined provider (`billsCombinedProvider`) overlays
  /// streamed updates on top of the initially-joined fetch, and
  /// `_mergeBillSnapshot` preserves the joined names from the fetch.
  Stream<List<BillModel>> streamBillsByProject(
    String projectId, {
    int limit = 200,
  }) {
    return _client
        .from('bills')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data
            .where((json) => json['deleted_at'] == null)
            .map((json) => BillModel.fromJson(json))
            .toList());
  }

  /// Stream bills for the dashboard with a hard cap.
  ///
  /// On a multi-project deployment the bills table can grow into the
  /// thousands; without a `limit` Supabase realtime would replay the
  /// entire table on every event, causing OOM and battery drain.
  ///
  /// Implications:
  /// - The cap means very old bills won't surface here. That's OK —
  ///   the dashboard shows recent activity only. Full history lives
  ///   on `/bills` (paginated) and per-project detail screens.
  /// - Joined fields (creator name, etc.) are not available on stream
  ///   events (Supabase limitation). Use the combined provider for the
  ///   merged view.
  Stream<List<BillModel>> streamBillsForDashboard({
    bool onlyAssignedProjects = false,
    int limit = 200,
  }) async* {
    final userId = _client.auth.currentUser?.id;
    if (onlyAssignedProjects && userId == null) {
      yield [];
      return;
    }

    Set<String> assignedProjectIds = {};
    if (onlyAssignedProjects && userId != null) {
      try {
        final assignments = await _client
            .from('project_assignments')
            .select('project_id')
            .eq('user_id', userId);
        assignedProjectIds = (assignments as List)
            .map((a) => a['project_id'] as String)
            .toSet();
      } catch (e) {
        logger.d('Failed to fetch project assignments for stream: $e');
      }
    }

    yield* _client
        .from('bills')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data
            .where((json) => json['deleted_at'] == null)
            .map((json) => BillModel.fromJson(json))
            .toList())
        .map((items) {
          if (!onlyAssignedProjects || userId == null) {
            return items;
          }
          return items
              .where((bill) => assignedProjectIds.contains(bill.projectId))
              .toList();
        })
        // Supabase throws RealtimeSubscribeException into the stream when the
        // websocket disconnects (app backgrounded). Swallowing it here keeps
        // the StreamProvider in data state so the last snapshot stays visible;
        // the channel resubscribes automatically when the socket reconnects.
        .handleError(
          (Object e) => logger.d('Bills stream paused (websocket disconnect): $e'),
          test: (e) => e is RealtimeSubscribeException,
        );
  }
}

String _contentTypeForFile(String fileName) {
  final extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : 'pdf';

  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}
