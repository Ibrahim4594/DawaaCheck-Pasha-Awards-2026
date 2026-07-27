import 'package:easy_localization/easy_localization.dart';

/// All UI strings for DawaaCheck — powered by easy_localization
/// Strings are loaded from assets/translations/{en,ur}.json
class AppStrings {
  AppStrings._();

  // App
  static String get appName => 'appName'.tr();
  static String get tagline => 'tagline'.tr();
  static String get poweredBy => 'poweredBy'.tr();

  // Welcome
  static String get continueWithGoogle => 'continueWithGoogle'.tr();
  static String get signInWithEmail => 'signInWithEmail'.tr();
  static String get createAccount => 'createAccount'.tr();
  static String get continueAsGuest => 'continueAsGuest'.tr();
  static String get stat1 => 'stat1'.tr();
  static String get stat1Label => 'stat1Label'.tr();
  static String get stat2 => 'stat2'.tr();
  static String get stat2Label => 'stat2Label'.tr();
  static String get stat3 => 'stat3'.tr();
  static String get stat3Label => 'stat3Label'.tr();

  // Auth
  static String get fullName => 'fullName'.tr();
  static String get emailAddress => 'emailAddress'.tr();
  static String get password => 'password'.tr();
  static String get confirmPassword => 'confirmPassword'.tr();
  static String get forgotPassword => 'forgotPassword'.tr();
  static String get signIn => 'signIn'.tr();
  static String get signUp => 'signUp'.tr();
  static String get resetPassword => 'resetPassword'.tr();
  static String get alreadyHaveAccount => 'alreadyHaveAccount'.tr();
  static String get dontHaveAccount => 'dontHaveAccount'.tr();
  static String get termsAgree => 'termsAgree'.tr();
  static String get or => 'or'.tr();
  static String get resetEmailSent => 'resetEmailSent'.tr();
  static String get welcomeBack => 'welcomeBack'.tr();
  static String get signInToContinue => 'signInToContinue'.tr();
  static String get joinMillions => 'joinMillions'.tr();
  static String get checkInbox => 'checkInbox'.tr();
  static String get backToSignIn => 'backToSignIn'.tr();
  static String get enterEmailReset => 'enterEmailReset'.tr();
  static String get email => 'email'.tr();
  static String get phone => 'phone'.tr();
  static String get phoneNumber => 'phoneNumber'.tr();
  static String get agreeToTerms => 'agreeToTerms'.tr();

  // Home
  static String get searchHint => 'searchHint'.tr();
  static String get verifyMedicineNow => 'verifyMedicineNow'.tr();
  static String get scanSubtitle => 'scanSubtitle'.tr();
  static String get scan => 'scan'.tr();
  static String get recentScans => 'recentScans'.tr();
  static String get seeAll => 'seeAll'.tr();
  static String get medicines => 'medicines'.tr();
  static String get recalls => 'recalls'.tr();
  static String get safetyMap => 'safetyMap'.tr();

  // Scan
  static String get verifyMedicine => 'verifyMedicine'.tr();
  static String get captureFrontLabel => 'captureFrontLabel'.tr();
  static String get captureBackLabel => 'captureBackLabel'.tr();
  static String get captureIngredientsPanel => 'captureIngredientsPanel'.tr();
  static String get front => 'front'.tr();
  static String get back => 'back'.tr();
  static String get ingredients => 'ingredients'.tr();
  static String get pointAtFront => 'pointAtFront'.tr();
  static String get pointAtBack => 'pointAtBack'.tr();
  static String get pointAtIngredients => 'pointAtIngredients'.tr();
  static String get goodLight => 'goodLight'.tr();
  static String get flatSurface => 'flatSurface'.tr();
  static String get holdSteady => 'holdSteady'.tr();
  static String get uploadFromGallery => 'uploadFromGallery'.tr();

  // Processing
  static String get analysingMedicine => 'analysingMedicine'.tr();
  static String get agentsWorking => 'agentsWorking'.tr();
  static String get verifying => 'verifying'.tr();

