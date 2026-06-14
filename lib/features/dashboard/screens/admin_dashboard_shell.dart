import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clivi_management/core/theme/app_colors.dart';
import 'package:clivi_management/core/ui/responsive.dart';
import 'package:clivi_management/core/widgets/sync_banner.dart';
import 'package:clivi_management/features/auth/providers/auth_provider.dart';

class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final authState = ref.watch(authProvider);
    final role = profile?.role ?? authState.role?.value;

    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdminRole = role == 'admin' || role == 'super_admin';
    final location = GoRouterState.of(context).uri.path;

    final homeRoute =
        role == 'site_manager' ? '/site-manager/dashboard' : '/admin/dashboard';

    final destinations = [
      _NavDestination(Icons.home_filled, 'Home', homeRoute),
      const _NavDestination(Icons.business, 'Projects', '/projects'),
      const _NavDestination(Icons.receipt_long, 'Bills', '/bills'),
      if (isAdminRole)
        const _NavDestination(Icons.bar_chart, 'Reports', '/reports'),
      const _NavDestination(Icons.person_outline, 'Profile', '/profile'),
    ];

    final activeIndex = _resolveActiveIndex(location, destinations);

    return LayoutBuilder(
      builder: (context, constraints) {
        final r = R(Size(constraints.maxWidth, constraints.maxHeight));

        // Desktop: always show sidebar
        if (r.useRail) {
          final isExtended = constraints.maxWidth >= 1180;
          return Scaffold(
            body: Row(
              children: [
                RepaintBoundary(
                  child: _DesktopSidebar(
                    destinations: destinations,
                    selectedIndex: activeIndex,
                    extended: isExtended,
                    onSelected: (i) => context.go(destinations[i].route),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          );
        }

        // Mobile: bottom nav on all shell routes (shell is only rendered for authed users)
        return Scaffold(
          // Inner scaffolds handle their own keyboard avoidance — disable here
          // to prevent the bottom nav from double-shifting when a keyboard opens.
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              // SafeArea only top so the banner doesn't overlap the status bar
              const SafeArea(bottom: false, child: SyncBanner()),
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: List.generate(
                          destinations.length,
                          (i) {
                            final selected = i ==
                                activeIndex.clamp(
                                    0, destinations.length - 1);
                            final d = destinations[i];
                            return _BottomNavItem(
                              icon: d.icon,
                              label: d.label,
                              selected: selected,
                              onTap: () => context.go(d.route),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  int _resolveActiveIndex(String location, List<_NavDestination> dests) {
    // Pick the destination whose route is the longest prefix of location.
    // Longest-prefix wins so /bills/approval-queue → Bills, /projects/create → Projects.
    int best = 0;
    int bestLen = 0;
    for (int i = 0; i < dests.length; i++) {
      final route = dests[i].route;
      if (location.startsWith(route) && route.length > bestLen) {
        best = i;
        bestLen = route.length;
      }
    }
    return best;
  }
}

// ── Data ──

class _NavDestination {
  const _NavDestination(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

// ── Desktop Sidebar ──

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final List<_NavDestination> destinations;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 244.0 : 88.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBackground,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            extended ? 16 : 12,
            16,
            extended ? 16 : 12,
            16,
          ),
          child: Column(
            crossAxisAlignment: extended
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              _SidebarHeader(extended: extended),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: destinations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = destinations[index];
                    return _DesktopNavItem(
                      icon: item.icon,
                      label: item.label,
                      selected: index == selectedIndex,
                      extended: extended,
                      onTap: () => onSelected(index),
                    );
                  },
                ),
              ),
              const Divider(color: AppColors.sidebarSurface, height: 1),
              const SizedBox(height: 12),
              _SidebarFooter(extended: extended),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sidebar Header ──

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/logo.png',
        width: 38,
        height: 38,
        fit: BoxFit.contain,
      ),
    );

    if (!extended) {
      return SizedBox(width: 56, height: 44, child: Center(child: logo));
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clivi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.sidebarTextPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav Item ──

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.sidebarTextSecondary;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        );

    final navItem = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.sidebarHoverBg,
        splashColor: AppColors.sidebarSelectedBg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 46,
          padding: EdgeInsets.symmetric(horizontal: extended ? 4 : 0),
          decoration: BoxDecoration(
            color: selected ? AppColors.sidebarSelectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: extended
              ? Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 3,
                      height: selected ? 24 : 0,
                      decoration: BoxDecoration(
                        color: AppColors.sidebarAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: selected ? 10 : 12),
                    Icon(icon, size: 22, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                  ],
                )
              : Center(child: Icon(icon, size: 24, color: foreground)),
        ),
      ),
    );

    return extended ? navItem : Tooltip(message: label, child: navItem);
  }
}

// ── Sidebar Footer ──

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final name =
        (profile?.fullName ?? '').isNotEmpty ? profile!.fullName! : 'User';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    if (!extended) {
      return Center(
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.sidebarSurface,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.sidebarTextPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.sidebarSurface,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.sidebarTextPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.sidebarTextPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (profile?.role != null)
                Text(
                  profile!.role.replaceAll('_', ' ').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.sidebarTextSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Editorial bottom nav item
// ─────────────────────────────────────────────────────────────────────

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.primary : AppColors.textHint;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.surfaceVariant
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(icon, size: 23, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

