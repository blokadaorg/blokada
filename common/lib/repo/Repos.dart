import 'package:common/repo/AppRepo.dart';

import 'AccountRepo.dart';
import 'StatsRepo.dart';

class Repos {

  // Singleton
  Repos._();
  static final instance = Repos._();

  late AppRepo app = AppRepo();
  late AccountRepo account = AccountRepo();
  late StatsRepo stats = StatsRepo();

  start() {
    app.start();
    account.start();
    stats.start();
  }

}