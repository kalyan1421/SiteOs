import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_client.dart';
import '../models/boq_result.dart';
import '../models/chat_message.dart';
import '../models/daily_report_result.dart';
import '../models/invoice_ocr_result.dart';

/// Raised when an AI Edge Function call fails. Carries a user-friendly message.
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// Wraps every Gemini-backed Edge Function. Screens NEVER call
/// `supabase.functions` directly — they go through this repository.
///
/// All AI inference runs server-side (Deno Edge Functions reading
/// GEMINI_API_KEY); the key is never present in the Flutter app.
class AiRepository {
  final SupabaseClient _client;

  AiRepository({SupabaseClient? client}) : _client = client ?? supabase;

  /// Pulls the best user-facing message out of an Edge Function error response.
  String _extractError(dynamic data, [String fallback = 'AI request failed']) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return fallback;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const AiException('AI returned an unexpected response.');
  }

  // ── Invoice OCR (AKS-75) ───────────────────────────────────────────────

  /// Sends a base64 image to `ai-invoice-ocr` and returns the parsed invoice.
  Future<InvoiceOcrResult> scanInvoice({
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-invoice-ocr',
        body: {'image_base64': imageBase64, 'mime_type': mimeType},
      );
      if (res.status != 200) {
        throw AiException(_extractError(res.data, 'Could not read the invoice.'));
      }
      final map = _asMap(res.data);
      final result = _asMap(map['result']);
      return InvoiceOcrResult.fromJson(result);
    } on AiException {
      rethrow;
    } on FunctionException catch (e) {
      throw AiException(_extractError(e.details, 'Could not read the invoice.'));
    } catch (e) {
      logger.e('scanInvoice error: $e');
      throw const AiException('Could not read the invoice. Please try again.');
    }
  }

  // ── Daily report / voice report (AKS-76) ───────────────────────────────

  /// Generates a WhatsApp-ready daily site summary via `ai-daily-report`.
  /// Pass [transcript] for the voice-report flow.
  Future<DailyReportResult> generateDailyReport({
    required String projectId,
    String? date,
    String language = 'en',
    String? transcript,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-daily-report',
        body: {
          'project_id': projectId,
          if (date != null) 'date': date,
          'language': language,
          if (transcript != null && transcript.trim().isNotEmpty)
            'transcript': transcript.trim(),
        },
      );
      if (res.status != 200) {
        throw AiException(
            _extractError(res.data, 'Could not generate the report.'));
      }
      return DailyReportResult.fromJson(_asMap(res.data));
    } on AiException {
      rethrow;
    } on FunctionException catch (e) {
      throw AiException(
          _extractError(e.details, 'Could not generate the report.'));
    } catch (e) {
      logger.e('generateDailyReport error: $e');
      throw const AiException('Could not generate the report. Please try again.');
    }
  }

  // ── BOQ wizard (AKS-78) ────────────────────────────────────────────────

  /// Generates an indicative BOQ via `ai-boq`.
  Future<BoqResult> generateBoq({
    required String projectType,
    required double areaSqft,
    int floors = 1,
    String quality = 'standard',
    String? location,
    String? notes,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-boq',
        body: {
          'project_type': projectType,
          'area_sqft': areaSqft,
          'floors': floors,
          'quality': quality,
          if (location != null && location.isNotEmpty) 'location': location,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      if (res.status != 200) {
        throw AiException(_extractError(res.data, 'Could not generate the BOQ.'));
      }
      final map = _asMap(res.data);
      final result = _asMap(map['result']);
      return BoqResult.fromJson(result);
    } on AiException {
      rethrow;
    } on FunctionException catch (e) {
      throw AiException(_extractError(e.details, 'Could not generate the BOQ.'));
    } catch (e) {
      logger.e('generateBoq error: $e');
      throw const AiException('Could not generate the BOQ. Please try again.');
    }
  }

  // ── Assistant chat (AKS-79) ────────────────────────────────────────────

  /// Asks the assistant a question via `ai-chat`. Optionally persists history.
  Future<String> askAssistant({
    required String question,
    String language = 'en',
    bool save = true,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-chat',
        body: {'question': question, 'language': language, 'save': save},
      );
      if (res.status != 200) {
        throw AiException(_extractError(res.data, 'Could not get an answer.'));
      }
      final map = _asMap(res.data);
      return (map['answer'] ?? '').toString();
    } on AiException {
      rethrow;
    } on FunctionException catch (e) {
      throw AiException(_extractError(e.details, 'Could not get an answer.'));
    } catch (e) {
      logger.e('askAssistant error: $e');
      throw const AiException('Could not get an answer. Please try again.');
    }
  }

  /// Loads persisted chat history (newest last) from `ai_chat_messages`.
  Future<List<ChatMessage>> loadChatHistory({int limit = 50}) async {
    try {
      final rows = await _client
          .from('ai_chat_messages')
          .select('id, role, content, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (rows as List)
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      // Return chronological (oldest first) for display.
      return list.reversed.toList();
    } catch (e) {
      logger.w('loadChatHistory failed (returning empty): $e');
      return const [];
    }
  }

  /// Deletes the caller's chat history.
  Future<void> clearChatHistory() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await _client.from('ai_chat_messages').delete().eq('user_id', uid);
    } catch (e) {
      logger.w('clearChatHistory failed: $e');
    }
  }
}
