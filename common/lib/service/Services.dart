import 'HttpService.dart';

class Services {

  // Singleton
  Services._();
  static final instance = Services._();

  //late StatsRepo stats = StatsRepo(BlockaApi(dioClient: DioClient()));
  late HttpService http = HttpService();

}
