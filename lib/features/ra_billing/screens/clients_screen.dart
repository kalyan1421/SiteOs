import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../data/models/client.dart';
import '../providers/ra_billing_providers.dart';
import '../widgets/billing_widgets.dart';
import 'client_form.dart';

/// Lists billing clients with add / edit / delete.
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final clientsAsync = ref.watch(clientsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.clients)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ClientForm.show(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newClient),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => BillingErrorState(
          error: e,
          onRetry: () => ref.invalidate(clientsProvider),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return BillingEmptyState(
              icon: Icons.business_outlined,
              title: 'No clients yet',
              message:
                  'Add the employers / customers you raise RA bills for. GSTIN '
                  'and state code drive CGST/SGST vs IGST.',
              action: FilledButton.icon(
                onPressed: () => ClientForm.show(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.addFirstClient),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clientsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s4),
              itemCount: clients.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.s3),
              itemBuilder: (context, i) =>
                  _ClientTile(client: clients[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ClientTile extends ConsumerWidget {
  final BillingClient client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s1),
        title: Text(client.name, style: AppTextStyles.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((client.gstin ?? '').isNotEmpty)
              Text('GSTIN: ${client.gstin}', style: AppTextStyles.mono),
            if ((client.stateCode ?? '').isNotEmpty)
              Text('State: ${client.stateCode}',
                  style: AppTextStyles.bodySmall),
            if ((client.contactPerson ?? '').isNotEmpty)
              Text(client.contactPerson!, style: AppTextStyles.bodySmall),
          ],
        ),
        isThreeLine: (client.gstin ?? '').isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              ClientForm.show(context, existing: client);
            } else if (v == 'delete') {
              final ok = await _confirmDelete(context);
              if (ok == true) {
                await ref
                    .read(raBillingRepositoryProvider)
                    .deleteClient(client.id);
                ref.invalidate(clientsProvider);
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
          ],
        ),
        onTap: () => ClientForm.show(context, existing: client),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text('Remove "${client.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
