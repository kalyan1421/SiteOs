import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../theme/app_colors.dart';

/// A slim banner that surfaces unsynced state at the top of the shell.
///
/// Polls [OfflineQueueService.pendingCount] every 2 seconds and animates
/// in/out when the count crosses zero. Tap to retry sync.
class SyncBanner extends StatefulWidget {
  const SyncBanner({super.key});

  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner> {
  Timer? _ticker;
  int _pending = 0;
  bool _offline = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  void _refresh() {
    var changed = false;
    try {
      final count = OfflineQueueService.instance.pendingCount;
      if (count != _pending) {
        _pending = count;
        changed = true;
      }
    } catch (_) {/* queue not initialized */}

    final offlineNow = ConnectivityService.instance.isOffline;
    if (offlineNow != _offline) {
      _offline = offlineNow;
      changed = true;
    }

    if (changed && mounted) setState(() {});
  }

  Future<void> _retry() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await OfflineQueueService.instance.processQueue();
    } catch (_) {
      // Errors are logged inside the service.
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        _refresh();
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _offline || _pending > 0;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: !visible ? const SizedBox.shrink() : _buildBanner(),
    );
  }

  Widget _buildBanner() {
    // Offline overrides pending-only state for clearer messaging.
    final bgColor = _offline
        ? AppColors.error.withValues(alpha: 0.12)
        : AppColors.warningLight;
    final fgColor =
        _offline ? AppColors.errorDark : AppColors.warningDark;

    final message = _syncing
        ? 'Syncing $_pending pending '
            '${_pending == 1 ? "change" : "changes"}…'
        : _offline
            ? _pending > 0
                ? 'Offline · $_pending '
                    '${_pending == 1 ? "change" : "changes"} '
                    'will sync when reconnected'
                : 'You\'re offline · changes will sync automatically'
            : '$_pending offline '
                '${_pending == 1 ? "change" : "changes"} '
                'pending sync';

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: _syncing || _offline ? null : _retry,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: _syncing
                      ? CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                        )
                      : Icon(
                          _offline
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_off_rounded,
                          size: 16,
                          color: fgColor,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (!_syncing && !_offline && _pending > 0)
                  Text(
                    'TAP TO RETRY',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                      letterSpacing: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
