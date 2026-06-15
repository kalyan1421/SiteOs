/// SiteOS subscription plans and the premium features each unlocks.
///
/// Mirrors the `companies.plan` value and the `plan_features` lookup table
/// (migration 052_saas_foundation.sql). Source of truth for PlanGuard.
library;

/// The four SiteOS plan tiers.
enum SiteOsPlan {
  trial('trial', 'Trial', 0),
  starter('starter', 'Starter', 1999),
  professional('professional', 'Professional', 4999),
  enterprise('enterprise', 'Enterprise', -1);

  /// DB value stored in `companies.plan`.
  final String key;

  /// Human label for UI.
  final String label;

  /// Monthly price in ₹. 0 = free trial, -1 = custom (Enterprise).
  final int monthlyPrice;

  const SiteOsPlan(this.key, this.label, this.monthlyPrice);

  static SiteOsPlan fromKey(String? key) => SiteOsPlan.values.firstWhere(
        (p) => p.key == key,
        orElse: () => SiteOsPlan.trial,
      );

  bool get isPaid => this == starter || this == professional;
  bool get isCustomPriced => monthlyPrice < 0;
}

/// A gateable premium capability. The [key] matches a boolean column on
/// `plan_features`.
enum AppFeature {
  gstBilling('gst_billing', 'GST & RA Billing'),
  boqModule('boq_module', 'BOQ & Estimation'),
  aiFeatures('ai_features', 'AI Features'),
  whatsapp('whatsapp', 'WhatsApp Reports'),
  clientPortal('client_portal', 'Client Portal');

  final String key;
  final String label;
  const AppFeature(this.key, this.label);

  /// The lowest plan that unlocks this feature — used for upgrade CTAs.
  SiteOsPlan get requiredPlan => switch (this) {
        AppFeature.whatsapp => SiteOsPlan.starter,
        _ => SiteOsPlan.professional,
      };
}

/// The resolved feature set for a company's current plan (one `plan_features`
/// row). `maxProjects`/`maxUsers` of -1 mean unlimited.
class PlanFeatures {
  final SiteOsPlan plan;
  final int maxProjects;
  final int maxUsers;
  final bool gstBilling;
  final bool boqModule;
  final bool aiFeatures;
  final bool whatsapp;
  final bool clientPortal;
  final String subStatus;
  final DateTime? trialEndsAt;

  const PlanFeatures({
    required this.plan,
    required this.maxProjects,
    required this.maxUsers,
    required this.gstBilling,
    required this.boqModule,
    required this.aiFeatures,
    required this.whatsapp,
    required this.clientPortal,
    this.subStatus = 'trialing',
    this.trialEndsAt,
  });

  bool get unlimitedProjects => maxProjects < 0;
  bool get unlimitedUsers => maxUsers < 0;

  /// True when the subscription/trial is no longer active.
  bool get isExpired {
    if (subStatus == 'expired' || subStatus == 'canceled' || subStatus == 'past_due') {
      return true;
    }
    if (subStatus == 'trialing' && trialEndsAt != null) {
      return DateTime.now().isAfter(trialEndsAt!);
    }
    return false;
  }

  /// Whether [feature] is enabled on this plan.
  bool has(AppFeature feature) => switch (feature) {
        AppFeature.gstBilling => gstBilling,
        AppFeature.boqModule => boqModule,
        AppFeature.aiFeatures => aiFeatures,
        AppFeature.whatsapp => whatsapp,
        AppFeature.clientPortal => clientPortal,
      };

  factory PlanFeatures.fromJson(Map<String, dynamic> json) => PlanFeatures(
        plan: SiteOsPlan.fromKey(json['plan'] as String?),
        maxProjects: (json['max_projects'] as num?)?.toInt() ?? 0,
        maxUsers: (json['max_users'] as num?)?.toInt() ?? 0,
        gstBilling: json['gst_billing'] as bool? ?? false,
        boqModule: json['boq_module'] as bool? ?? false,
        aiFeatures: json['ai_features'] as bool? ?? false,
        whatsapp: json['whatsapp'] as bool? ?? false,
        clientPortal: json['client_portal'] as bool? ?? false,
        subStatus: json['sub_status'] as String? ?? 'trialing',
        trialEndsAt: json['trial_ends_at'] == null
            ? null
            : DateTime.tryParse(json['trial_ends_at'] as String),
      );

  /// Safe defaults used when the plan can't be fetched (offline / error).
  /// Locks every premium feature — fail closed, never grant access on failure.
  factory PlanFeatures.fallback(SiteOsPlan plan) => PlanFeatures(
        plan: plan,
        maxProjects: 3,
        maxUsers: 5,
        gstBilling: false,
        boqModule: false,
        aiFeatures: false,
        whatsapp: false,
        clientPortal: false,
        subStatus: 'trialing',
      );
}
