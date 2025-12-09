import 'package:dio/dio.dart';

abstract class Failure {
  final String errMessage;

  Failure({required this.errMessage});
}

class ServerFailure extends Failure {
  ServerFailure({required super.errMessage});

  factory ServerFailure.fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
        return ServerFailure(errMessage: 'Connection Timeout');

      case DioExceptionType.sendTimeout:
        return ServerFailure(errMessage: 'Send Timeout');

      case DioExceptionType.receiveTimeout:
        return ServerFailure(errMessage: 'Receive Timeout');

      case DioExceptionType.badCertificate:
        return ServerFailure(errMessage: 'Bad Certificate - SSL Error');

      case DioExceptionType.badResponse:
        return ServerFailure.fromResponse(
          dioError.response!.statusCode!,
          dioError.response!.data,
        );

      case DioExceptionType.cancel:
        return ServerFailure(errMessage: 'Request Cancelled');

      case DioExceptionType.connectionError:
        return ServerFailure(errMessage: 'Connection Error - No Internet');

      case DioExceptionType.unknown:
        return ServerFailure(errMessage: 'Unexpected Error Occurred');
    }
  }
  factory ServerFailure.fromResponse(int statusCode, dynamic response) {
    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      return ServerFailure(errMessage: response['error']['message']);
    } else if (statusCode == 404) {
      return ServerFailure(
        errMessage: 'Your request not found, please try again later!',
      );
    } else if (statusCode == 404) {
      return ServerFailure(
        errMessage: 'Internal server error, please try again later!',
      );
    } else {
      return ServerFailure(
        errMessage: 'Oops there is an error, please try again later!',
      );
    }
  }
}
