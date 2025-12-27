import 'package:dio/dio.dart';

class ApiService {
  final String _baseUrl = 'http://ec2-3-14-15-242.us-east-2.compute.amazonaws.com:8000/api/v1/';
  final Dio dio;

  ApiService(this.dio) {
    dio.options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  // ========== HEADER HELPER ==========

  /// Create headers with required token
  Map<String, dynamic> _createHeaders({required String token}) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
  Future<dynamic> get({
    required String endPoint,
    required String token,
    Map<String, dynamic>? queryParams,
  }) async {
    var response = await dio.get(
        endPoint,
        queryParameters: queryParams,
        options: Options(headers: _createHeaders(token: token)),
      );

    return response.data;
  }

  Future<Map<String, dynamic>> post({required String endPoint}) async {
    var response = await dio.post('$_baseUrl$endPoint');

    return response.data;
  }
}
