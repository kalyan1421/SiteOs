import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../core/config/supabase_client.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/cache_registry.dart';
import '../../../core/services/local_database_service.dart';
import '../../../core/services/offline_queue_service.dart';
import '../../../core/services/session_manager.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_repository_provider.dart';

/// User role enum
enum UserRole {
  superAdmin('super_admin'),
  admin('admin'),
  siteManager('site_manager');

  final String value;
  const UserRole(this.value);

  static UserRole? fromString(String? role) {
    if (role == null) return null;
    return UserRole.values.firstWhere(
      (r) => r.value == role,
      orElse: () => UserRole.siteManager,
    );
  }

  /// Check if this role has higher privileges than another
  bool hasHigherPrivilegeThan(UserRole other) {
    const hierarchy = [
      UserRole.siteManager,
      UserRole.admin,
      UserRole.superAdmin,
    ];
    return hierarchy.indexOf(this) > hierarchy.indexOf(other);
  }

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.siteManager:
        return 'Site Manager';
    }
  }
}

/// App auth state model (renamed to avoid conflict with Supabase AuthState)
class AppAuthState {
  final supabase.User? user;
  final UserRole? role;
  final UserProfileModel? profile;
  final bool isLoading;
  final String? statusMessage;
  final String? error;
  final bool isInitialized;

  const AppAuthState({
    this.user,
    this.role,
    this.profile,
    this.isLoading = false,
    this.statusMessage,
    this.error,
    this.isInitialized = false,
  });

  bool get isAuthenticated => user != null;
  bool get hasProfile => profile != null;

  /// Check if user has required role
  bool hasRole(UserRole requiredRole) => role == requiredRole;

  /// Check if user has any of the required roles
  bool hasAnyRole(List<UserRole> allowedRoles) =>
      role != null && allowedRoles.contains(role);

  /// Check if user is at least the given role level
  bool isAtLeast(UserRole minRole) {
    if (role == null) return false;
    const hierarchy = [
      UserRole.siteManager,
      UserRole.admin,
      UserRole.superAdmin,
    ];
    return hierarchy.indexOf(role!) >= hierarchy.indexOf(minRole);
  }

  AppAuthState copyWith({
    supabase.User? user,
    UserRole? role,
    UserProfileModel? profile,
    bool? isLoading,
    String? statusMessage,
    String? error,
    bool? isInitialized,
    bool clearUser = false,
    bool clearError = false,
    bool clearStatus = false,
  }) {
    return AppAuthState(
      user: clearUser ? null : (user ?? this.user),
      role: clearUser ? null : (role ?? this.role),
      profile: clearUser ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  String toString() {
    return 'AppAuthState(user: ${user?.email}, role: ${role?.value}, isLoading: $isLoading, statusMessage: $statusMessage, isAuthenticated: $isAuthenticated)';
  }
}

/// Auth state notifier - uses repository pattern
class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _repository;
  final Ref _ref;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthNotifier(this._repository, this._ref) : super(const AppAuthState()) {
    _init();
  }

  /// Initialize auth listener
  void _init() {
    // Keep the listener, it's good for realtime updates (logout elsewhere)
    _authSubscription = _repository.authStateChanges.listen(
      (data) async {
        final session = data.session;

        // Only react to stream changes if we are ALREADY initialized
        // or if this is the first definitive event.
        if (state.isInitialized) {
          if (session != null && state.user?.id != session.user.id) {
            await _loadUserProfile(session.user);
          } else if (session == null) {
            state = const AppAuthState(
              user: null,
              role: null,
              profile: null,
              isInitialized: true, // Keep it true
            );
          }
        }
      },
      onError: (error) {
        logger.e('Auth state stream error: $error');
      },
    );

    // This is the critical function for app startup
    _checkInitialSession();
  }

  /// Check for existing session on app start
  Future<void> _checkInitialSession() async {
    try {
      // Add a tiny delay to ensure Supabase local storage is ready
      // explicitly on mobile devices sometimes this is instant,
      // sometimes needs a microtask.
      await Future.delayed(Duration.zero);

      final session = _repository.currentSession;
      if (session != null) {
        await _loadUserProfile(session.user);
      } else {
        // Explicitly set initialized to true so Router knows to redirect to Login
        state = state.copyWith(isInitialized: true, user: null);
      }
    } catch (e) {
      // Even on error, we must mark initialized so the app doesn't hang on splash
      state = state.copyWith(isInitialized: true, error: e.toString());
    }
  }

  /// Load user profile and role from database
  Future<void> _loadUserProfile(supabase.User user) async {
    try {
      final profile = await _repository.getUserProfile(user.id);
      final role = UserRole.fromString(profile?.role);

      state = AppAuthState(
        user: user,
        role: role ?? UserRole.siteManager,
        profile: profile,
        isLoading: false,
        isInitialized: true,
      );

      logger.i('User profile loaded: ${role?.value}');
    } catch (e) {
      logger.e('Failed to load user profile: $e');

      // User exists but profile doesn't - set default role
      state = AppAuthState(
        user: user,
        role: UserRole.siteManager,
        profile: null,
        isLoading: false,
        isInitialized: true,
        error: 'Profile not found. Using default role.',
      );
    }
  }

  /// Sign in with email and password
  Future<void> signIn({required String email, required String password}) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        statusMessage: 'Verifying credentials...',
      );

