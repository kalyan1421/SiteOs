import '../config/supabase_client.dart' show logger;

/// A tiny registry that lets repositories hold their own in-memory caches
/// while still being centrally clearable on sign-out.
///
/// Repositories that keep per-process caches (e.g. `_memoryCache` in
/// `ProjectRepository`) call [register] in their constructor, passing a
/// callback that wipes their internal state. `AuthNotifier.signOut`
/// calls [clearAll] to fire every registered callback.
///
/// Why a registry instead of importing repositories from auth?
/// Importing every feature module from auth would create a tangled
/// dependency graph and risk circular imports. A registry inverts the
/// dependency — features register themselves with auth's cleanup hook.
class CacheRegistry {
  CacheRegistry._();

  static final instance = CacheRegistry._();

  final List<void Function()> _clearCallbacks = <void Function()>[];

  /// Register a cache-clear callback. Safe to call multiple times — the
  /// same callback is only registered once (by identity).
  void register(void Function() onClear) {
    if (!_clearCallbacks.contains(onClear)) {
      _clearCallbacks.add(onClear);
    }
  }

  /// Fire every registered callback. Errors in one callback don't
  /// prevent the others from running.
  void clearAll() {
    var cleared = 0;
    for (final cb in _clearCallbacks) {
      try {
        cb();
        cleared++;
      } catch (e) {
        logger.w('CacheRegistry: a clear callback failed: $e');
      }
    }
    logger.d('CacheRegistry: cleared $cleared callback(s)');
  }
}
