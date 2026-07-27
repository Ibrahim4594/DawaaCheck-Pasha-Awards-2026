import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// API and service constants.
class ApiConstants {
  ApiConstants._();

  /// Backend base URL.
  ///
  /// Override at build time for a deployed backend:
  /// ```
  /// flutter run --dart-define=DAWAACHECK_API_URL=https://api.example.com
  /// ```
  ///
  /// With no override, this resolves to a sensible local default per platform.
  /// The Android emulator cannot reach the host's `localhost` — that address
  /// refers to the emulated device itself — so it uses the standard
  /// `10.0.2.2` alias for the host machine instead. Getting this wrong is the
  /// usual reason a locally-running backend appears unreachable from the app.
  static final String baseUrl = const String.fromEnvironment(
    'DAWAACHECK_API_URL',
    defaultValue: '',
  ).isNotEmpty
      ? const String.fromEnvironment('DAWAACHECK_API_URL')
      : _localDefault;

  static String get _localDefault {
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {
      // Platform is unavailable on some targets; fall through to localhost.
    }
    return 'http://localhost:8000';
  }

  // Endpoints
  static const String scanVerify = '/scan/verify';
  static const String scanVerifyJson = '/scan/verify-json';
  static const String recalls = '/recalls';
  static const String recallsAll = '/recalls/all';
  static const String recallCheck = '/recalls/check';
  static const String medicineSearch = '/medicines/search';
  static const String medicineDetail = '/medicines/detail';
  static const String medicineInteractions = '/medicines/interactions';
  static const String medicineInteractionPair = '/medicines/interactions/check-pair';
  static const String medicineSideEffects = '/medicines/side-effects';
  static const String medicineWhoAware = '/medicines/who-aware';
  static const String medicinePediatric = '/medicines/pediatric-safety';
  static const String medicineConditions = '/medicines/conditions';
  static const String medicineAlternatives = '/medicines/alternatives';
  static const String medicineManufacturer = '/medicines/manufacturer';
  static const String medicineStats = '/medicines/stats';
  static const String adrReport = '/adr/report';
  static const String userSync = '/users/sync';

  // External APIs
  static const String openFdaBase = 'https://api.fda.gov/drug';
  static const String rxNormBase = 'https://rxnav.nlm.nih.gov/REST';
  static const String dailyMedBase = 'https://dailymed.nlm.nih.gov/dailymed/services';

  // Supabase
  static const String supabaseUrl = 'https://fiqfkzrjpqxbtpbmibsv.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpcWZrenJqcHF4YnRwYm1pYnN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NTMwODYsImV4cCI6MjA4ODEyOTA4Nn0.SE-4khQIIhX5gEkR0csAgYgyGY7k2qf-kNJqAbcpQmc';

  // Timeouts
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 60000;
  static const int scanTimeout = 120000;
}
