import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../auth/providers/auth_provider.dart';

/// Central hub that surfaces every global SiteOS module (Phase 1–3 features)
/// without crowding the bottom navigation. Project-scoped tools (BOQ, QA/QC)
/// live on the project screen instead.
class MoreToolsScreen extends ConsumerWidget {
  const MoreToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final isAdmin = role == UserRole.admin || role == UserRole.superAdmin;

    final sections = <_ToolSection>[
      _ToolSection('Billing & Compliance', adminOnly: true, tools: const [
        _Tool(Icons.receipt_long_rounded, 'RA Billing', 'GST RA bills + Tally export', '/ra-billing'),
        _Tool(Icons.account_balance_rounded, 'GST Config', 'Company GSTIN & bank setup', '/ra-billing/gst-config'),
        _Tool(Icons.groups_2_rounded, 'Clients', 'Client master for billing', '/ra-billing/clients'),
        _Tool(Icons.fact_check_rounded, 'RERA Reporting', 'Quarterly compliance reports', '/rera'),
      ]),
      _ToolSection('Procurement', adminOnly: true, tools: const [
        _Tool(Icons.note_alt_rounded, 'Indents', 'Material purchase requests', '/purchase/indents'),
        _Tool(Icons.shopping_cart_rounded, 'Purchase Orders', 'POs + GRN 3-way match', '/purchase/orders'),
        _Tool(Icons.engineering_rounded, 'Subcontractors', 'Work orders, sub RA bills', '/subcontractors'),
      ]),
      _ToolSection('AI Tools', tools: const [
        _Tool(Icons.document_scanner_rounded, 'Scan Invoice', 'OCR a paper bill', '/ai/invoice-scan'),
        _Tool(Icons.summarize_rounded, 'Daily Report', 'Auto site summary', '/ai/daily-report'),
        _Tool(Icons.mic_rounded, 'Voice Report', 'Speak your daily log (Hindi)', '/ai/voice-report'),
        _Tool(Icons.auto_awesome_rounded, 'AI BOQ', 'Generate a BOQ from inputs', '/ai/boq'),
        _Tool(Icons.chat_rounded, 'Assistant', 'Ask about your project data', '/ai/chat'),
      ]),
      _ToolSection('Quality & Field', tools: [
        if (isAdmin)
          const _Tool(Icons.checklist_rounded, 'Checklist Templates', 'Manage QA/QC templates', '/quality/templates'),
        if (isAdmin)
          const _Tool(Icons.my_location_rounded, 'Geofence Setup', 'Set site GPS boundaries', '/gps-attendance/geofence-setup'),
        const _Tool(Icons.where_to_vote_rounded, 'GPS Check-in', 'Attendance within site geofence', '/gps-attendance/check-in'),
      ]),
      _ToolSection('Settings', tools: [
        if (isAdmin)
          const _Tool(Icons.chat_bubble_rounded, 'WhatsApp', 'Daily reports & alerts', '/settings/whatsapp'),
        const _Tool(Icons.translate_rounded, 'Language', 'App language (हिन्दी, தமிழ்…)', '/settings/language'),
      ]),
    ];

    final visible = sections
        .where((s) => (!s.adminOnly || isAdmin) && s.tools.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s10),
        itemCount: visible.length,
        itemBuilder: (context, i) {
          final section = visible[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                    left: AppSpacing.s1,
                    top: i == 0 ? 0 : AppSpacing.s5,
                    bottom: AppSpacing.s2),
                child: Text(section.title.toUpperCase(),
                    style: AppTextStyles.overline),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (var t = 0; t < section.tools.length; t++) ...[
                      if (t > 0)
                        const Divider(height: 1, indent: 56),
                      _ToolTile(tool: section.tools[t]),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolSection {
  final String title;
  final bool adminOnly;
  final List<_Tool> tools;
  const _ToolSection(this.title, {this.adminOnly = false, required this.tools});
}

class _Tool {
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  const _Tool(this.icon, this.label, this.subtitle, this.route);
}

class _ToolTile extends StatelessWidget {
  final _Tool tool;
  const _ToolTile({required this.tool});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(tool.icon, color: AppColors.primary, size: 20),
      ),
      title: Text(tool.label, style: AppTextStyles.titleSmall),
      subtitle: Text(tool.subtitle,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint),
      onTap: () => context.push(tool.route),
    );
  }
}
