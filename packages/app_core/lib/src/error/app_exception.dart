abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.code, this.originalError, this.stackTrace});

  @override
  String toString() => '$runtimeType${code != null ? ' ($code)' : ''}: $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.originalError, super.stackTrace});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError, super.stackTrace});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.code, super.originalError, super.stackTrace});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.originalError, super.stackTrace});
}

class ConfigException extends AppException {
  const ConfigException(super.message, {super.code, super.originalError, super.stackTrace});
}

class PermissionException extends AppException {
  final String permissionType;
  const PermissionException(
    super.message, {
    required this.permissionType,
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

class ForbiddenZoneException extends AppException {
  final String? zoneId;
  const ForbiddenZoneException(
    super.message, {
    this.zoneId,
    super.code = 'FORBIDDEN_ZONE',
    super.originalError,
    super.stackTrace,
  });
}

