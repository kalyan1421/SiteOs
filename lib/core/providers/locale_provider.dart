import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locale / vernacular-language scaffolding for SiteOS (AKS-69, Phase 1).
///
/// Holds the app-wide [Locale] and lets the user switch between English and the
/// supported Indian vernacular languages. The selection is persisted in-memory
/// for this session only — `shared_preferences` is intentionally NOT a
/// dependency yet, so we do not add it here. When `shared_preferences` is added
/// to the project later, swap the `_PersistedLocaleStore` implementation for a
/// real one (see TODO below) without touching the rest of the app.
///
/// Wiring: `MaterialApp` reads `ref.watch(localeProvider)` for its `locale`
/// argument. The language picker screen calls
/// `ref.read(localeProvider.notifier).setLocale(...)`.

/// A single selectable app language.
///
/// `nativeName` is shown in the picker in the language's own script so users can
/// recognise it regardless of the current UI language.
@immutable
class AppLanguage {
  const AppLanguage({
    required this.locale,
    required this.englishName,
    required this.nativeName,
  });

  final Locale locale;

  /// Name in English (for accessibility / fallback labelling).
  final String englishName;

  /// Endonym — the language's name written in its own script.
  final String nativeName;

  String get code => locale.languageCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLanguage &&
          runtimeType == other.runtimeType &&
          locale.languageCode == other.locale.languageCode;

  @override
  int get hashCode => locale.languageCode.hashCode;
}

/// The languages SiteOS offers in the picker.
///
/// English + the four highest-priority vernaculars for the launch markets.
/// Only English and Hindi have full ARB translations in Phase 1; the remaining
/// languages are listed so the picker is complete and the scaffolding is ready
/// for their ARB files to be dropped in later.
const List<AppLanguage> kSupportedLanguages = <AppLanguage>[
  AppLanguage(
    locale: Locale('en'),
    englishName: 'English',
    nativeName: 'English',
  ),
  AppLanguage(
    locale: Locale('hi'),
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
  ),
  AppLanguage(
    locale: Locale('ta'),
    englishName: 'Tamil',
    nativeName: 'தமிழ்',
  ),
  AppLanguage(
    locale: Locale('te'),
    englishName: 'Telugu',
    nativeName: 'తెలుగు',
  ),
  AppLanguage(
    locale: Locale('mr'),
    englishName: 'Marathi',
    nativeName: 'मराठी',
  ),
];

/// The list of [Locale]s to pass to `MaterialApp.supportedLocales`.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('en'),
  Locale('hi'),
  Locale('ta'),
  Locale('te'),
  Locale('mr'),
];

/// Default locale when nothing has been chosen yet.
const Locale kDefaultLocale = Locale('en');

/// In-memory store for the chosen locale.
///
/// Survives provider invalidation within a session but NOT app restarts, since
/// `shared_preferences` is not yet a dependency. Centralised here so the
/// persistence backend can be swapped in one place.
class _PersistedLocaleStore {
  Locale _locale = kDefaultLocale;

  Locale get locale => _locale;

  void save(Locale locale) {
    _locale = locale;
    // TODO(AKS-69): once `shared_preferences` is a dependency, persist here:
    //   final prefs = await SharedPreferences.getInstance();
    //   await prefs.setString('app_locale', locale.languageCode);
  }
}

final _localeStore = _PersistedLocaleStore();

/// Manages the active app [Locale].
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_localeStore.locale);

  /// Set the active locale. Ignores unsupported locales.
  void setLocale(Locale locale) {
    if (!_isSupported(locale)) return;
    if (locale.languageCode == state.languageCode) return;
    _localeStore.save(locale);
    state = locale;
  }

  /// Convenience: set the locale from a 2-letter language code (e.g. `'hi'`).
  void setLanguageCode(String code) => setLocale(Locale(code));

  /// Reset to the default app locale.
  void reset() => setLocale(kDefaultLocale);

  bool _isSupported(Locale locale) => kSupportedLocales
      .any((l) => l.languageCode == locale.languageCode);
}

/// App-wide active locale. `MaterialApp.locale` watches this.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

/// The currently-selected [AppLanguage] (resolved from [localeProvider]).
///
/// Falls back to English if the active locale somehow has no matching entry.
final currentLanguageProvider = Provider<AppLanguage>((ref) {
  final locale = ref.watch(localeProvider);
  return kSupportedLanguages.firstWhere(
    (lang) => lang.locale.languageCode == locale.languageCode,
    orElse: () => kSupportedLanguages.first,
  );
});
