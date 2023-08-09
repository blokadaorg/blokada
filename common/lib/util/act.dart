import 'package:mocktail/mocktail.dart';

import 'di.dart';

class ActScreenplay with Act {
  final ActScenario scenario;

  ActScreenplay(this.scenario);

  @override
  bool isProd() =>
      scenario == ActScenario.prod || scenario == ActScenario.prodWithToys;

  @override
  bool hasToys() => scenario == ActScenario.prodWithToys;
}

enum ActScenario {
  prod,
  prodWithToys,
  platformIsMocked,
  connectivityRandomlyFailing,
}

Answer<Future<void>> ignore() {
  return (_) async {};
}
