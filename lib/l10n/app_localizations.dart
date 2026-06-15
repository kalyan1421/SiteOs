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

  /// Affirmative dialog button.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Navigation back button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Completion action button.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Submit form action.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Approve a request or item.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Reject a request or item.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Restore a deleted item.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Share content action.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Copy content to clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Clear input or content.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Create a new item.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Export data to file.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// Review an item or request.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// View all items action.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// Refresh the current list or screen.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// View an item in detail.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Save unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Generic error message.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Shown when a network connection fails.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// Badge/label for admin-only areas.
  ///
  /// In en, this message translates to:
  /// **'Admin Only'**
  String get adminOnly;

  /// Generic date field label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Generic status label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Priority level label.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// Total amount label.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Generic items label.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// Photos section label.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// Monetary amount field label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// Single project label.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// Billing section label.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;

  /// Overview section label.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// Title for delete confirmation dialogs.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// Warning message for irreversible delete actions.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This action cannot be undone.'**
  String get areYouSureCannotBeUndone;

  /// Placeholder/hint for project selection dropdown.
  ///
  /// In en, this message translates to:
  /// **'Select a project'**
  String get selectProject;

  /// Error shown when a project is required but not chosen.
  ///
  /// In en, this message translates to:
  /// **'No project selected'**
  String get noProjectSelected;

  /// Snackbar message after copying content.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Action to copy item details to clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get copyDetails;

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

  /// Sign-in CTA, used as a link on register screen.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Sign-out button on the trial expired screen.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

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

  /// Link on the register screen to go to login.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// Primary CTA on the registration screen.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// Title and button on the forgot-password screen.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Short CTA to begin the trial.
  ///
  /// In en, this message translates to:
  /// **'Start free trial'**
  String get startFreeTrial;

  /// Full CTA sentence to begin the trial.
  ///
  /// In en, this message translates to:
  /// **'Start your free trial'**
  String get startYourFreeTrial;

  /// Suggestion when login fails with the current email.
  ///
  /// In en, this message translates to:
  /// **'Try a different email'**
  String get tryDifferentEmail;

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

  /// Title of the super-admin dashboard screen.
  ///
  /// In en, this message translates to:
  /// **'Super Admin Dashboard'**
  String get superAdminDashboard;

  /// More Tools section in the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// Navigation link back to the main dashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get backToDashboard;

  /// Button to create a new project.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get createProject;

  /// Button to delete a project.
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get deleteProject;

  /// Snackbar confirmation after deleting a project.
  ///
  /// In en, this message translates to:
  /// **'Project deleted'**
  String get projectDeleted;

  /// Generic quality label (e.g. step name in BOQ wizard).
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// Label for the QA/QC checklists section.
  ///
  /// In en, this message translates to:
  /// **'Quality Checklists'**
  String get qualityChecklists;

  /// Label for the snag/defect list.
  ///
  /// In en, this message translates to:
  /// **'Snags'**
  String get snags;

  /// Confirmation after updating a project status.
  ///
  /// In en, this message translates to:
  /// **'Status updated successfully'**
  String get statusUpdatedSuccessfully;

  /// Button to update the project completion percentage.
  ///
  /// In en, this message translates to:
  /// **'Update Completion %'**
  String get updateCompletionPct;

  /// Label for the BOQ and estimation section on project operations.
  ///
  /// In en, this message translates to:
  /// **'BOQ & Estimation'**
  String get boqEstimation;

  /// Action to log material usage on a project.
  ///
  /// In en, this message translates to:
  /// **'Log Materials'**
  String get logMaterials;

  /// Action to log material consumption.
  ///
  /// In en, this message translates to:
  /// **'Log Consumption'**
  String get logConsumption;

  /// Section/screen title for project detail view.
  ///
  /// In en, this message translates to:
  /// **'Project Details'**
  String get projectDetails;

  /// Button to add a new material to the master list.
  ///
  /// In en, this message translates to:
  /// **'Add Master Material'**
  String get addMasterMaterial;

  /// Action to attach a delivery challan or photo.
  ///
  /// In en, this message translates to:
  /// **'Attach Challan / Photo'**
  String get attachChallanPhoto;

  /// Action to browse for PDF or image files.
  ///
  /// In en, this message translates to:
  /// **'Browse Files (PDF / Image)'**
  String get browseFilesPdfImage;

  /// Action to select a photo from the device gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// Action to take a new photo with the camera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Confirmation after logging material consumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption logged successfully'**
  String get consumptionLoggedSuccessfully;

  /// Action to delete a material grade.
  ///
  /// In en, this message translates to:
  /// **'Delete Grade'**
  String get deleteGrade;

  /// Label for quantity of materials received at site.
  ///
  /// In en, this message translates to:
  /// **'Inward quantity'**
  String get inwardQuantity;

  /// Screen title for viewing material details.
  ///
  /// In en, this message translates to:
  /// **'Material Details'**
  String get materialDetails;

  /// Screen title for the full material master list.
  ///
  /// In en, this message translates to:
  /// **'Material Master List'**
  String get materialMasterList;

  /// Confirmation after logging a material receipt.
  ///
  /// In en, this message translates to:
  /// **'Materials received successfully'**
  String get materialsReceivedSuccessfully;

  /// Empty state for the material master list.
  ///
  /// In en, this message translates to:
  /// **'No master materials found.'**
  String get noMasterMaterialsFound;

  /// Empty state when material search returns nothing.
  ///
  /// In en, this message translates to:
  /// **'No materials found'**
  String get noMaterialsFound;

  /// Validation error when required fields are missing.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields in all entries'**
  String get fillAllRequiredFields;

  /// Action to rename a material grade.
  ///
  /// In en, this message translates to:
  /// **'Rename Grade'**
  String get renameGrade;

  /// Screen title for the stock ledger.
  ///
  /// In en, this message translates to:
  /// **'Stock Ledger'**
  String get stockLedger;

  /// Filter/group-by option for material grouping.
  ///
  /// In en, this message translates to:
  /// **'By Material'**
  String get byMaterial;

  /// Filter/group-by option for vendor grouping.
  ///
  /// In en, this message translates to:
  /// **'By Vendor'**
  String get byVendor;

  /// Button to add a new worker to the project.
  ///
  /// In en, this message translates to:
  /// **'Add Worker'**
  String get addWorker;

  /// Empty-state hint for the attendance screen.
  ///
  /// In en, this message translates to:
  /// **'Add workers to mark attendance'**
  String get addWorkersToMarkAttendance;

  /// Attendance section/tab label.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// Confirmation after saving attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance saved successfully'**
  String get attendanceSavedSuccessfully;

  /// Action to remove a worker from the master list.
  ///
  /// In en, this message translates to:
  /// **'Delete worker'**
  String get deleteWorker;

  /// Hint text for the contractor name field.
  ///
  /// In en, this message translates to:
  /// **'Enter contractor name'**
  String get enterContractorName;

  /// Screen title for the labour master list.
  ///
  /// In en, this message translates to:
  /// **'Labour Master'**
  String get labourMaster;

  /// Confirmation after saving any log entry.
  ///
  /// In en, this message translates to:
  /// **'Log saved'**
  String get logSaved;

  /// Empty state when no active workers exist.
  ///
  /// In en, this message translates to:
  /// **'No active workers'**
  String get noActiveWorkers;

  /// Empty state for the labour master list.
  ///
  /// In en, this message translates to:
  /// **'No workers in master list'**
  String get noWorkersInMasterList;

  /// Button to save the day's attendance records.
  ///
  /// In en, this message translates to:
  /// **'Save Attendance'**
  String get saveAttendance;

  /// Confirmation after removing a worker.
  ///
  /// In en, this message translates to:
  /// **'Worker removed'**
  String get workerRemoved;

  /// Button to add a new stock or log entry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get addEntry;

  /// Button to add a material to inventory.
  ///
  /// In en, this message translates to:
  /// **'Add Material'**
  String get addMaterial;

  /// Button to add a new stock item.
  ///
  /// In en, this message translates to:
  /// **'Add Stock Item'**
  String get addStockItem;

  /// Action to add a material not yet in the list.
  ///
  /// In en, this message translates to:
  /// **'Add new material'**
  String get addNewMaterial;

  /// Action to add a vendor not yet in the list.
  ///
  /// In en, this message translates to:
  /// **'Add new vendor'**
  String get addNewVendor;

  /// Unit of measure: bags (cement, sand, etc.).
  ///
  /// In en, this message translates to:
  /// **'Bags'**
  String get unitBags;

  /// Payment method: bank transfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentBankTransfer;

  /// Payment method: cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// Payment method: cheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get paymentCheque;

  /// Unit of measure: cubic meter.
  ///
  /// In en, this message translates to:
  /// **'Cubic Meter'**
  String get unitCubicMeter;

  /// Action to delete a material log entry.
  ///
  /// In en, this message translates to:
  /// **'Delete Material Log'**
  String get deleteMaterialLog;

  /// Unit of measure: kilograms.
  ///
  /// In en, this message translates to:
  /// **'Kg'**
  String get unitKg;

  /// Button to create a new vendor.
  ///
  /// In en, this message translates to:
  /// **'New Vendor'**
  String get newVendor;

  /// Payment method: online / UPI.
  ///
  /// In en, this message translates to:
  /// **'Online/UPI'**
  String get paymentOnlineUpi;

  /// Validation error for the quantity field.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid quantity'**
  String get pleaseEnterValidQuantity;

  /// Label for items/materials that have been received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// Button to save a new entry.
  ///
  /// In en, this message translates to:
  /// **'Save Entry'**
  String get saveEntry;

  /// Prompt to choose a payment method.
  ///
  /// In en, this message translates to:
  /// **'Select payment type for this bill'**
  String get selectPaymentType;

  /// Stock tab/section label.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// Suppliers list section label.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// Unit of measure: metric tons.
  ///
  /// In en, this message translates to:
  /// **'Tons'**
  String get unitTons;

  /// Generic unit of measure.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get unitUnits;

  /// Label for materials that have been consumed/used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// Button to add a new bill.
  ///
  /// In en, this message translates to:
  /// **'Add Bill'**
  String get addBill;

  /// Filter option to show bills across all projects.
  ///
  /// In en, this message translates to:
  /// **'All Projects'**
  String get allProjects;

  /// Filter option to show bills from all site managers.
  ///
  /// In en, this message translates to:
  /// **'All Site Managers'**
  String get allSiteManagers;

  /// Button to apply selected filters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// Screen title for the admin bill approval queue.
  ///
  /// In en, this message translates to:
  /// **'Approval Queue'**
  String get approvalQueue;

  /// Label for a bill submitted for approval.
  ///
  /// In en, this message translates to:
  /// **'Bill Request'**
  String get billRequest;

  /// Field label for the type of bill.
  ///
  /// In en, this message translates to:
  /// **'Bill Type'**
  String get billType;

  /// Confirmation after creating a bill.
  ///
  /// In en, this message translates to:
  /// **'Bill created successfully'**
  String get billCreatedSuccessfully;

  /// Confirmation after permanently deleting a bill.
  ///
  /// In en, this message translates to:
  /// **'Bill permanently deleted'**
  String get billPermanentlyDeleted;

  /// Confirmation after updating a bill.
  ///
  /// In en, this message translates to:
  /// **'Bill updated successfully'**
  String get billUpdatedSuccessfully;

  /// Empty state for the deleted bills bin.
  ///
  /// In en, this message translates to:
  /// **'Bin is empty'**
  String get binIsEmpty;

  /// Action to clear all filters or selections.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Action to delete a bill.
  ///
  /// In en, this message translates to:
  /// **'Delete Bill'**
  String get deleteBill;

  /// Action to permanently delete an item from the bin.
  ///
  /// In en, this message translates to:
  /// **'Delete Forever'**
  String get deleteForever;

  /// Validation error when bill title or amount is missing.
  ///
  /// In en, this message translates to:
  /// **'Enter valid title and amount'**
  String get enterValidTitleAndAmount;

  /// Error message when bill creation fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to create bill. Please try again.'**
  String get failedToCreateBill;

  /// Sheet/dialog title for bill filtering options.
  ///
  /// In en, this message translates to:
  /// **'Filter Bills'**
  String get filterBills;

  /// Message shown to non-admin users on admin-only screens.
  ///
  /// In en, this message translates to:
  /// **'Only admin can access this screen.'**
  String get onlyAdminAccess;

  /// Filter/field label for payment status.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// Title for the permanent deletion confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Permanently Delete?'**
  String get permanentlyDeleteConfirm;

  /// Validation error when no project is selected for a bill.
  ///
  /// In en, this message translates to:
  /// **'Please select a project'**
  String get pleaseSelectProject;

  /// Placeholder for the vendor selection field.
  ///
  /// In en, this message translates to:
  /// **'Select a Vendor'**
  String get selectVendor;

  /// Action to delete a vendor.
  ///
  /// In en, this message translates to:
  /// **'Delete vendor'**
  String get deleteVendor;

  /// Empty state for vendor analytics charts.
  ///
  /// In en, this message translates to:
  /// **'No chart data'**
  String get noChartData;

  /// Empty state on the vendor detail screen.
  ///
  /// In en, this message translates to:
  /// **'No material data for this vendor yet'**
  String get noMaterialDataForVendor;

  /// Confirmation after deleting a vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor deleted'**
  String get vendorDeleted;

  /// Action to delete a machinery item.
  ///
  /// In en, this message translates to:
  /// **'Delete machinery'**
  String get deleteMachinery;

  /// Action to delete a machinery usage log entry.
  ///
  /// In en, this message translates to:
  /// **'Delete machinery log'**
  String get deleteMachineryLog;

  /// Screen title / button for logging machinery usage.
  ///
  /// In en, this message translates to:
  /// **'Log Machinery Usage'**
  String get logMachineryUsage;

  /// Screen title for the machinery master list.
  ///
  /// In en, this message translates to:
  /// **'Machinery Master'**
  String get machineryMaster;

  /// Confirmation after deleting a machinery item.
  ///
  /// In en, this message translates to:
  /// **'Machinery deleted'**
  String get machineryDeleted;

  /// Empty state for the machinery list.
  ///
  /// In en, this message translates to:
  /// **'No machinery added yet.'**
  String get noMachineryAdded;

  /// Machinery ownership type: company-owned.
  ///
  /// In en, this message translates to:
  /// **'Own'**
  String get own;

  /// Validation error for machinery log time fields.
  ///
  /// In en, this message translates to:
  /// **'Please select Start and End time'**
  String get pleaseSelectStartEndTime;

  /// Validation error when no machine is selected.
  ///
  /// In en, this message translates to:
  /// **'Please select a machine'**
  String get pleaseSelectMachine;

  /// Machinery ownership type: rented.
  ///
  /// In en, this message translates to:
  /// **'Rental'**
  String get rental;

  /// Button to save a log entry (machinery or other).
  ///
  /// In en, this message translates to:
  /// **'Save Log'**
  String get saveLog;

  /// Button to add a checklist item or BOQ line item.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// Action to add a 'before' photo to a snag.
  ///
  /// In en, this message translates to:
  /// **'Add before photo'**
  String get addBeforePhoto;

  /// Option to create a blank (empty) checklist.
  ///
  /// In en, this message translates to:
  /// **'Blank checklist'**
  String get blankChecklist;

  /// Screen title for the QA/QC checklist templates.
  ///
  /// In en, this message translates to:
  /// **'Checklist Templates'**
  String get checklistTemplates;

  /// Action to mark a snag as resolved.
  ///
  /// In en, this message translates to:
  /// **'Mark Resolved'**
  String get markResolved;

  /// Button to create a new checklist.
  ///
  /// In en, this message translates to:
  /// **'New Checklist'**
  String get newChecklist;

  /// Button to create a new checklist template.
  ///
  /// In en, this message translates to:
  /// **'New Template'**
  String get newTemplate;

  /// Action to raise a new defect/snag report.
  ///
  /// In en, this message translates to:
  /// **'Raise Snag'**
  String get raiseSnag;

  /// Field label for notes on how a snag was resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolution notes'**
  String get resolutionNotes;

  /// Action to mark a snag as resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolve Snag'**
  String get resolveSnag;

  /// A single defect item.
  ///
  /// In en, this message translates to:
  /// **'Snag'**
  String get snag;

  /// Empty-state CTA on the RA billing clients screen.
  ///
  /// In en, this message translates to:
  /// **'Add your first client'**
  String get addFirstClient;

  /// Screen title for the RA billing clients list.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// Button to create a new RA bill.
  ///
  /// In en, this message translates to:
  /// **'Create RA bill'**
  String get createRaBill;

  /// Action to export a document as PDF.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// Action to export billing data as Tally XML.
  ///
  /// In en, this message translates to:
  /// **'Export Tally XML'**
  String get exportTallyXml;

  /// GST (Goods and Services Tax) label.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get gst;

  /// Screen title for GST configuration.
  ///
  /// In en, this message translates to:
  /// **'GST Settings'**
  String get gstSettings;

  /// Label for the live RA bill preview section.
  ///
  /// In en, this message translates to:
  /// **'Live Preview'**
  String get livePreview;

  /// Label for the net payable amount on a bill.
  ///
  /// In en, this message translates to:
  /// **'Net payable'**
  String get netPayable;

  /// Button to create a new running account bill.
  ///
  /// In en, this message translates to:
  /// **'New RA Bill'**
  String get newRaBill;

  /// Button to add a new billing client.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get newClient;

  /// Action to preview the printable version of a bill.
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get printPreview;

  /// Running Account Bill abbreviation.
  ///
  /// In en, this message translates to:
  /// **'RA Bill'**
  String get raBill;

  /// Screen title for the RA bills list.
  ///
  /// In en, this message translates to:
  /// **'RA Bills'**
  String get raBills;

  /// Button to save GST configuration.
  ///
  /// In en, this message translates to:
  /// **'Save GST settings'**
  String get saveGstSettings;

  /// Tally accounting software XML export format.
  ///
  /// In en, this message translates to:
  /// **'Tally XML'**
  String get tallyXml;

  /// Label for taxable amount on a bill.
  ///
  /// In en, this message translates to:
  /// **'Taxable'**
  String get taxable;

  /// Empty-state CTA to add the first BOQ item.
  ///
  /// In en, this message translates to:
  /// **'Add first item'**
  String get addFirstItem;

  /// Button to add a new line item to the BOQ.
  ///
  /// In en, this message translates to:
  /// **'Add line item'**
  String get addLineItem;

  /// Screen title comparing BOQ estimates to actual spend.
  ///
  /// In en, this message translates to:
  /// **'BOQ vs Actual'**
  String get boqVsActual;

  /// View toggle to group BOQ items by category.
  ///
  /// In en, this message translates to:
  /// **'By Category'**
  String get byCategory;

  /// Full name for the BOQ section.
  ///
  /// In en, this message translates to:
  /// **'Bill of Quantities'**
  String get billOfQuantities;

  /// Button to create a new Bill of Quantities.
  ///
  /// In en, this message translates to:
  /// **'Create BOQ'**
  String get createBoq;

  /// Label for the grand total row in BOQ or billing.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// Amount for a single BOQ line item.
  ///
  /// In en, this message translates to:
  /// **'Line amount'**
  String get lineAmount;

  /// Button to start a new BOQ.
  ///
  /// In en, this message translates to:
  /// **'New BOQ'**
  String get newBoq;

  /// Empty state on the BOQ list screen.
  ///
  /// In en, this message translates to:
  /// **'No estimates yet'**
  String get noEstimatesYet;

  /// Empty state on the BOQ detail screen.
  ///
  /// In en, this message translates to:
  /// **'No line items yet'**
  String get noLineItemsYet;

  /// Empty state on the BOQ vs Actual screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing to compare yet'**
  String get nothingToCompareYet;

  /// Subtotal label in BOQ or billing totals.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// Actual spend column label in BOQ vs Actual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get actual;

  /// Button to add a line to a purchase order or indent.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get addLine;

  /// Button to create a new material indent.
  ///
  /// In en, this message translates to:
  /// **'Create Indent'**
  String get createIndent;

  /// Button to create a new purchase order.
  ///
  /// In en, this message translates to:
  /// **'Create PO'**
  String get createPo;

  /// Screen title for matching purchase orders with GRN.
  ///
  /// In en, this message translates to:
  /// **'GRN Match'**
  String get grnMatch;

  /// Section label for line items on a PO or indent.
  ///
  /// In en, this message translates to:
  /// **'Line items'**
  String get lineItems;

  /// Button to raise a new material indent.
  ///
  /// In en, this message translates to:
  /// **'New Indent'**
  String get newIndent;

  /// Short label for creating a new purchase order.
  ///
  /// In en, this message translates to:
  /// **'New PO'**
  String get newPo;

  /// Full title for creating a new purchase order.
  ///
  /// In en, this message translates to:
  /// **'New Purchase Order'**
  String get newPurchaseOrder;

  /// Label for the total value of a purchase order.
  ///
  /// In en, this message translates to:
  /// **'PO Total'**
  String get poTotal;

  /// Confirmation message after a PO is approved.
  ///
  /// In en, this message translates to:
  /// **'PO approved.'**
  String get poApproved;

  /// Screen title for the purchase indents list.
  ///
  /// In en, this message translates to:
  /// **'Purchase Indents'**
  String get purchaseIndents;

  /// Screen title for the purchase orders list.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrders;

  /// Action to receive goods and match against a PO.
  ///
  /// In en, this message translates to:
  /// **'Receive / Match'**
  String get receiveMatch;

  /// Button to save a Goods Receipt Note.
  ///
  /// In en, this message translates to:
  /// **'Save GRN'**
  String get saveGrn;

  /// Action to view the GRN match for a PO.
  ///
  /// In en, this message translates to:
  /// **'View Match'**
  String get viewMatch;

  /// Filter option in reports to show all vendors.
  ///
  /// In en, this message translates to:
  /// **'All vendors'**
  String get allVendors;

  /// Section header for financial summary in reports.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financialSummary;

  /// Section header for monthly breakdown in reports.
  ///
  /// In en, this message translates to:
  /// **'Monthly Breakdown'**
  String get monthlyBreakdown;

  /// Action button to attach a file from various sources.
  ///
  /// In en, this message translates to:
  /// **'Attach File (Camera / Gallery / PDF)'**
  String get attachFileCameraGalleryPdf;

  /// Confirmation after deleting a blueprint.
  ///
  /// In en, this message translates to:
  /// **'Blueprint deleted successfully'**
  String get blueprintDeletedSuccessfully;

  /// Confirmation after uploading a blueprint.
  ///
  /// In en, this message translates to:
  /// **'Blueprint uploaded successfully!'**
  String get blueprintUploadedSuccessfully;

  /// Action to create new blueprint folders.
  ///
  /// In en, this message translates to:
  /// **'Create Folders'**
  String get createFolders;

  /// Action to delete a blueprint.
  ///
  /// In en, this message translates to:
  /// **'Delete Blueprint'**
  String get deleteBlueprint;

  /// Empty state when no blueprint folders exist.
  ///
  /// In en, this message translates to:
  /// **'No blueprint folders found for this project.'**
  String get noBlueprintFolders;

  /// Validation message when no file has been chosen.
  ///
  /// In en, this message translates to:
  /// **'Please select a file to upload.'**
  String get pleaseSelectFile;

  /// Empty-state CTA to upload the first blueprint.
  ///
  /// In en, this message translates to:
  /// **'Upload First Blueprint'**
  String get uploadFirstBlueprint;

  /// Confirmation after saving profile changes.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// Screen title for the AI-powered BOQ estimation tool.
  ///
  /// In en, this message translates to:
  /// **'AI BOQ Estimator'**
  String get aiBoqEstimator;

  /// Section showing AI estimation assumptions.
  ///
  /// In en, this message translates to:
  /// **'Assumptions'**
  String get assumptions;

  /// Placeholder text in the AI chat input.
  ///
  /// In en, this message translates to:
  /// **'Ask about your sites'**
  String get askAboutYourSites;

  /// Section title showing AI-generated BOQ preview.
  ///
  /// In en, this message translates to:
  /// **'BOQ Preview'**
  String get boqPreview;

  /// Confirmation after copying BOQ to clipboard.
  ///
  /// In en, this message translates to:
  /// **'BOQ copied to clipboard'**
  String get boqCopiedToClipboard;

  /// Confirmation prompt to clear the AI chat history.
  ///
  /// In en, this message translates to:
  /// **'Clear chat history?'**
  String get clearChatHistoryConfirm;

  /// Screen title for the AI daily report generator.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get dailyReport;

  /// Label for the AI-estimated total cost.
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get estimatedTotal;

  /// Input field for number of floors in BOQ estimation.
  ///
  /// In en, this message translates to:
  /// **'Floors'**
  String get floors;

  /// Button to trigger AI report generation.
  ///
  /// In en, this message translates to:
  /// **'Generate report'**
  String get generateReport;

  /// Section showing the AI-parsed invoice data.
  ///
  /// In en, this message translates to:
  /// **'Parsed invoice'**
  String get parsedInvoice;

  /// Confirmation after copying a report to clipboard.
  ///
  /// In en, this message translates to:
  /// **'Report copied'**
  String get reportCopied;

  /// Button to scan a document.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// Screen title for the AI invoice scanning tool.
  ///
  /// In en, this message translates to:
  /// **'Scan Invoice'**
  String get scanInvoice;

  /// Action to share a generated report.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get shareReport;

  /// Name of the AI chat assistant.
  ///
  /// In en, this message translates to:
  /// **'SiteOS Assistant'**
  String get siteOsAssistant;

  /// Button to reset AI generation and start fresh.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// Hint text on the invoice scan screen.
  ///
  /// In en, this message translates to:
  /// **'Tap to select an invoice photo'**
  String get tapToSelectInvoicePhoto;

  /// Shown while the AI is processing a request.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// Section showing the voice report transcript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcript;

  /// Screen title for the AI voice report tool.
  ///
  /// In en, this message translates to:
  /// **'Voice Report'**
  String get voiceReport;

  /// Section showing a preview of the WhatsApp message.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp preview'**
  String get whatsappPreview;

  /// Hint when trying to send a test WhatsApp without recipients.
  ///
  /// In en, this message translates to:
  /// **'Add a recipient first to send a test.'**
  String get addRecipientFirst;

  /// Label for the daily WhatsApp progress report type.
  ///
  /// In en, this message translates to:
  /// **'Daily progress report'**
  String get dailyProgressReport;

  /// Confirmation after saving WhatsApp settings.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get preferencesSaved;

  /// Label for the send-test button on WhatsApp settings.
  ///
  /// In en, this message translates to:
  /// **'Send test to…'**
  String get sendTestTo;

  /// Label for the scheduled send time field (Indian Standard Time).
  ///
  /// In en, this message translates to:
  /// **'Send time (IST)'**
  String get sendTimeIst;

  /// Screen title for WhatsApp reporting settings.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Reports'**
  String get whatsappReports;

  /// Client portal tab for project milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// Client portal screen title for the client's projects.
  ///
  /// In en, this message translates to:
  /// **'My Projects'**
  String get myProjects;

  /// Client portal tab for project progress photos.
  ///
  /// In en, this message translates to:
  /// **'Progress Photos'**
  String get progressPhotos;

  /// RERA report status: approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// RERA report status: draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// Action to edit an existing RERA report.
  ///
  /// In en, this message translates to:
  /// **'Edit RERA report'**
  String get editReraReport;

  /// Button to create a new RERA report.
  ///
  /// In en, this message translates to:
  /// **'New report'**
  String get newReport;

  /// RERA photo timeline screen title.
  ///
  /// In en, this message translates to:
  /// **'Photo timeline'**
  String get photoTimeline;

  /// Screen title for the RERA reporting section.
  ///
  /// In en, this message translates to:
  /// **'RERA Reporting'**
  String get reraReporting;

  /// RERA report status: submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// Field label for geofence radius in GPS attendance.
  ///
  /// In en, this message translates to:
  /// **'Allowed radius'**
  String get allowedRadius;

  /// Field label for geofence centre coordinates.
  ///
  /// In en, this message translates to:
  /// **'Centre coordinates'**
  String get centreCoordinates;

  /// Confirmation after a successful GPS check-in.
  ///
  /// In en, this message translates to:
  /// **'Checked in successfully.'**
  String get checkedInSuccessfully;

  /// Option to check in for yourself (vs for a worker).
  ///
  /// In en, this message translates to:
  /// **'Checking in for myself'**
  String get checkingInForMyself;

  /// Screen title for the GPS attendance check-in screen.
  ///
  /// In en, this message translates to:
  /// **'GPS Check-in'**
  String get gpsCheckIn;

  /// Screen title for setting up geofence boundaries.
  ///
  /// In en, this message translates to:
  /// **'Geofence Setup'**
  String get geofenceSetup;

  /// Confirmation after saving geofence settings.
  ///
  /// In en, this message translates to:
  /// **'Geofence saved.'**
  String get geofenceSaved;

  /// Field label for optional labour selection in GPS check-in.
  ///
  /// In en, this message translates to:
  /// **'Labour (optional)'**
  String get labourOptional;

  /// Option to check in as yourself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get myself;

  /// Button to create a new subcontractor work order.
  ///
  /// In en, this message translates to:
  /// **'New Work Order'**
  String get newWo;

  /// Empty state on the subcontractor RA bills screen.
  ///
  /// In en, this message translates to:
  /// **'No RA bills yet'**
  String get noRaBillsYet;

  /// Empty state on the work orders screen.
  ///
  /// In en, this message translates to:
  /// **'No work orders yet'**
  String get noWorkOrdersYet;

  /// Label for the value of a work order.
  ///
  /// In en, this message translates to:
  /// **'Order value'**
  String get orderValue;

  /// Button to save a subcontractor RA bill.
  ///
  /// In en, this message translates to:
  /// **'Save RA bill'**
  String get saveRaBill;

  /// Screen title for the subcontractors list.
  ///
  /// In en, this message translates to:
  /// **'Subcontractors'**
  String get subcontractors;

  /// Placeholder shown on the subscription/plans screen.
  ///
  /// In en, this message translates to:
  /// **'Plans & checkout — coming soon.'**
  String get plansComingSoon;

  /// Message shown on the trial expired screen.
  ///
  /// In en, this message translates to:
  /// **'Your free trial has ended'**
  String get yourFreeTrialHasEnded;

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