  // Results
  static String get medicineVerified => 'medicineVerified'.tr();
  static String get allChecksPassed => 'allChecksPassed'.tr();
  static String get doNotUse => 'doNotUse'.tr();
  static String get criticalIssues => 'criticalIssues'.tr();
  static String get cannotVerify => 'cannotVerify'.tr();
  static String get someChecksIncomplete => 'someChecksIncomplete'.tr();
  static String get medicineDetails => 'medicineDetails'.tr();
  static String get issuesFound => 'issuesFound'.tr();
  static String get incompleteChecks => 'incompleteChecks'.tr();
  static String get whatThisMeans => 'whatThisMeans'.tr();
  static String get genericAlternative => 'genericAlternative'.tr();
  static String get reportSideEffect => 'reportSideEffect'.tr();
  static String get reportToDrap => 'reportToDrap'.tr();
  static String get returnToPharmacy => 'returnToPharmacy'.tr();
  static String get tryScanAgain => 'tryScanAgain'.tr();
  static String get contactDrap => 'contactDrap'.tr();
  static String get savedToHistory => 'savedToHistory'.tr();
  static String get backToHome => 'backToHome'.tr();
  static String get verificationFailed => 'verificationFailed'.tr();
  static String get couldNotVerify => 'couldNotVerify'.tr();
  static String get verificationIncomplete => 'verificationIncomplete'.tr();
  static String get checksCouldNotComplete => 'checksCouldNotComplete'.tr();
  static String get recommendation1 => 'recommendation1'.tr();
  static String get recommendation2 => 'recommendation2'.tr();
  static String get recommendation3 => 'recommendation3'.tr();
  static String get recommendation4 => 'recommendation4'.tr();

  // History
  static String get scanHistory => 'scanHistory'.tr();
  static String get all => 'all'.tr();
  static String get verified => 'verified'.tr();
  static String get unverified => 'unverified'.tr();
  static String get danger => 'danger'.tr();
  static String get noScansYet => 'noScansYet'.tr();
  static String get scanNow => 'scanNow'.tr();
  static String get scanFirstMedicine => 'scanFirstMedicine'.tr();
  static String get verifyFirstMedicine => 'verifyFirstMedicine'.tr();
  static String get allMedicinesSafe => 'allMedicinesSafe'.tr();

  // Recalls
  static String get recallAlerts => 'recallAlerts'.tr();
  static String get classI => 'classI'.tr();
  static String get classII => 'classII'.tr();
  static String get youMayBeAffected => 'youMayBeAffected'.tr();
  static String get noActiveRecalls => 'noActiveRecalls'.tr();
  static String get viewDetails => 'viewDetails'.tr();

  // ADR
  static String get reportAdr => 'reportAdr'.tr();
  static String get medicineName => 'medicineName'.tr();
  static String get reactionDescription => 'reactionDescription'.tr();
  static String get severity => 'severity'.tr();
  static String get mild => 'mild'.tr();
  static String get moderate => 'moderate'.tr();
  static String get severe => 'severe'.tr();
  static String get lifeThreatening => 'lifeThreatening'.tr();
  static String get dateOfReaction => 'dateOfReaction'.tr();
  static String get patientAgeGroup => 'patientAgeGroup'.tr();
  static String get submit => 'submit'.tr();
  static String get reportSuccess => 'reportSuccess'.tr();
  static String get reportFailed => 'reportFailed'.tr();

  // Profile
  static String get profile => 'profile'.tr();
  static String get totalScans => 'totalScans'.tr();
  static String get notifications => 'notifications'.tr();
  static String get language => 'language'.tr();
  static String get privacy => 'privacy'.tr();
  static String get about => 'about'.tr();
  static String get signOut => 'signOut'.tr();
  static String get guestUser => 'guestUser'.tr();
  static String get noEmail => 'noEmail'.tr();
  static String get rateApp => 'rateApp'.tr();
  static String get helpSupport => 'helpSupport'.tr();
  static String get cancel => 'cancel'.tr();
  static String get areYouSureSignOut => 'areYouSureSignOut'.tr();
  static String get privacyPolicy => 'privacyPolicy'.tr();
  static String get privacyDataCollection => 'privacyDataCollection'.tr();
  static String get privacyDataCollectionBody => 'privacyDataCollectionBody'.tr();
  static String get privacyHowWeUse => 'privacyHowWeUse'.tr();
  static String get privacyHowWeUseBody => 'privacyHowWeUseBody'.tr();
  static String get privacyCameraStorage => 'privacyCameraStorage'.tr();
  static String get privacyCameraStorageBody => 'privacyCameraStorageBody'.tr();
  static String get privacyAuthentication => 'privacyAuthentication'.tr();
  static String get privacyAuthenticationBody => 'privacyAuthenticationBody'.tr();
  static String get privacyAdr => 'privacyAdr'.tr();
  static String get privacyAdrBody => 'privacyAdrBody'.tr();
  static String get privacyDataSecurity => 'privacyDataSecurity'.tr();
  static String get privacyDataSecurityBody => 'privacyDataSecurityBody'.tr();
  static String get privacyYourRights => 'privacyYourRights'.tr();
  static String get privacyYourRightsBody => 'privacyYourRightsBody'.tr();
  static String get lastUpdated => 'lastUpdated'.tr();
  static String get aboutDescription => 'aboutDescription'.tr();
  static String get aiAgents => 'aiAgents'.tr();
  static String get drapVerified => 'drapVerified'.tr();
  static String get realTime => 'realTime'.tr();
  static String get developedBy => 'developedBy'.tr();
  static String get copyright => 'copyright'.tr();
  static String get trademark => 'trademark'.tr();
  static String get madeWithLove => 'madeWithLove'.tr();
  static String get inPakistan => 'inPakistan'.tr();
  static String get version => 'version'.tr();
  static String get versionFull => 'versionFull'.tr();

