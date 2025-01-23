part of 'api.dart';

enum HttpType { post, put, delete }

class HttpCodeException implements Exception {
  final int code;
  final String message;

  HttpCodeException(this.code, this.message);

  @override
  String toString() {
    return 'HttpCodeException{code: $code, message: $message}';
  }

  bool shouldRetry() {
    return code >= 500;
  }
}
