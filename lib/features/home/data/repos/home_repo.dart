import 'package:dartz/dartz.dart';
import 'package:isd/core/errors/failure.dart';
import 'package:isd/features/home/data/models/my_trips_model/all_trips_model.dart';

abstract class HomeRepo {
  Future<Either<Failure, List<AllTripsModel>>> fetchAllTrips();
}
