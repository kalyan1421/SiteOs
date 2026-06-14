import 'dart:ui' show PlatformDispatcher;

import 'package:siteos/core/config/app_lifecycle_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'core/config/env.dart';
import 'core/config/supabase_client.dart';
import 'core/providers/global_realtime_sync_provider.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/local_database_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_queue_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

/// Whether Firebase initialized successfully this launch. Guards Crashlytics
/// calls so a missing/failed Firebase init never crashes the app itself.
bool _crashlyticsReady = false;

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase + Crashlytics (best-effort; must never block startup).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _crashlyticsReady = true;

    // Collect crash reports only in release builds to avoid debug noise.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    // Route Flutter framework + async/platform errors to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e, st) {
    logger.w('Crashlytics init skipped: $e');
    logger.d('$st');
  }

  try {
    // Initialize environment variables
    await Env.init();
    logger.i('Environment variables loaded');

    // Validate environment variables
    if (!Env.validate()) {
      throw Exception('Invalid environment configuration');
    }

    // Initialize local database (Hive) for offline caching
    await LocalDatabaseService.init();
    logger.i('Local database initialized');

    // Initialize offline write queue (must run after Hive is ready)
    await OfflineQueueService.init();
    logger.i('Offline queue initialized');

    // Initialize in-app notification meta storage.
    await NotificationService.init();

    // Initialize Supabase
    await SupabaseConfig.initialize();

    // Watch connectivity → flush offline queue on reconnect.
    await ConnectivityService.instance.init();

    // Pre-load Google Fonts to prevent runtime download lag
    GoogleFonts.pendingFonts([
      GoogleFonts.spaceGrotesk(),
      GoogleFonts.inter(),
      GoogleFonts.jetBrainsMono(),
    ]);

    // Run the app
    runApp(ProviderScope(child: SiteOsApp()));
  } catch (e, stackTrace) {
    logger.e('Failed to initialize app', error: e, stackTrace: stackTrace);

    // Report the fatal startup failure if Crashlytics is available.
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'App initialization failed',
        fatal: true,
      );
    }

    // Show error screen
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ErrorApp(error: e.toString()),
      ),
    );
  }
}

/// Main application widget
class SiteOsApp extends ConsumerWidget {
  const SiteOsApp({super.key});

  static final _theme = AppTheme.lightTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(globalRealtimeSyncProvider);

    ref.listen<AsyncValue<AppLifecycleState?>>(appLifecycleProvider, (
      previous,
      next,
    ) {
      next.whenData((state) {
        if (state != null) {
          SupabaseConfig.handleAppLifecycle(state);
          // Re-initialise the global realtime channel on resume so any
          // channels that timed out while backgrounded resubscribe cleanly.
          if (state == AppLifecycleState.resumed) {
            ref.invalidate(globalRealtimeSyncProvider);
          }
        }
      });
    });

    return MaterialApp.router(
      title: 'SiteOS',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

/// Error app widget shown when initialization fails
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'App Initialization Failed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Please check your configuration:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Ensure .env file exists in the project root\n'
                '2. Add SUPABASE_URL and SUPABASE_ANON_KEY\n'
                '3. Verify Supabase project is running\n'
                '4. Run: flutter clean && flutter pub get',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