      // Add a slight delay for better UX visibility of the first step
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await _repository.signIn(
        SignInRequest(email: email, password: password),
      );

      if (!result.isSuccess) {
        throw AppAuthException(result.error ?? 'Sign in failed');
      }

      state = state.copyWith(statusMessage: 'Fetching user profile...');
      await Future.delayed(const Duration(milliseconds: 300));

      final role = UserRole.fromString(result.profile?.role);

      state = state.copyWith(statusMessage: 'Finalizing session...');
      await Future.delayed(const Duration(milliseconds: 200));

      state = AppAuthState(
        user: result.user,
        role: role ?? UserRole.siteManager,
        profile: result.profile,
        isLoading: false,
        isInitialized: true,
        statusMessage: null,
      );

      logger.i('User signed in: ${result.user!.email}');
    } on AppAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        clearStatus: true,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
        clearStatus: true,
      );
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        statusMessage: 'Creating your account...',
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final result = await _repository.signUp(
        SignUpRequest(
          email: email,
          password: password,
          fullName: fullName,
          phone: phone,
        ),
      );

      if (!result.isSuccess) {
        throw AppAuthException(result.error ?? 'Sign up failed');
      }

      state = state.copyWith(statusMessage: 'Setting up your workspace...');
      await Future.delayed(const Duration(milliseconds: 400));

      state = AppAuthState(
        user: result.user,
        role: UserRole.siteManager, // Default role for new users
        profile: result.profile,
        isLoading: false,
        isInitialized: true,
      );

      logger.i('User signed up: ${result.user!.email}');
    } on AppAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } on DatabaseException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      rethrow;
    }
  }

  /// Create a new site manager as admin (without affecting admin's session)
  Future<UserProfileModel> createSiteManager({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? position,
    String? address,
  }) async {
    try {
      final profile = await _repository.createUserAsAdmin(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        position: position,
        address: address,
        role: 'site_manager',
      );

      logger.i('Site manager created: $email');
      return profile;
    } on AppAuthException catch (e) {
      logger.e('Failed to create site manager: ${e.message}');
      rethrow;
    } catch (e) {
      logger.e('Failed to create site manager: $e');
      throw AppAuthException('Failed to create site manager');
    }
  }

  /// Sign out and tear down all per-user state.
  ///
  /// On sign out we must purge anything that could leak between users:
  /// - Supabase session (server-side)
  /// - Hive caches (projects, bills, materials, etc.)
  /// - Offline queue (pending writes attributed to the signed-out user)
  /// - In-memory provider state (invalidated via container.invalidate)
  ///
  /// We invalidate the *root* provider containers — `authRepositoryProvider`
  /// rebuilds will cascade through dependent providers since they all
  /// `.watch(...)` upstream chains.
  Future<void> signOut() async {
    try {
      await _repository.signOut();

      // Per-user durable caches.
      await LocalDatabaseService.instance.clearAll();

      // Drop any pending offline writes — they belong to the previous user.
      try {
        await OfflineQueueService.instance.clear();
      } catch (e) {
        // Service may not be initialized in some tests; non-fatal.
        logger.w('Offline queue clear skipped: $e');
      }

      // Invalidate the broad feature roots. Family providers (e.g. by
      // projectId) clean up via .autoDispose when no widget watches them.
      _invalidateFeatureCaches();

      state = const AppAuthState(
        user: null,
        role: null,
        profile: null,
        isLoading: false,
        isInitialized: true,
      );
      logger.i('User signed out and all per-user caches cleared');
    } catch (e) {
      logger.e('Sign out failed: $e');
      rethrow;
    }
  }

  /// Invalidates feature provider roots so any in-memory state from the
  /// previous user is dropped.
  ///
  /// Repositories that hold their own in-memory caches expose a
  /// `clearCaches()` method we can hit via a registry on
  /// [CacheRegistry]. Family providers that use `.autoDispose` will
  /// naturally drop when the router redirects to /login and no widget
  /// watches them.
  void _invalidateFeatureCaches() {
    // Drop any process-level caches held by repository singletons.
    CacheRegistry.instance.clearAll();

    // Force the auth repository (root of the dependency graph) to
    // rebuild. Anything that watches it will recompute on next access.
    try {
      _ref.invalidate(authRepositoryProvider);
    } catch (_) {
      // Ignore in tests where ref may not be live.
    }

    logger.d('Sign-out: feature caches cleared');
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        statusMessage: 'Sending reset link...',
      );
      await _repository.resetPassword(PasswordResetRequest(email: email));
      state = state.copyWith(isLoading: false, clearStatus: true);
      logger.i('Password reset email sent');
    } on AppAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message, clearStatus: true);
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      await _repository.updatePassword(
        PasswordUpdateRequest(newPassword: newPassword),
      );
      state = state.copyWith(isLoading: false);
      logger.i('Password updated');
    } on AppAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (state.user == null) return;

    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();

      final updatedProfile = await _repository.updateUserProfile(
        userId: state.user!.id,
        updates: updates,
      );

      state = state.copyWith(profile: updatedProfile, isLoading: false);

      logger.i('Profile updated');
    } on DatabaseException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    }
  }

  /// Refresh session
  Future<void> refreshSession() async {
    try {
      final session = await _repository.refreshSession();
      if (session?.user != null) {
        await _loadUserProfile(session!.user);
      }
    } catch (e) {
      logger.e('Session refresh failed: $e');
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Auth state provider - uses repository
/// Uses ref.onDispose() for proper cleanup of stream subscriptions
final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final notifier = AuthNotifier(repository, ref);

  // Start session health check when provider is created
  SessionManager.instance.startHealthCheck();

  // Properly dispose resources when provider is disposed
  ref.onDispose(() {
    SessionManager.instance.stopHealthCheck();
    logger.d('AuthProvider disposed, stream subscription cancelled');
  });

  // Keep the provider alive to prevent premature disposal
  ref.keepAlive();

  return notifier;
});

/// Convenience providers
final currentUserProvider = Provider<supabase.User?>((ref) {
  return ref.watch(authProvider).user;
});

final userRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).role;
});

final userProfileProvider = Provider<UserProfileModel?>((ref) {
  return ref.watch(authProvider).profile;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final isAuthLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});

final isAuthInitializedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isInitialized;
});
