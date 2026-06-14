import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../../../core/config/supabase_client.dart';
import '../models/whatsapp_config.dart';
import '../models/whatsapp_log.dart';
import '../models/whatsapp_preferences.dart';

/// All Supabase access for the WhatsApp feature. Screens/providers never touch
/// the `supabase` client directly. RLS scopes every read/write to the caller's
/// company via `current_company_id()` (migration 057).
class WhatsAppRepository {
  static const _configTable = 'whatsapp_config';
  static const _prefsTable = 'whatsapp_preferences';
  static const _logsTable = 'whatsapp_logs';
  static const _sendFunction = 'whatsapp-send';

  /// Fetch the company's connection status, or an empty/unconfigured default.
  Future<WhatsAppConfig> fetchConfig(String companyId) async {
    final row = await supabase
        .from(_configTable)
        .select()
        .eq('company_id', companyId)
        .maybeSingle();
    if (row == null) return WhatsAppConfig.empty(companyId);
    return WhatsAppConfig.fromJson(row);
  }

  /// Fetch the company's daily-report preferences, or sane defaults.
  Future<WhatsAppPreferences> fetchPreferences(String companyId) async {
    final row = await supabase
        .from(_prefsTable)
        .select()
        .eq('company_id', companyId)
        .maybeSingle();
    if (row == null) return WhatsAppPreferences.empty(companyId);
    return WhatsAppPreferences.fromJson(row);
  }

  /// Upsert the company's preferences (one row per company — unique company_id).
  Future<WhatsAppPreferences> savePreferences(
      WhatsAppPreferences prefs) async {
    final row = await supabase
        .from(_prefsTable)
        .upsert(prefs.toJson(), onConflict: 'company_id')
        .select()
        .single();
    return WhatsAppPreferences.fromJson(row);
  }

  /// Recent outbound message log entries for the company (newest first).
  Future<List<WhatsAppLog>> fetchLogs(String companyId, {int limit = 50}) async {
    final rows = await supabase
        .from(_logsTable)
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => WhatsAppLog.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Invoke the `whatsapp-send` edge function to send one template message.
  /// Throws on a non-2xx response so the UI can surface the Meta error.
  Future<void> sendTest({
    required String to,
    String template = 'daily_report',
    List<String> params = const [],
    String language = 'en',
  }) async {
    try {
      final response = await supabase.functions.invoke(
        _sendFunction,
        body: {
          'template': template,
          'to': to,
          'params': params,
          'language': language,
        },
      );

      // The client throws FunctionException for non-2xx, but guard anyway.
      if (response.status >= 400) {
        throw WhatsAppSendException(
          _extractError(response.data, response.status),
          statusCode: response.status,
          details: response.data,
        );
      }
    } on FunctionException catch (e) {
      throw WhatsAppSendException(
        _extractError(e.details, e.status),
        statusCode: e.status,
        details: e.details,
      );
    }
  }

  /// Pull a human-readable message out of an edge-function error body.
  String _extractError(Object? data, int status) {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return 'WhatsApp send failed (HTTP $status)';
  }
}

/// Raised when the edge function rejects a send (config missing, Meta error…).
class WhatsAppSendException implements Exception {
  final String message;
  final int? statusCode;
  final Object? details;

  const WhatsAppSendException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}
