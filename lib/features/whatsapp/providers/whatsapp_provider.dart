import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/models/whatsapp_config.dart';
import '../data/models/whatsapp_log.dart';
import '../data/models/whatsapp_preferences.dart';
import '../data/repositories/whatsapp_repository.dart';

/// Singleton repository for the WhatsApp feature.
final whatsAppRepositoryProvider =
    Provider<WhatsAppRepository>((ref) => WhatsAppRepository());

/// The signed-in user's company id (null when no profile is loaded).
final _companyIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider)?.companyId;
});

/// Connection status for the current company's WhatsApp integration.
final whatsAppConfigProvider = FutureProvider<WhatsAppConfig>((ref) async {
  final companyId = ref.watch(_companyIdProvider);
  if (companyId == null) {
    throw StateError('No company found for the current user.');
  }
  return ref.watch(whatsAppRepositoryProvider).fetchConfig(companyId);
});

/// The current company's daily-report preferences.
final whatsAppPreferencesProvider =
    FutureProvider<WhatsAppPreferences>((ref) async {
  final companyId = ref.watch(_companyIdProvider);
  if (companyId == null) {
    throw StateError('No company found for the current user.');
  }
  return ref.watch(whatsAppRepositoryProvider).fetchPreferences(companyId);
});

/// Recent outbound message log for the current company (newest first).
final whatsAppLogsProvider = FutureProvider<List<WhatsAppLog>>((ref) async {
  final companyId = ref.watch(_companyIdProvider);
  if (companyId == null) return const [];
  return ref.watch(whatsAppRepositoryProvider).fetchLogs(companyId);
});

/// Controller for mutating preferences + sending a test message. Exposes a
/// loading flag so the settings screen can disable buttons while busy.
class WhatsAppController extends StateNotifier<AsyncValue<void>> {
  WhatsAppController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  WhatsAppRepository get _repo => _ref.read(whatsAppRepositoryProvider);

  /// Persist updated preferences and refresh the providers.
  Future<bool> savePreferences(WhatsAppPreferences prefs) async {
    state = const AsyncValue.loading();
    try {
      await _repo.savePreferences(prefs);
      _ref.invalidate(whatsAppPreferencesProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Send a test message to [to] via the edge function. Returns null on
  /// success, or a human-readable error message on failure.
  Future<String?> sendTest(String to) async {
    state = const AsyncValue.loading();
    try {
      await _repo.sendTest(to: to);
      _ref.invalidate(whatsAppLogsProvider);
      state = const AsyncValue.data(null);
      return null;
    } on WhatsAppSendException catch (e, st) {
      state = AsyncValue.error(e, st);
      return e.message;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return e.toString();
    }
  }
}

final whatsAppControllerProvider =
    StateNotifierProvider<WhatsAppController, AsyncValue<void>>(
  (ref) => WhatsAppController(ref),
);
