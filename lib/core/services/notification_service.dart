import 'package:hive_flutter/hive_flutter.dart';

import '../config/supabase_client.dart' show logger;

/// Tracks per-user "last seen" timestamps for the in-app notifications
/// feed (backed by the `operation_logs` table).
///
/// We don't have a server-side `notifications` table yet. Instead we
/// compute "unread" client-side as: any activity row created after the
/// last time the user opened the notifications panel.
///
/// Stored in a dedicated Hive box keyed by user ID — survives app
/// restarts, isolated per device, cleared on logout via the
/// [LocalDatabaseService.clearAll] sweep.
class NotificationService {
  static const String _boxName = 'notifications_meta';
  static const String _lastSeenPrefix = 'last_seen_';

  static NotificationService? _instance;
  static NotificationService get instance => _instance!;

  late Box<String> _box;

  NotificationService._();

  /// Open the Hive box. Call once from `main()` after `Hive.initFlutter()`.
  static Future<void> init() async {
    _instance = NotificationService._();
    await _instance!._open();
  }

  Future<void> _open() async {
    _box = await Hive.openBox<String>(_boxName);
    logger.i('NotificationService initialized');
  }

  /// Timestamp of the last time [userId] opened the notifications panel.
  /// Returns `DateTime.fromMillisecondsSinceEpoch(0)` if never seen — so
  /// a brand-new user sees every existing log as "unread" on first
  /// load (acceptable since the activity feed is short).
  DateTime getLastSeen(String userId) {
    final raw = _box.get('$_lastSeenPrefix$userId');
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Mark all current notifications as read for [userId] (sets the
  /// last-seen pointer to "now").
  Future<void> markAllRead(String userId) async {
    await _box.put(
      '$_lastSeenPrefix$userId',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Compute unread count given a list of activity timestamps. Caller
  /// passes the timestamps so this stays decoupled from the activity
  /// model (operation_logs).
  int unreadCount(String userId, Iterable<DateTime?> activityTimestamps) {
    final lastSeen = getLastSeen(userId);
    var count = 0;
    for (final t in activityTimestamps) {
      if (t == null) continue;
      if (t.isAfter(lastSeen)) count++;
    }
    return count;
  }

  /// Convenience: clear all stored last-seen pointers (used on
  /// `LocalDatabaseService.clearAll`).
  Future<void> clear() async {
    await _box.clear();
  }
}