  // Navigation
  static String get home => 'home'.tr();
  static String get history => 'history'.tr();
  static String get terminal => 'terminal'.tr();

  // Agent Console
  static String get agentConsole => 'agentConsole'.tr();
  static String get agentConsoleSubtitle => 'agentConsoleSubtitle'.tr();
  static String get agentConsoleReplay => 'agentConsoleReplay'.tr();
  static String get agentConsoleRunning => 'agentConsoleRunning'.tr();
  static String get agentConsoleHint => 'agentConsoleHint'.tr();

  // Offline
  static String get offlineMessage => 'offlineMessage'.tr();

  // Errors
  static String get errorGeneric => 'errorGeneric'.tr();
  static String get retry => 'retry'.tr();

  // Auth Error Messages
  static final Map<String, String> authErrors = {
    'user-not-found': 'authErrorUserNotFound'.tr(),
    'wrong-password': 'authErrorWrongPassword'.tr(),
    'email-already-in-use': 'authErrorEmailAlreadyInUse'.tr(),
    'weak-password': 'authErrorWeakPassword'.tr(),
    'too-many-requests': 'authErrorTooManyRequests'.tr(),
  };

  // Result extras
  static String get riskScore => 'riskScore'.tr();
  static String get riskLevel => 'riskLevel'.tr();
  static String get safetyAlerts => 'safetyAlerts'.tr();
  static String get recommendations => 'recommendations'.tr();
  static String get agentBreakdown => 'agentBreakdown'.tr();
  static String get overallRisk => 'overallRisk'.tr();
  static String get confidenceScore => 'confidenceScore'.tr();
  static String get low => 'low'.tr();
  static String get high => 'high'.tr();
  static String get critical => 'critical'.tr();
  static String get safeToUse => 'safeToUse'.tr();
  static String get exerciseCaution => 'exerciseCaution'.tr();
  static String get allAgentsPassed => 'allAgentsPassed'.tr();
  static String get scanAgain => 'scanAgain'.tr();
  static String get shareResult => 'shareResult'.tr();

  // Agent Names (all 10)
  static List<String> get agentNames => [
    'agent1'.tr(),
    'agent2'.tr(),
    'agent3'.tr(),
    'agent4'.tr(),
    'agent5'.tr(),
    'agent7'.tr(),
    'agent8'.tr(),
    'agent9'.tr(),
    'agent10'.tr(),
    'agent6'.tr(),
  ];

  // Agent processing/done messages (all 10 — order: 1-5, 7-10, 6)
  static List<String> get processingMessages => [
    'processingAgent1'.tr(),
    'processingAgent2'.tr(),
    'processingAgent3'.tr(),
    'processingAgent4'.tr(),
    'processingAgent5'.tr(),
    'processingAgent7'.tr(),
    'processingAgent8'.tr(),
    'processingAgent9'.tr(),
    'processingAgent10'.tr(),
    'processingAgent6'.tr(),
  ];

  static List<String> get doneMessages => [
    'doneAgent1'.tr(),
    'doneAgent2'.tr(),
    'doneAgent3'.tr(),
    'doneAgent4'.tr(),
    'doneAgent5'.tr(),
    'doneAgent7'.tr(),
    'doneAgent8'.tr(),
    'doneAgent9'.tr(),
    'doneAgent10'.tr(),
    'doneAgent6'.tr(),
  ];

  static String get waiting => 'waiting'.tr();

  // Onboarding
  static String get skip => 'skip'.tr();

  /// Retained: the final onboarding CTA ("Let's Go!" / "چلیں شروع کریں!").
  /// The rest of the onboardingN* keys were retired with the Clinical
  /// Precision splash rewrite — current copy lives under `onb*` keys and is
  /// resolved inline via `.tr()` in splash_screen.dart.
  static String get onboarding3Button => 'onboarding3Button'.tr();

  // Language (only en/ur are in supportedLocales in main.dart; the native-
  // script labels for the other four are kept for display in the Profile
  // language picker, but there are no corresponding getters used.)
  static String get english => 'english'.tr();
  static String get urdu => 'urdu'.tr();

  // Greetings
  static String get goodMorning => 'goodMorning'.tr();
  static String get goodAfternoon => 'goodAfternoon'.tr();
  static String get goodEvening => 'goodEvening'.tr();
  static String get goodNight => 'goodNight'.tr();
}
