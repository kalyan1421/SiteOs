import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/snag.dart';
import '../providers/quality_providers.dart';

/// Detail view for a single snag: shows before/after photos, lets the user add
/// an "after" photo, change priority/status, and resolve the snag with notes.
class SnagDetailScreen extends ConsumerWidget {
  final String projectId;
  final String snagId;

  const SnagDetailScreen({
    super.key,
    required this.projectId,
    required this.snagId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snagAsync = ref.watch(snagDetailProvider(snagId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.snag),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(snagDetailProvider(snagId)),
        child: snagAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _CenterMessage(
            icon: Icons.error_outline,
            color: AppColors.error,
            title: 'Failed to load snag',
            message: e.toString(),
          ),
          data: (snag) => _SnagBody(
            projectId: projectId,
            snag: snag,
          ),
        ),
      ),
    );
  }
}

class _SnagBody extends ConsumerStatefulWidget {
  final String projectId;
  final Snag snag;

  const _SnagBody({required this.projectId, required this.snag});

  @override
  ConsumerState<_SnagBody> createState() => _SnagBodyState();
}

class _SnagBodyState extends ConsumerState<_SnagBody> {
  bool _busy = false;

  Snag get snag => widget.snag;

  void _refresh() {
    ref.invalidate(snagDetailProvider(snag.id));
    ref.invalidate(projectSnagsProvider(widget.projectId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        Text(snag.title, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            _Pill(label: snag.priority.label, color: snag.priority.color),
            const SizedBox(width: AppSpacing.s2),
            _Pill(label: snag.status.label, color: snag.status.color),
          ],
        ),
        if (snag.description != null && snag.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(snag.description!, style: AppTextStyles.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.s4),
        _MetaRow(
          icon: Icons.place_outlined,
          label: 'Location',
          value: (snag.location?.isNotEmpty ?? false) ? snag.location! : '—',
        ),
        _MetaRow(
          icon: Icons.schedule,
          label: 'Raised',
          value: snag.createdAt != null
              ? dateFmt.format(snag.createdAt!)
              : '—',
        ),
        if (snag.resolvedAt != null)
          _MetaRow(
            icon: Icons.task_alt,
            label: 'Resolved',
            value: dateFmt.format(snag.resolvedAt!),
          ),
        if (snag.resolutionNotes != null &&
            snag.resolutionNotes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.resolutionNotes,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.successDark)),
                const SizedBox(height: AppSpacing.s1),
                Text(snag.resolutionNotes!, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s6),
        _PhotoSection(
          title: 'Before',
          photos: snag.beforePhotos,
          emptyHint: 'No before photos.',
        ),
        const SizedBox(height: AppSpacing.s5),
        _PhotoSection(
          title: 'After',
          photos: snag.afterPhotos,
          emptyHint: 'No after photos yet.',
          trailing: OutlinedButton.icon(
            onPressed: _busy ? null : _addAfterPhoto,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(l10n.add),
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(l10n.priority, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          children: SnagPriority.values.map((p) {
            return ChoiceChip(
              label: Text(p.label),
              selected: p == snag.priority,
              selectedColor: p.color.withValues(alpha: 0.18),
              onSelected: _busy ? null : (_) => _setPriority(p),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(l10n.status, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.s2),
        Wrap(
          spacing: AppSpacing.s2,
          children: SnagStatus.values.map((s) {
            return ChoiceChip(
              label: Text(s.label),
              selected: s == snag.status,
              selectedColor: s.color.withValues(alpha: 0.18),
              onSelected: _busy ? null : (_) => _setStatus(s),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (!snag.status.isResolved)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _resolve,
              icon: const Icon(Icons.check),
              label: Text(l10n.resolveSnag),
            ),
          ),
        if (_busy) ...[
          const SizedBox(height: AppSpacing.s4),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Future<void> _addAfterPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final profile = ref.read(userProfileProvider);
    final companyId = profile?.companyId;
    if (companyId == null) {
      _showError('No company found for user.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(snagRepositoryProvider).uploadSnagPhoto(
            companyId: companyId,
            projectId: widget.projectId,
            snagId: snag.id,
            bytes: Uint8List.fromList(result.files.single.bytes!),
            fileName: result.files.single.name,
            kind: SnagPhotoKind.after,
            uploadedBy: profile?.id,
          );
      _refresh();
    } catch (e) {
      _showError('Could not upload photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPriority(SnagPriority priority) async {
    if (priority == snag.priority) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(snagRepositoryProvider)
          .updateSnag(snagId: snag.id, priority: priority);
      _refresh();
    } catch (e) {
      _showError('Could not update priority: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(SnagStatus status) async {
    if (status == snag.status) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(snagRepositoryProvider)
          .updateSnag(snagId: snag.id, status: status);
      _refresh();
    } catch (e) {
      _showError('Could not update status: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolve() async {
    final notesController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s4,
            right: AppSpacing.s4,
            top: AppSpacing.s4,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.resolveSnag, style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.s4),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Resolution notes (optional)',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.s4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: Text(l10n.markResolved),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final profile = ref.read(userProfileProvider);
    setState(() => _busy = true);
    try {
      await ref.read(snagRepositoryProvider).resolveSnag(
            snagId: snag.id,
            resolutionNotes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
            resolvedBy: profile?.id,
          );
      _refresh();
    } catch (e) {
      _showError('Could not resolve snag: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final String title;
  final List<SnagPhoto> photos;
  final String emptyHint;
  final Widget? trailing;

  const _PhotoSection({
    required this.title,
    required this.photos,
    required this.emptyHint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppTextStyles.titleSmall),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        if (photos.isEmpty)
          Text(
            emptyHint,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textHint),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.s2),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  photos[i].photoUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 96,
                    height: 96,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textHint),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.s2),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _CenterMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 52, color: color),
        const SizedBox(height: AppSpacing.s4),
        Center(child: Text(title, style: AppTextStyles.titleMedium)),
        const SizedBox(height: AppSpacing.s2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
