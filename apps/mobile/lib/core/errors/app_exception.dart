class AppException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const AppException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => '[$code] $message';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Phiên đăng nhập đã hết hạn.'])
      : super(code: 'UNAUTHORIZED', message: message, statusCode: 401);
}

class NetworkFailureException extends AppException {
  const NetworkFailureException([
    String message = 'Không thể kết nối tới máy chủ Nam Cinema.',
  ]) : super(code: 'NETWORK_FAILURE', message: message);
}
