import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/snag.dart';
import '../data/repositories/snag_report_service.dart';
import '../providers/quality_providers.dart';
import 'snag_detail_screen.dart';

/// Lists the snags (defects / punch-list) raised against a project. Lets the
/// user raise a new snag with an optional "before" photo and export a snag
/// report PDF.
class SnagsScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? projectName;

  const SnagsScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  ConsumerState<SnagsScreen> createState() => _SnagsScreenState();
}

class _SnagsScreenState extends ConsumerState<SnagsScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final snags = ref.watch(projectSnagsProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snags'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exporting
                ? null
                : () => _exportPdf(snags.asData?.value ?? const []),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRaiseSnagSheet(context),
        icon: const Icon(Icons.report_problem_outlined),
        label: const Text('Raise Snag'),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(projectSnagsProvider(widget.projectId)),
        child: snags.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _CenterMessage(
            icon: Icons.error_outline,
            color: AppColors.error,
            title: 'Failed to load snags',
            message: e.toString(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _CenterMessage(
                icon: Icons.verified_outlined,
                color: AppColors.textHint,
                title: 'No snags',
                message:
                    'Raise a snag to track defects and rework on this project.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
              itemBuilder: (_, i) => _SnagCard(
                snag: list[i],
                onTap: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => SnagDetailScreen(
                          projectId: widget.projectId,
                          snagId: list[i].id,
                        ),
                      ),
                    )
                    .then((_) =>
                        ref.invalidate(projectSnagsProvider(widget.projectId))),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _exportPdf(List<Snag> snags) async {
    setState(() => _exporting = true);
    try {
      await SnagReportService.generateAndShare(
        projectName: widget.projectName ?? 'Project',
        snags: snags,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showRaiseSnagSheet(BuildContext context) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController();
    SnagPriority priority = SnagPriority.medium;
    Uint8List? photoBytes;
    String? photoName;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> pickPhoto() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png'],
                withData: true,
              );
              if (result != null && result.files.single.bytes != null) {
                setSheetState(() {
                  photoBytes = result.files.single.bytes;
                  photoName = result.files.single.name;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.s4,
                right: AppSpacing.s4,
                top: AppSpacing.s4,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.s4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raise Snag', style: AppTextStyles.titleLarge),
                    const SizedBox(height: AppSpacing.s4),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)'),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                          labelText: 'Location (optional)',
                          hintText: 'e.g. Block A, 2nd floor'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text('Priority', style: AppTextStyles.labelMedium),
                    const SizedBox(height: AppSpacing.s2),
                    Wrap(
                      spacing: AppSpacing.s2,
                      children: SnagPriority.values.map((p) {
                        final selected = p == priority;
                        return ChoiceChip(
                          label: Text(p.label),
                          selected: selected,
                          selectedColor: p.color.withValues(alpha: 0.18),
                          onSelected: (_) =>
                              setSheetState(() => priority = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _BeforePhotoPicker(
                      bytes: photoBytes,
                      name: photoName,
                      onPick: pickPhoto,
                      onClear: () => setSheetState(() {
                        photoBytes = null;
                        photoName = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) return;
                                final profile = ref.read(userProfileProvider);
                                final companyId = profile?.companyId;
                                if (companyId == null) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('No company found for user.')),
                                  );
                                  return;
                                }
                                setSheetState(() => saving = true);
                                try {
                                  final repo =
                                      ref.read(snagRepositoryProvider);
                                  final snag = await repo.createSnag(
                                    companyId: companyId,
                                    projectId: widget.projectId,
                                    title: title,
                                    description: descController.text.trim(),
                                    location: locationController.text.trim(),
                                    priority: priority,
                                    raisedBy: profile?.id,
                                  );
                                  if (photoBytes != null) {
                                    await repo.uploadSnagPhoto(
                                      companyId: companyId,
                                      projectId: widget.projectId,
                                      snagId: snag.id,
                                      bytes: photoBytes!,
                                      fileName: photoName ?? 'before.jpg',
                                      kind: SnagPhotoKind.before,
                                      uploadedBy: profile?.id,
                                    );
                                  }
                                  ref.invalidate(projectSnagsProvider(
                                      widget.projectId));
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                } catch (e) {
                                  setSheetState(() => saving = false);
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Could not raise snag: $e')),
                                    );
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Raise Snag'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BeforePhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? name;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _BeforePhotoPicker({
    required this.bytes,
    required this.name,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.memory(
              bytes!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              name ?? 'Before photo',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClear,
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: onPick,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text('Add before photo'),
    );
  }
}

class _SnagCard extends StatelessWidget {
  final Snag snag;
  final VoidCallback onTap;

  const _SnagCard({required this.snag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBefore = snag.beforePhotos.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBefore)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    snag.beforePhotos.first.photoUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _photoPlaceholder(),
                  ),
                )
              else
                _photoPlaceholder(),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snag.title,
                      style: AppTextStyles.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (snag.location != null &&
                        snag.location!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 14, color: AppColors.textHint),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              snag.location!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        _Pill(label: snag.priority.label, color: snag.priority.color),
                        const SizedBox(width: AppSpacing.s2),
                        _Pill(label: snag.status.label, color: snag.status.color),
                        const Spacer(),
                        if (snag.createdAt != null)
                          Text(
                            DateFormat('dd MMM').format(snag.createdAt!),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textHint),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.image_outlined,
            size: 22, color: AppColors.textHint),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: 2),
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
