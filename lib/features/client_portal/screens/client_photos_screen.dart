import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/client_photo.dart';
import '../providers/client_portal_providers.dart';
import '../widgets/client_state_views.dart';
import '../../../l10n/app_localizations.dart';

/// Read-only progress-photo / document timeline for an assigned project.
class ClientPhotosScreen extends ConsumerWidget {
  final String projectId;
  const ClientPhotosScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final photosAsync = ref.watch(clientPhotosProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.progressPhotos)),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ClientErrorState(
          onRetry: () => ref.invalidate(clientPhotosProvider(projectId)),
          message: "Couldn't load photos.",
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return const ClientEmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'No photos yet',
              message:
                  'Progress photos shared by your builder will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(clientPhotosProvider(projectId).future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: photos.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.s4),
              itemBuilder: (context, i) => _PhotoCard(photo: photos[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final ClientPhoto photo;
  const _PhotoCard({required this.photo});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy · h:mm a');
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
            aspectRatio: 16 / 10,
            child: photo.isImage && photo.url.isNotEmpty
                ? Image.network(
                    photo.url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const ColoredBox(
                        color: AppColors.surfaceVariant,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, _, _) => const _PhotoFallback(),
                  )
                : const _PhotoFallback(isDocument: true),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photo.title != null)
                  Text(photo.title!, style: AppTextStyles.titleSmall),
                if (photo.caption != null) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    photo.caption!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
                if (photo.capturedAt != null) ...[
                  const SizedBox(height: AppSpacing.s2),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: AppSpacing.s1),
                      Text(
                        df.format(photo.capturedAt!.toLocal()),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  final bool isDocument;
  const _PhotoFallback({this.isDocument = false});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(
          isDocument
              ? Icons.description_outlined
              : Icons.image_not_supported_outlined,
          size: 40,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}
