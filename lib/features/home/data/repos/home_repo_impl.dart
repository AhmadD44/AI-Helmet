import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:isd/core/errors/failure.dart';
import 'package:isd/core/utils/api_service.dart';
import 'package:isd/features/home/data/models/my_trips_model/my_trips_model.dart';
import 'package:isd/features/home/data/repos/home_repo.dart';

class HomeRepoImpl implements HomeRepo {
  final ApiService apiService;

  HomeRepoImpl(this.apiService);
  @override
  Future<Either<Failure, List<MyTripsModel>>> fetchAllTrips() async {
    try {
      var data = await apiService.get(endPoint: 'trips');
      List<MyTripsModel> trips = [];
      for (var item in data) {
        trips.add(MyTripsModel.fromJson(item));
      }
      return right(trips);
    } catch (e) {
      if (e is DioException) {
        return left(ServerFailure.fromDioError(e));
      }
      return left(ServerFailure(errMessage: e.toString()));
    }
  }
}
