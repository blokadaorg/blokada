import 'package:mocktail/mocktail.dart';

import 'di.dart';

class ActScreenplay with Act {
  final ActScenario scenario;

  ActScreenplay(this.scenario);

  @override
  bool isProd() => scenario == ActScenario.production;
}

enum ActScenario {
  production,
  platformIsMocked,
  connectivityRandomlyFailing,
}

Answer<Future<void>> ignore() {
  return (_) async {};
}
