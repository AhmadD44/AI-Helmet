import 'package:equatable/equatable.dart';
import 'package:isd/features/home/data/models/my_trips_model/all_trips_model.dart';

abstract class AllTripsState extends Equatable{
  const AllTripsState();

  @override
  List<Object> get props => [];
}

class AllTripsInitial extends AllTripsState{}

class AllTripsLoading extends AllTripsState{}

class AllTripsSuccess extends AllTripsState{
  final List<AllTripsModel> trips;
  const AllTripsSuccess(this.trips);
}

class AllTripsFailure extends AllTripsState{
  final String errMessage;
  const AllTripsFailure(this.errMessage);
}