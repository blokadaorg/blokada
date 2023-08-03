import 'package:mocktail/mocktail.dart';

import 'di.dart';

class ActScreenplay with Act {
  final ActScenario scenario;
  final String flavor;

  ActScreenplay(this.scenario, this.flavor);

  @override
  bool isProd() =>
      scenario == ActScenario.prod || scenario == ActScenario.prodWithToys;

  @override
  bool hasToys() => scenario == ActScenario.prodWithToys;

  @override
  bool isFamily() => flavor == 'family';
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
