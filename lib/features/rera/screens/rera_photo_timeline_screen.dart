import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/rera_report.dart';
import '../providers/rera_providers.dart';
import '../widgets/rera_widgets.dart';
import '../../../l10n/app_localizations.dart';

/// Geotagged photo timeline for a project's RERA filing.
///
/// Reuses existing project site photos when a source is available (the
/// repository's [getTimelinePhotos]). A dedicated project-photos table is not
/// in the schema yet (Phase 3+), so this currently renders an informative
/// placeholder; the timeline UI is final and will populate automatically once
/// the repository is pointed at a real source.
class ReraPhotoTimelineScreen extends ConsumerWidget {
  final String projectId;
  final String? projectName;

  const ReraPhotoTimelineScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final photosAsync = ref.watch(reraTimelinePhotosProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.photoTimeline),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.s4, bottom: AppSpacing.s2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                projectName ?? 'Project',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ReraPlaceholder(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load photos",
          message: e.toString(),
          action: OutlinedButton(
            onPressed: () =>
                ref.invalidate(reraTimelinePhotosProvider(projectId)),
            child: Text(l10n.retry),
          ),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return const ReraPlaceholder(
              icon: Icons.add_a_photo_outlined,
              title: 'No geotagged photos yet',
              message:
                  'Geotagged site photos for this project will appear here as '
                  'a chronological timeline. Photo capture for RERA is coming '
                  'in a later phase.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.s4),
            itemCount: photos.length,
            itemBuilder: (context, i) => _TimelineTile(
              photo: photos[i],
              isFirst: i == 0,
              isLast: i == photos.length - 1,
            ),
          );
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ReraTimelinePhoto photo;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.photo,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : AppColors.border,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: _PhotoCard(photo: photo),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final ReraTimelinePhoto photo;
  const _PhotoCard({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: photo.imageUrl == null
                ? Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.image_outlined,
                        size: 36, color: AppColors.textHint),
                  )
                : Image.network(
                    photo.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 36, color: AppColors.textHint),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photo.caption != null && photo.caption!.isNotEmpty) ...[
                  Text(photo.caption!, style: AppTextStyles.titleSmall),
                  const SizedBox(height: AppSpacing.s2),
                ],
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a')
                          .format(photo.capturedAt),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      photo.hasGeotag
                          ? Icons.location_on_outlined
                          : Icons.location_off_outlined,
                      size: 14,
                      color: photo.hasGeotag
                          ? AppColors.success
                          : AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      photo.geotagLabel,
                      style: AppTextStyles.mono.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
