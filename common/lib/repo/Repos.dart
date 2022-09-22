import 'StatsRepo.dart';

class Repos {

  // Singleton
  Repos._();
  static final instance = Repos._();

  late StatsRepo stats = StatsRepo();

  start() {
    stats.start();
  }

}