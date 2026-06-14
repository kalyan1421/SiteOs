import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/subscription/screens/trial_expired_screen.dart';
import '../../features/dashboard/screens/site_manager_management_screen.dart';
import '../../features/dashboard/screens/add_site_manager_screen.dart';
import '../../features/dashboard/screens/staff_directory_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/dashboard/screens/super_admin_dashboard.dart';
import '../../features/dashboard/screens/admin_dashboard_shell.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';
import '../../features/dashboard/screens/site_manager_dashboard.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/projects/screens/project_list_screen.dart';
import '../../features/projects/screens/create_project_screen.dart';
import '../../features/projects/screens/project_detail_screen.dart';
import '../../features/blueprints/screens/blueprint_files_screen.dart';
import '../../features/blueprints/screens/blueprint_viewer_screen.dart';
import '../../features/blueprints/data/models/blueprint_model.dart';
import '../../features/inventory/screens/stock_list_screen.dart';
import '../../features/vendors/screens/vendors_list_screen.dart';
import '../../features/inventory/screens/daily_material_log_screen.dart';
import '../../features/labour/screens/labour_roster_screen.dart';
import '../../features/labour/screens/attendance_screen.dart';
import '../../features/projects/screens/project_operations_screen.dart';
import '../../features/inventory/screens/supplier_list_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/bills/screens/bills_screen.dart';
import '../../features/bills/screens/create_bill_screen.dart';
import '../../features/bills/screens/admin_approval_queue_screen.dart';
import '../../features/bills/screens/bills_bin_screen.dart';
import '../../features/materials/screens/materials_tab_screen.dart';
import '../../features/materials/screens/material_master_list_screen.dart';
import '../../features/materials/screens/material_receive_screen.dart';
import '../../features/materials/screens/material_consume_screen.dart';
import '../../features/materials/screens/stock_ledger_screen.dart';
import '../../features/materials/screens/receipt_detail_screen.dart';
import '../../features/machinery/screens/machinery_tab_screen.dart';
import '../../features/machinery/screens/machinery_log_screen.dart';
import '../../features/machinery/screens/machinery_master_screen.dart';
import '../../features/labour/screens/labour_master_screen.dart';
import '../../features/labour/screens/labour_tab_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/projects/screens/project_site_photos_screen.dart';
import 'route_param_guard.dart';
// ── Phase 1–3 feature screens ──
import '../../features/subscription/data/models/plan.dart';
import '../../features/subscription/widgets/plan_guard.dart';
import '../../features/quality/screens/checklist_templates_screen.dart';
import '../../features/quality/screens/project_checklists_screen.dart';
import '../../features/quality/screens/snags_screen.dart';
import '../../features/boq/screens/boq_list_screen.dart';
import '../../features/boq/screens/boq_detail_screen.dart';
import '../../features/boq/screens/boq_vs_actual_screen.dart';
import '../../features/ra_billing/screens/ra_bill_list_screen.dart';
import '../../features/ra_billing/screens/clients_screen.dart';
import '../../features/ra_billing/screens/gst_config_screen.dart';
import '../../features/whatsapp/screens/whatsapp_settings_screen.dart';
import '../../features/settings/screens/language_picker_screen.dart';
import '../../features/ai/screens/invoice_scan_screen.dart';
import '../../features/ai/screens/daily_report_screen.dart';
import '../../features/ai/screens/voice_report_screen.dart';
import '../../features/ai/screens/ai_boq_wizard.dart';
import '../../features/ai/screens/ai_chat_screen.dart';
import '../../features/client_portal/screens/client_dashboard.dart';
import '../../features/client_portal/screens/client_project_screen.dart';
import '../../features/client_portal/screens/client_photos_screen.dart';
import '../../features/client_portal/screens/client_billing_screen.dart';
import '../../features/gps_attendance/screens/geofence_setup_screen.dart';
import '../../features/gps_attendance/screens/gps_checkin_screen.dart';
import '../../features/purchase/screens/indents_screen.dart';
import '../../features/purchase/screens/po_list_screen.dart';
import '../../features/rera/screens/rera_dashboard_screen.dart';
import '../../features/rera/screens/rera_report_form.dart';
import '../../features/subcontractor/screens/subcontractors_screen.dart';
import '../../features/dashboard/screens/more_tools_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: _AuthStateNotifier(ref),
    redirect: (context, state) {
      if (!authState.isInitialized) {
        return null;
      }

      final isAuthenticated = authState.isAuthenticated;
      final userRole = authState.role;
      final isSplashRoute = state.matchedLocation == '/splash';

      final publicRoutes = ['/login', '/register', '/forgot-password'];
      final isPublicRoute = publicRoutes.contains(state.matchedLocation);

      if (!isAuthenticated && !isPublicRoute) {
        return '/login';
      }

      if (isAuthenticated) {
        if (isSplashRoute || isPublicRoute) {
          // Keep a just-registered user on /register until their company is
          // created there (then the screen routes onward to the dashboard).
          if (state.matchedLocation == '/register' &&
              authState.profile?.companyId == null) {
            return null;
          }
          return _getRoleBasedRoute(userRole ?? UserRole.siteManager);
        }

        if (userRole == null) {
          return null;
        }

        final path = state.uri.path;

        // Client role is sandboxed to /client/* — block access to all
        // staff-facing routes so a client token cannot browse the shell.
        if (userRole == UserRole.client && !path.startsWith('/client/')) {
          return '/client/dashboard';
        }

        if (_requiresSuperAdmin(path) && userRole != UserRole.superAdmin) {
          return _getRoleBasedRoute(userRole);
        }

        if (_requiresAdmin(path) && !_isAdminRole(userRole)) {
          return _getRoleBasedRoute(userRole);
        }

        if (path == '/site-manager/dashboard' &&
            userRole != UserRole.siteManager) {
          return _getRoleBasedRoute(userRole);
        }
      }

      return null;
    },
    routes: [
      // ── Public Routes ──
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/trial-expired',
        name: 'trial-expired',
        builder: (context, state) => const TrialExpiredScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Super Admin (no shell) ──
      GoRoute(
        path: '/super-admin/dashboard',
        name: 'super-admin-dashboard',
        builder: (context, state) => const SuperAdminDashboard(),
      ),

      // ── Client Portal (AKS-81) — read-only, builder's clients ──
      GoRoute(
        path: '/client/dashboard',
        name: 'client-dashboard',
        builder: (context, state) => const ClientDashboard(),
      ),
      GoRoute(
        path: '/client/project/:projectId',
        name: 'client-project',
        builder: (context, state) =>
            ClientProjectScreen(projectId: state.pathParameters['projectId']!),
      ),
      GoRoute(
        path: '/client/project/:projectId/photos',
        name: 'client-photos',
        builder: (context, state) =>
            ClientPhotosScreen(projectId: state.pathParameters['projectId']!),
      ),
      GoRoute(
        path: '/client/project/:projectId/billing',
        name: 'client-billing',
        builder: (context, state) =>
            ClientBillingScreen(projectId: state.pathParameters['projectId']!),
      ),

      // ── Authenticated Shell ──
      // All routes inside here get the sidebar (desktop) or bottom nav (mobile)
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/admin/dashboard',
            name: 'admin-dashboard',
            builder: (context, state) => const AdminDashboard(),
          ),
          GoRoute(
            path: '/site-manager/dashboard',
            name: 'site-manager-dashboard',
            builder: (context, state) => const SiteManagerDashboard(),
          ),

          // Profile
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),

          // Tools hub — surfaces all global Phase 1–3 modules
          GoRoute(
            path: '/tools',
            name: 'tools',
            builder: (context, state) => const MoreToolsScreen(),
          ),

          // Reports
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),

          // Admin management
          GoRoute(
            path: '/admin/site-managers',
            name: 'admin-site-managers',
            builder: (context, state) =>
                const SiteManagerManagementScreen(),
          ),
          GoRoute(
            path: '/admin/site-managers/add',
            name: 'admin-add-site-manager',
            builder: (context, state) => const AddSiteManagerScreen(),
          ),
          GoRoute(
            path: '/admin/staff-directory',
            name: 'admin-staff-directory',
            builder: (context, state) => const StaffDirectoryScreen(),
          ),

          // Master data
          GoRoute(
            path: '/suppliers',
            name: 'suppliers',
            builder: (context, state) => const SupplierListScreen(),
          ),
          GoRoute(
            path: '/master/vendors',
            name: 'master-vendors',
            builder: (context, state) => const SupplierListScreen(),
          ),
          GoRoute(
            path: '/machinery',
            name: 'machinery',
            builder: (context, state) => const MachineryMasterScreen(),
          ),
          GoRoute(
            path: '/master/machinery',
            name: 'master-machinery',
            builder: (context, state) => const MachineryMasterScreen(),
          ),
          GoRoute(
            path: '/master/labour',
            name: 'master-labour',
            builder: (context, state) => const LabourMasterScreen(),
          ),
          GoRoute(
            path: '/master/materials',
            name: 'master-materials',
            builder: (context, state) => const MaterialMasterListScreen(),
          ),
          GoRoute(
            path: '/vendors',
            name: 'vendors',
            builder: (context, state) => const VendorsListScreen(),
          ),

          // Bills
          GoRoute(
            path: '/bills',
            name: 'bills',
            builder: (context, state) => const BillsScreen(),
            routes: [
              GoRoute(
                path: 'create',
                name: 'create-bill',
                builder: (context, state) => const CreateBillScreen(),
              ),
              GoRoute(
                path: 'approval-queue',
                name: 'admin-approval-queue',
                builder: (context, state) =>
                    const AdminApprovalQueueScreen(),
              ),
              GoRoute(
                path: 'bin',
                name: 'bills-bin',
                builder: (context, state) => const BillsBinScreen(),
              ),
            ],
          ),

          // Projects
          GoRoute(
            path: '/projects',
            name: 'projects',
            builder: (context, state) => const ProjectListScreen(),
          ),
          GoRoute(
            path: '/projects/create',
            name: 'create-project',
            builder: (context, state) => const CreateProjectScreen(),
          ),
          GoRoute(
            path: '/projects/:id',
            name: 'project-detail',
            builder: (context, state) => RouteParamGuard.uuid(
              state.pathParameters['id'],
              (id) => ProjectDetailScreen(projectId: id),
              label: 'project',
            ),
            routes: [
              GoRoute(
                path: 'blueprints',
                name: 'project-blueprints',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return BlueprintFilesScreen(projectId: projectId);
                },
                routes: [
                  GoRoute(
                    path: 'view/:fileId',
                    name: 'project-blueprint-viewer',
                    builder: (context, state) {
                      final blueprint = state.extra as Blueprint?;
                      if (blueprint == null) {
                        return Scaffold(
                          appBar: AppBar(
                            title: const Text('Blueprint'),
                            elevation: 0,
                          ),
                          body: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 48, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                const Text(
                                  'Blueprint data not available',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please navigate from the files list',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return BlueprintViewerScreen(blueprint: blueprint);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'stock',
                name: 'project-stock',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  final projectName =
                      (state.extra as String?) ?? 'Project';
                  return StockListScreen(
                    projectId: projectId,
                    projectName: projectName,
                  );
                },
              ),
              GoRoute(
                path: 'material-log',
                name: 'project-material-log',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  final projectName =
                      (state.extra as String?) ?? 'Project';
                  return DailyMaterialLogScreen(
                    projectId: projectId,
                    projectName: projectName,
                  );
                },
              ),
              GoRoute(
                path: 'labour',
                name: 'project-labour',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  final projectName =
                      (state.extra as String?) ?? 'Project';
                  return LabourRosterScreen(
                    projectId: projectId,
                    projectName: projectName,
                  );
                },
              ),
              GoRoute(
                path: 'attendance',
                name: 'project-attendance',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  final projectName =
                      (state.extra as String?) ?? 'Project';
                  return AttendanceScreen(
                    projectId: projectId,
                    projectName: projectName,
                  );
                },
              ),
              GoRoute(
                path: 'operations',
                name: 'project-operations',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return ProjectOperationsScreen(projectId: projectId);
                },
                routes: [
                  GoRoute(
                    path: 'materials',
                    name: 'project-materials',
                    builder: (context, state) {
                      final projectId = state.pathParameters['id']!;
                      return MaterialsTabScreen(projectId: projectId);
                    },
                  ),
                  GoRoute(
                    path: 'machinery',
                    name: 'project-machinery',
                    builder: (context, state) {
                      final projectId = state.pathParameters['id']!;
                      return MachineryTabScreen(projectId: projectId);
                    },
                  ),
                  GoRoute(
                    path: 'labour',
                    name: 'project-labour-tab',
                    builder: (context, state) {
                      final projectId = state.pathParameters['id']!;
                      return LabourTabScreen(projectId: projectId);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'materials/receive',
                name: 'material-receive',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return MaterialReceiveScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: 'materials/consume',
                name: 'material-consume',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return MaterialConsumeScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: 'materials/stock',
                name: 'material-stock',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return StockLedgerScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: 'materials/receipt/:receiptId',
                name: 'receipt-detail',
                builder: (context, state) {
                  final receiptId = state.pathParameters['receiptId']!;
                  return ReceiptDetailScreen(receiptId: receiptId);
                },
              ),
              GoRoute(
                path: 'machinery/log',
                name: 'machinery-log',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return MachineryLogScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: 'labour/daily-attendance',
                name: 'labour-daily-attendance',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  final projectName =
                      (state.extra as String?) ?? 'Project';
                  return AttendanceScreen(
                    projectId: projectId,
                    projectName: projectName,
                  );
                },
              ),
              GoRoute(
                path: 'reports',
                name: 'project-reports',
                builder: (context, state) {
                  final projectId = state.pathParameters['id'];
                  return ReportsScreen(projectId: projectId);
                },
              ),
              GoRoute(
                path: 'photos',
                name: 'project-photos',
                builder: (context, state) {
                  final projectId = state.pathParameters['id']!;
                  return ProjectSitePhotosScreen(projectId: projectId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/projects/:id/edit',
            name: 'edit-project',
            builder: (context, state) {
              final projectId = state.pathParameters['id']!;
              return CreateProjectScreen(projectId: projectId);
            },
          ),

          // ── QA/QC Snag Lists (AKS-70) ──
          GoRoute(
            path: '/quality/templates',
            name: 'quality-templates',
            builder: (context, state) => const ChecklistTemplatesScreen(),
          ),
          GoRoute(
            path: '/projects/:id/quality/checklists',
            name: 'project-checklists',
            builder: (context, state) => ProjectChecklistsScreen(
                projectId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/projects/:id/quality/snags',
            name: 'project-snags',
            builder: (context, state) =>
                SnagsScreen(projectId: state.pathParameters['id']!),
          ),

          // ── BOQ / Estimation (AKS-72, Professional) ──
          GoRoute(
            path: '/projects/:id/boq',
            name: 'boq-list',
            builder: (context, state) => PlanGuard(
              feature: AppFeature.boqModule,
              child: BoqListScreen(projectId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/projects/:id/boq/:boqId',
            name: 'boq-detail',
            builder: (context, state) => PlanGuard(
              feature: AppFeature.boqModule,
              child: BoqDetailScreen(
                projectId: state.pathParameters['id']!,
                boqId: state.pathParameters['boqId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/projects/:id/boq/:boqId/vs-actual',
            name: 'boq-vs-actual',
            builder: (context, state) => PlanGuard(
              feature: AppFeature.boqModule,
              child: BoqVsActualScreen(
                projectId: state.pathParameters['id']!,
                boqId: state.pathParameters['boqId']!,
              ),
            ),
          ),

          // ── GST / RA Billing + Tally (AKS-73, Professional) ──
          GoRoute(
            path: '/ra-billing',
            name: 'ra-billing',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.gstBilling, child: RaBillListScreen()),
          ),
          GoRoute(
            path: '/ra-billing/clients',
            name: 'ra-billing-clients',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.gstBilling, child: ClientsScreen()),
          ),
          GoRoute(
            path: '/ra-billing/gst-config',
            name: 'ra-billing-gst-config',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.gstBilling, child: GstConfigScreen()),
          ),

          // ── WhatsApp (AKS-71, Starter+) ──
          GoRoute(
            path: '/settings/whatsapp',
            name: 'whatsapp-settings',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.whatsapp, child: WhatsAppSettingsScreen()),
          ),

          // ── Language (AKS-69) ──
          GoRoute(
            path: '/settings/language',
            name: 'language-picker',
            builder: (context, state) => const LanguagePickerScreen(),
          ),

          // ── AI Suite (AKS-75..79, Professional) ──
          GoRoute(
            path: '/ai/invoice-scan',
            name: 'ai-invoice-scan',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.aiFeatures, child: InvoiceScanScreen()),
          ),
          GoRoute(
            path: '/ai/daily-report',
            name: 'ai-daily-report',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.aiFeatures, child: DailyReportScreen()),
          ),
          GoRoute(
            path: '/ai/voice-report',
            name: 'ai-voice-report',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.aiFeatures, child: VoiceReportScreen()),
          ),
          GoRoute(
            path: '/ai/boq',
            name: 'ai-boq',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.aiFeatures, child: AiBoqWizard()),
          ),
          GoRoute(
            path: '/ai/chat',
            name: 'ai-chat',
            builder: (context, state) => const PlanGuard(
                feature: AppFeature.aiFeatures, child: AiChatScreen()),
          ),

          // ── GPS / Geofence Attendance (AKS-82) ──
          GoRoute(
            path: '/gps-attendance/geofence-setup',
            name: 'geofence-setup',
            builder: (context, state) => const GeofenceSetupScreen(),
          ),
          GoRoute(
            path: '/gps-attendance/check-in',
            name: 'gps-checkin',
            builder: (context, state) => const GpsCheckinScreen(),
          ),

          // ── Purchase Orders (AKS-83) ──
          GoRoute(
            path: '/purchase/indents',
            name: 'purchase-indents',
            builder: (context, state) => const IndentsScreen(),
          ),
          GoRoute(
            path: '/purchase/orders',
            name: 'purchase-orders',
            builder: (context, state) => const PoListScreen(),
          ),

          // ── RERA Reporting (AKS-84) ──
          GoRoute(
            path: '/rera',
            name: 'rera',
            builder: (context, state) => const ReraDashboardScreen(),
          ),
          GoRoute(
            path: '/rera/report/new',
            name: 'rera-report-new',
            builder: (context, state) => const ReraReportForm(),
          ),

          // ── Subcontractor Management (AKS-85) ──
          GoRoute(
            path: '/subcontractors',
            name: 'subcontractors',
            builder: (context, state) => const SubcontractorsScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 20),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textHint,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final authState = ProviderScope.containerOf(context)
                    .read(authProvider);
                if (authState.isAuthenticated && authState.role != null) {
                  context.go(
                      _getRoleBasedRoute(authState.role!));
                } else {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

String _getRoleBasedRoute(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return '/super-admin/dashboard';
    case UserRole.admin:
      return '/admin/dashboard';
    case UserRole.siteManager:
      return '/site-manager/dashboard';
    case UserRole.client:
      return '/client/dashboard';
  }
}

bool _isAdminRole(UserRole role) {
  return role == UserRole.admin || role == UserRole.superAdmin;
}

bool _requiresSuperAdmin(String path) {
  return path.startsWith('/super-admin');
}

bool _requiresAdmin(String path) {
  if (path.startsWith('/admin')) return true;
  if (path.startsWith('/master')) return true;

  const adminOnlyRoutes = {
    '/machinery',
    '/reports',
    '/suppliers',
    '/vendors',
    '/bills/approval-queue',
    '/bills/bin',
    '/projects/create',
  };
  if (adminOnlyRoutes.contains(path)) return true;

  return path.startsWith('/projects/') && path.endsWith('/edit');
}

class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.role != next.role ||
          previous?.isInitialized != next.isInitialized) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;
}
