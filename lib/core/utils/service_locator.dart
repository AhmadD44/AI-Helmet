//This file to avoid making too much objects only one dio-apiService-....

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:isd/core/utils/api_service.dart';
import 'package:isd/features/home/data/repos/home_repo_impl.dart';

final getIt = GetIt.instance;

void setupServiceLocator(){
  getIt.registerSingleton<ApiService>(ApiService(Dio()));
  getIt.registerSingleton<HomeRepoImpl>(HomeRepoImpl(
    getIt.get<ApiService>() ,
  ));
}
