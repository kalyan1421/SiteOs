import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/machinery_provider.dart';
import '../data/models/machinery_model.dart';
import '../../../l10n/app_localizations.dart';

/// Machinery master list with add/edit/delete via bottom sheets
class MachineryMasterScreen extends ConsumerWidget {
  const MachineryMasterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final machineryListAsync = ref.watch(machineryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.machineryMaster),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                ref.invalidate(machineryListProvider);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'refresh', child: Text(l10n.refresh)),
            ],
          ),
        ],
      ),
      body: machineryListAsync.when(
        data: (machinery) {
          if (machinery.isEmpty) {
            return Center(child: Text(l10n.noMachineryAdded));
          }
          return ListView.builder(
            itemCount: machinery.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final item = machinery[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      item.ownershipType == 'Own'
                          ? Icons.handyman
                          : Icons.car_rental,
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.type ?? 'Unknown Type'} - '
                    '${item.registrationNo ?? 'No Reg No'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showFormSheet(context, ref, existing: item);
                          break;
                        case 'delete':
                          _confirmDelete(context, ref, item.id);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                    ],
                  ),
                  onTap: () => _showFormSheet(context, ref, existing: item),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showFormSheet(
    BuildContext context,
    WidgetRef ref, {
    MachineryModel? existing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final typeController = TextEditingController(text: existing?.type ?? '');
    final regController = TextEditingController(
      text: existing?.registrationNo ?? '',
    );
    String ownership = existing?.ownershipType ?? 'Rental';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Add Machinery' : 'Edit Machinery',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: typeController,
                    decoration: const InputDecoration(labelText: 'Type *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: regController,
                    decoration: const InputDecoration(
                      labelText: 'Registration No',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ownership,
                    decoration: const InputDecoration(labelText: 'Ownership'),
                    items: [
                      DropdownMenuItem(value: 'Own', child: Text(l10n.own)),
                      DropdownMenuItem(value: 'Rental', child: Text(l10n.rental)),
                    ],
                    onChanged: (v) => setState(() => ownership = v ?? 'Rental'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isSaving = true);
                            final repo = ref.read(machineryRepositoryProvider);
                            try {
                              if (existing == null) {
                                await repo.createMachinery(
                                  name: nameController.text.trim(),
                                  type: typeController.text.trim(),
                                  registrationNo:
                                      regController.text.trim().isEmpty
                                      ? null
                                      : regController.text.trim(),
                                  ownershipType: ownership,
                                );
                              } else {
                                await repo.updateMachinery(
                                  machineryId: existing.id,
                                  data: {
                                    'name': nameController.text.trim(),
                                    'type': typeController.text.trim(),
                                    'registration_no': regController.text
                                        .trim(),
                                    'ownership_type': ownership,
                                  },
                                );
                              }
                              ref.invalidate(machineryListProvider);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      existing == null
                                          ? 'Machinery added'
                                          : 'Machinery updated',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Save failed: $e')),
                                );
                              }
                            } finally {
                              setState(() => isSaving = false);
                            }
                          },
                    child: Text(existing == null ? 'Save' : 'Update'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMachinery),
        content: const Text(
          'Are you sure you want to delete this machinery item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(machineryRepositoryProvider).deleteMachinery(id);
      ref.invalidate(machineryListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.machineryDeleted)));
      }
    }
  }
}
