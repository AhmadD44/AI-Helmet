import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:isd/core/errors/failure.dart';
import 'package:isd/core/utils/api_service.dart';
import 'package:isd/features/home/data/models/my_trips_model/all_trips_model.dart';
import 'package:isd/features/home/data/repos/home_repo.dart';

class HomeRepoImpl implements HomeRepo {
  final ApiService apiService;

  HomeRepoImpl(this.apiService);
  @override
  Future<Either<Failure, List<AllTripsModel>>> fetchAllTrips() async {
    try {
      final userForJwt = FirebaseAuth.instance.currentUser;
          final idToken = await userForJwt?.getIdToken();
      var data = await apiService.get(endPoint: 'trips', token: idToken ?? '',);
      List<AllTripsModel> trips = [];
      for (var item in data) {
        trips.add(AllTripsModel.fromJson(item));
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
