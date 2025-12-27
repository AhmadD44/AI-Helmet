import 'package:isd/features/home/presentation/view_model/all_trips_cubit/all_trips_state.dart';
import 'package:bloc/bloc.dart';
import 'package:isd/features/home/data/repos/home_repo.dart';

class AllTripsCubit extends Cubit<AllTripsState>{
  AllTripsCubit(this.homeRepo) : super(AllTripsInitial());

  final HomeRepo homeRepo;

  Future<void> fetchAllTrips() async{
    emit(AllTripsLoading());
    var result = await homeRepo.fetchAllTrips();
    result.fold((
      failure){
        emit(AllTripsFailure(failure.errMessage));
      },
     (allTrips){
        emit(AllTripsSuccess(allTrips));
    });
  }
}