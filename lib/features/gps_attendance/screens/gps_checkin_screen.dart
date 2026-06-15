import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/project_geofence.dart';
import '../data/services/location_service.dart';
import '../providers/gps_attendance_providers.dart';
import '../../../l10n/app_localizations.dart';

/// Site screen: take a GPS reading, compute the distance to the selected
/// project's geofence, and allow check-in only when inside the radius.
class GpsCheckinScreen extends ConsumerStatefulWidget {
  const GpsCheckinScreen({super.key});

  @override
  ConsumerState<GpsCheckinScreen> createState() => _GpsCheckinScreenState();
}

class _GpsCheckinScreenState extends ConsumerState<GpsCheckinScreen> {
  String? _selectedProjectId;
  String? _selectedLabourId;

  DeviceLocation? _location;
  double? _distanceM;
  bool _withinFence = false;
  bool _locating = false;
  bool _submitting = false;

  void _onProjectChanged(String? id) {
    setState(() {
      _selectedProjectId = id;
      _selectedLabourId = null;
      _location = null;
      _distanceM = null;
      _withinFence = false;
    });
  }

  Future<void> _checkLocation(ProjectGeofence geofence) async {
    final service = ref.read(locationServiceProvider);
    setState(() => _locating = true);
    try {
      final loc = await service.getCurrentLocation();
      final dist = geofence.distanceMetresTo(loc.lat, loc.lng);
      setState(() {
        _location = loc;
        _distanceM = dist;
        _withinFence = dist <= geofence.radiusM;
      });
    } on LocationFailure catch (e) {
      if (mounted) _showError(e.message, openSettings: e.openSettingsRequired);
    } catch (_) {
      if (mounted) _showError('Could not read your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit(ProjectGeofence geofence) async {
    final loc = _location;
    final dist = _distanceM;
    if (loc == null || dist == null || !_withinFence) return;

    final profile = ref.read(userProfileProvider);
    final companyId = profile?.companyId;
    if (profile == null || companyId == null) {
      _showError('No company on your profile — cannot check in.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(gpsAttendanceRepositoryProvider);
      await repo.recordCheckin(
        companyId: companyId,
        projectId: geofence.projectId,
        labourId: _selectedLabourId,
        userId: profile.id,
        lat: loc.lat,
        lng: loc.lng,
        distanceM: dist,
        withinGeofence: true,
      );
      ref.invalidate(recentCheckinsProvider(geofence.projectId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.checkedInSuccessfully),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {
        _location = null;
        _distanceM = null;
        _withinFence = false;
        _selectedLabourId = null;
      });
    } catch (e) {
      if (mounted) _showError('Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message, {bool openSettings = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        action: openSettings
            ? SnackBarAction(
                label: 'Settings',
                textColor: AppColors.textOnPrimary,
                onPressed: () =>
                    ref.read(locationServiceProvider).openAppSettings(),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projectsAsync = ref.watch(gpsProjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.gpsCheckIn)),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'Could not load projects.',
          onRetry: () => ref.invalidate(gpsProjectsProvider),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const _EmptyView(
              icon: Icons.work_outline_rounded,
              title: 'No projects available',
              subtitle: 'You need an assigned project to check in.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              Text(l10n.project, style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.s2),
              DropdownButtonFormField<String>(
                initialValue: _selectedProjectId,
                isExpanded: true,
                hint: Text(l10n.selectProject),
                items: [
                  for (final p in projects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: _onProjectChanged,
              ),
              const SizedBox(height: AppSpacing.s5),
              if (_selectedProjectId != null)
                _buildProjectSection(_selectedProjectId!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectSection(String projectId) {
    final geofenceAsync = ref.watch(geofenceForProjectProvider(projectId));
    final labourAsync = ref.watch(labourForProjectProvider(projectId));

    return geofenceAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.s8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ErrorView(
        message: "Could not load this project's geofence.",
        onRetry: () => ref.invalidate(geofenceForProjectProvider(projectId)),
      ),
      data: (geofence) {
        if (geofence == null) {
          return const _EmptyView(
            icon: Icons.location_off_rounded,
            title: 'No geofence set',
            subtitle:
                'An admin needs to set up a geofence for this project first.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labourAsync.maybeWhen(
              data: (labour) => labour.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.labourOptional,
                            style: AppTextStyles.labelLarge),
                        const SizedBox(height: AppSpacing.s2),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedLabourId,
                          isExpanded: true,
                          hint: Text(AppLocalizations.of(context)!.checkingInForMyself),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(AppLocalizations.of(context)!.myself),
                            ),
                            for (final l in labour)
                              DropdownMenuItem(
                                  value: l.id, child: Text(l.name)),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedLabourId = v),
                        ),
                        const SizedBox(height: AppSpacing.s5),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            _GeofenceStatusCard(geofence: geofence),
            const SizedBox(height: AppSpacing.s5),
            if (_location != null && _distanceM != null) ...[
              _DistanceCard(
                distanceM: _distanceM!,
                radiusM: geofence.radiusM,
                within: _withinFence,
                accuracyM: _location!.accuracyM,
              ),
              const SizedBox(height: AppSpacing.s5),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _locating ? null : () => _checkLocation(geofence),
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                label: Text(_locating
                    ? 'Reading location…'
                    : _location == null
                        ? 'Check my location'
                        : 'Re-check location'),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_withinFence && !_submitting)
                    ? () => _submit(geofence)
                    : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textOnPrimary),
                      )
                    : const Icon(Icons.how_to_reg_rounded),
                label: Text(_submitting ? 'Checking in…' : 'Check in'),
              ),
            ),
            if (_location != null && !_withinFence)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s3),
                child: Text(
                  'You are outside the allowed radius. Move closer to the '
                  'site to check in.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GeofenceStatusCard extends StatelessWidget {
  final ProjectGeofence geofence;
  const _GeofenceStatusCard({required this.geofence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.place_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  geofence.label?.isNotEmpty == true
                      ? geofence.label!
                      : 'Site geofence',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '${geofence.lat.toStringAsFixed(5)}, '
                  '${geofence.lng.toStringAsFixed(5)} · ${geofence.radiusM} m',
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final double distanceM;
  final int radiusM;
  final bool within;
  final double accuracyM;

  const _DistanceCard({
    required this.distanceM,
    required this.radiusM,
    required this.within,
    required this.accuracyM,
  });

  @override
  Widget build(BuildContext context) {
    final color = within ? AppColors.success : AppColors.error;
    final bg = within ? AppColors.successLight : AppColors.errorLight;
    final fmt = NumberFormat('#,##0');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            within ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  within ? 'Inside geofence' : 'Outside geofence',
                  style: AppTextStyles.titleMedium.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '${fmt.format(distanceM)} m from centre · '
                  'allowed ${fmt.format(radiusM)} m',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  'GPS accuracy ±${fmt.format(accuracyM)} m',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.s4),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.s2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.s4),
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
