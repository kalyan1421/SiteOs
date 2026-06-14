import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// The application name shown in titles and the app bar.
  ///
  /// In en, this message translates to:
  /// **'SiteOS'**
  String get appTitle;

  /// Primary navigation label for the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Navigation label for the projects section.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// Navigation label for the materials section.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// Navigation label for the labour section.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get labour;

  /// Navigation label for the bills/billing section.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get bills;

  /// Navigation label for the reports section.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// Navigation label for the blueprints section.
  ///
  /// In en, this message translates to:
  /// **'Blueprints'**
  String get blueprints;

  /// Navigation label for the inventory section.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// Navigation label for the machinery section.
  ///
  /// In en, this message translates to:
  /// **'Machinery'**
  String get machinery;

  /// Navigation label for the vendors section.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get vendors;

  /// Navigation label for the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Navigation label for the user profile screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Navigation label for the company management screen.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// Navigation label for the subscription/plan screen.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// Generic save action button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Generic cancel action button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic delete action button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Generic edit action button.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Generic add action button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Generic update action button.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Generic search field placeholder / action.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Generic filter action.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Generic confirm action button.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Generic close action button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Retry action shown on error states.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Generic loading indicator label.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic empty-state message.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// Login action button on the auth screen.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// Logout action.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// Registration action button on the auth screen.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Phone number field label.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Name field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Link to the password reset flow.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Greeting shown on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Dashboard KPI label for total project count.
  ///
  /// In en, this message translates to:
  /// **'Total projects'**
  String get totalProjects;

  /// Dashboard KPI label for active projects.
  ///
  /// In en, this message translates to:
  /// **'Active projects'**
  String get activeProjects;

  /// Dashboard KPI label for bills awaiting action.
  ///
  /// In en, this message translates to:
  /// **'Pending bills'**
  String get pendingBills;

  /// Dashboard section header for the activity feed.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// Settings label for choosing the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Title of the language picker screen.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// Display name for the English language option.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Display name for the Hindi language option (in English).
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
