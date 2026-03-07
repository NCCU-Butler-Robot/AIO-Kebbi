import 'package:get_it/get_it.dart';

import '../services/api_service.dart';


final sl = GetIt.instance;

void setupServiceLocator() {
  sl.registerLazySingleton<ApiService>(() => ApiService());
}
