import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/project_geofence.dart';
import '../data/services/location_service.dart';
import '../providers/gps_attendance_providers.dart';

/// Admin screen: set the geofence (centre + radius) for a project.
///
/// "Use current location" reads the device GPS; lat/lng can also be typed
/// manually. The radius is a slider (50–1000 m). A live preview shows the
/// resulting circle dimensions. (A full map is optional and gated behind a
/// Google Maps API key — see wiringNotes.)
class GeofenceSetupScreen extends ConsumerStatefulWidget {
  const GeofenceSetupScreen({super.key});

  @override
  ConsumerState<GeofenceSetupScreen> createState() =>
      _GeofenceSetupScreenState();
}

class _GeofenceSetupScreenState extends ConsumerState<GeofenceSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _labelController = TextEditingController();

  String? _selectedProjectId;
  double _radius = 200;
  bool _locating = false;
  bool _saving = false;
  bool _loadedExisting = false;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _onProjectChanged(String? projectId) {
    setState(() {
      _selectedProjectId = projectId;
      _loadedExisting = false;
      _latController.clear();
      _lngController.clear();
      _labelController.clear();
      _radius = 200;
    });
  }

  void _applyExisting(ProjectGeofence g) {
    if (_loadedExisting) return;
    _loadedExisting = true;
    _latController.text = g.lat.toStringAsFixed(6);
    _lngController.text = g.lng.toStringAsFixed(6);
    _labelController.text = g.label ?? '';
    setState(() => _radius = g.radiusM.toDouble().clamp(50, 1000));
  }

  Future<void> _useCurrentLocation() async {
    final service = ref.read(locationServiceProvider);
    setState(() => _locating = true);
    try {
      final loc = await service.getCurrentLocation();
      _latController.text = loc.lat.toStringAsFixed(6);
      _lngController.text = loc.lng.toStringAsFixed(6);
      if (mounted) setState(() {});
    } on LocationFailure catch (e) {
      if (!mounted) return;
      _showError(e.message, openSettings: e.openSettingsRequired);
    } catch (_) {
      if (mounted) _showError('Could not read your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_selectedProjectId == null) {
      _showError('Pick a project first.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final profile = ref.read(userProfileProvider);
    final companyId = profile?.companyId;
    if (companyId == null) {
      _showError('No company on your profile — cannot save.');
      return;
    }

    final lat = double.parse(_latController.text.trim());
    final lng = double.parse(_lngController.text.trim());

    setState(() => _saving = true);
    try {
      final repo = ref.read(gpsAttendanceRepositoryProvider);
      await repo.upsertGeofence(
        companyId: companyId,
        projectId: _selectedProjectId!,
        lat: lat,
        lng: lng,
        radiusM: _radius.round(),
        label: _labelController.text.trim(),
        createdBy: profile?.id,
      );
      ref.invalidate(geofenceForProjectProvider(_selectedProjectId!));
      ref.invalidate(geofencesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geofence saved.')),
      );
    } catch (e) {
      if (mounted) _showError('Failed to save geofence: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final projectsAsync = ref.watch(gpsProjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Geofence Setup')),
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
              title: 'No projects yet',
              subtitle: 'Create a project before setting up a geofence.',
            );
          }

          // When a project is selected, prefill from its saved geofence.
          if (_selectedProjectId != null && !_loadedExisting) {
            final existing =
                ref.watch(geofenceForProjectProvider(_selectedProjectId!));
            existing.whenData((g) {
              if (g != null) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _applyExisting(g));
              } else {
                _loadedExisting = true;
              }
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              children: [
                Text('Project', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.s2),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProjectId,
                  isExpanded: true,
                  hint: const Text('Select a project'),
                  items: [
                    for (final p in projects)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: _onProjectChanged,
                ),
                const SizedBox(height: AppSpacing.s5),
                _CoordinatesCard(
                  latController: _latController,
                  lngController: _lngController,
                  labelController: _labelController,
                  locating: _locating,
                  onUseCurrent: _useCurrentLocation,
                ),
                const SizedBox(height: AppSpacing.s5),
                _RadiusCard(
                  radius: _radius,
                  onChanged: (v) => setState(() => _radius = v),
                ),
                const SizedBox(height: AppSpacing.s6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save geofence'),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Tip: Stand at the site centre and tap "Use current '
                  'location" for the most accurate fence.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CoordinatesCard extends StatelessWidget {
  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController labelController;
  final bool locating;
  final VoidCallback onUseCurrent;

  const _CoordinatesCard({
    required this.latController,
    required this.lngController,
    required this.labelController,
    required this.locating,
    required this.onUseCurrent,
  });

  String? _validateLat(String? v) {
    final value = double.tryParse((v ?? '').trim());
    if (value == null) return 'Enter a latitude';
    if (value < -90 || value > 90) return 'Latitude must be -90…90';
    return null;
  }

  String? _validateLng(String? v) {
    final value = double.tryParse((v ?? '').trim());
    if (value == null) return 'Enter a longitude';
    if (value < -180 || value > 180) return 'Longitude must be -180…180';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Centre coordinates', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: latController,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  validator: _validateLat,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: TextFormField(
                  controller: lngController,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  validator: _validateLng,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          TextFormField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. Main gate',
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: locating ? null : onUseCurrent,
              icon: locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(locating ? 'Locating…' : 'Use current location'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusCard extends StatelessWidget {
  final double radius;
  final ValueChanged<double> onChanged;

  const _RadiusCard({required this.radius, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Allowed radius', style: AppTextStyles.titleMedium),
              Text(
                '${radius.round()} m',
                style: AppTextStyles.price.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          Slider(
            value: radius,
            min: 50,
            max: 1000,
            divisions: 19,
            label: '${radius.round()} m',
            onChanged: onChanged,
          ),
          Text(
            'Workers can only check in within this distance of the centre.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

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
      child: child,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.s4),
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
