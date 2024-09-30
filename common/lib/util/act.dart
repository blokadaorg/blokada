import 'package:mocktail/mocktail.dart';

import 'di.dart';

class ActScreenplay with Act {
  final ActScenario scenario;
  final Flavor flavor;
  final Platform platform;

  ActScreenplay(this.scenario, this.flavor, this.platform);

  @override
  bool isProd() =>
      scenario == ActScenario.prod || scenario == ActScenario.prodWithToys;

  @override
  bool hasToys() => scenario == ActScenario.prodWithToys;

  @override
  bool isFamily() => flavor == Flavor.family;

  @override
  bool isTest() => scenario == ActScenario.test;

  @override
  Platform getPlatform() => platform;

  @override
  Flavor getFlavor() => flavor;
}

enum ActScenario {
  prod,
  prodWithToys,
  platformIsMocked,
  test,
  connectivityRandomlyFailing,
}

Answer<Future<void>> ignore() {
  return (_) async {};
}
