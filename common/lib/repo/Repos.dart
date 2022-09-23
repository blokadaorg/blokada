import 'package:common/repo/AppRepo.dart';

import 'StatsRepo.dart';

class Repos {

  // Singleton
  Repos._();
  static final instance = Repos._();

  late AppRepo app = AppRepo();
  late StatsRepo stats = StatsRepo();

  start() {
    app.start();
    stats.start();
  }

}