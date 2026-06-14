import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/supabase_client.dart' show logger;
import 'offline_queue_service.dart';

/// Watches device connectivity and triggers a flush of the offline
/// queue whenever the device comes back online.
///
/// Initialize once from `main()`:
///
/// ```dart
/// await ConnectivityService.instance.init();
/// ```
///
/// The service holds a single subscription to [Connectivity.onConnectivityChanged]
/// and is otherwise stateless from the app's perspective.
class ConnectivityService {
  ConnectivityService._();

  static final instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  /// Set up the connectivity listener. Idempotent.
  Future<void> init() async {
    if (_subscription != null) return;

    // Seed initial state so the first event isn't always treated as a
    // transition.
    try {
      final initial = await _connectivity.checkConnectivity();
      _wasOffline = _isOffline(initial);
    } catch (e) {
      logger.w('Initial connectivity check failed: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _onChange,
      onError: (e) => logger.w('Connectivity stream error: $e'),
    );
    logger.i('ConnectivityService initialized (offline=$_wasOffline)');
  }

  bool _isOffline(List<ConnectivityResult> results) {
    // Empty list or only `none` means offline.
    if (results.isEmpty) return true;
    return results.every((r) => r == ConnectivityResult.none);
  }

  Future<void> _onChange(List<ConnectivityResult> results) async {
    final offlineNow = _isOffline(results);

    // Reconnection: was offline, now online → flush queue.
    if (_wasOffline && !offlineNow) {
      logger.i('Network restored — flushing offline queue');
      try {
        await OfflineQueueService.instance.processQueue();
      } catch (e) {
        logger.w('Queue flush on reconnect failed: $e');
      }
    }

    _wasOffline = offlineNow;
  }

  /// Whether the device is currently offline (based on the last
  /// observed state).
  bool get isOffline => _wasOffline;

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
