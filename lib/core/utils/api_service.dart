import 'package:dio/dio.dart';

class ApiService {
  final _baseUrl = 'https://smart-helmet-backend-cj1x.onrender.com/api/v1/';
  final Dio dio;

  ApiService(this.dio);

  Future<dynamic> get({required String endPoint}) async {
    var response = await dio.get('$_baseUrl$endPoint');

    return response.data;
  }

  Future<Map<String, dynamic>> post({required String endPoint}) async {
    var response = await dio.post('$_baseUrl$endPoint');

    return response.data;
  }
}
