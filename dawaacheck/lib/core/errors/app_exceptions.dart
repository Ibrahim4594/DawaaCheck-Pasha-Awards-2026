/// Custom exceptions for DawaaCheck
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException($code): $message';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError});
}

class ScanException extends AppException {
  const ScanException(super.message, {super.code, super.originalError});
}

class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.originalError});
}
