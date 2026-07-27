import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_strings.dart';
import 'app_exceptions.dart';

/// Centralized error handling
class ErrorHandler {
  ErrorHandler._();

  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return AppStrings.authErrors[error.code] ?? error.message ?? AppStrings.errorGeneric;
    }
    if (error is AuthException) {
      return error.message;
    }
    return AppStrings.errorGeneric;
  }

  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    return AppStrings.errorGeneric;
  }
}
