import 'package:dio/dio.dart';

class Stats {
  final String total_allowed;
  final String total_blocked;

  const Stats({
    required this.total_allowed,
    required this.total_blocked,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      total_allowed: json['total_allowed'],
      total_blocked: json['total_blocked'],
    );
  }
}

class Endpoints {
  Endpoints._();

  static const String baseUrl = "https://api.blocka.net";
  static const int receiveTimeout = 5000;
  static const int connectionTimeout = 5000;

}

class DioClient {
// dio instance
  final Dio _dio = Dio();

  DioClient() {
    _dio
      ..options.baseUrl = Endpoints.baseUrl
      ..options.connectTimeout = Endpoints.connectionTimeout
      ..options.receiveTimeout = Endpoints.receiveTimeout
      ..options.responseType = ResponseType.json;
  }

  Future<Response> get(
      String url, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
        ProgressCallback? onReceiveProgress,
      }) async {
    try {
      final Response response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

class BlockaApi {
  final DioClient dioClient;

  BlockaApi({required this.dioClient});

  Future<Response> getStatsApi(String accountId) async {
    try {
      final Response response = await dioClient.get("/v2/stats?account_id=$accountId");
      return response;
    } catch (e) {
      rethrow;
    }
  }

}

class StatsRepo {
  final BlockaApi api;

  StatsRepo(this.api);

  Future<Stats> getStats(String accountId) async {
    try {
      final response = await api.getStatsApi(accountId);
      return Stats.fromJson(response.data);
    } on DioError catch (e) {
      print(e);
      final errorMessage = DioExceptions.fromDioError(e).toString();
      throw errorMessage;
    }
  }
}

class DioExceptions implements Exception {
  late String message;

  DioExceptions.fromDioError(DioError dioError) {
    switch (dioError.type) {
      case DioErrorType.cancel:
        message = "Request to API server was cancelled";
        break;
      case DioErrorType.connectTimeout:
        message = "Connection timeout with API server";
        break;
      case DioErrorType.receiveTimeout:
        message = "Receive timeout in connection with API server";
        break;
      case DioErrorType.response:
        message = _handleError(
          dioError.response?.statusCode,
          dioError.response?.data,
        );
        break;
      case DioErrorType.sendTimeout:
        message = "Send timeout in connection with API server";
        break;
      case DioErrorType.other:
        if (dioError.message.contains("SocketException")) {
          message = 'No Internet';
          break;
        }
        message = "Unexpected error occurred";
        break;
      default:
        message = "Something went wrong";
        break;
    }
  }

  String _handleError(int? statusCode, dynamic error) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return error['message'];
      case 500:
        return 'Internal server error';
      case 502:
        return 'Bad gateway';
      default:
        return 'Oops something went wrong';
    }
  }

  @override
  String toString() => message;
}