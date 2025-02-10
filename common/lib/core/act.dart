part of 'core.dart';

enum Flavor { v6, family }

enum ActScenario {
  prod,
  prodWithToys,
  platformIsMocked,
  test,
  connectivityRandomlyFailing,
}

mixin Act {
  late final bool isProd;
  late final bool isFamily;
  late final bool isTest;
  late final bool isRelease;
  late final bool hasToys;
  late final PlatformType platform;
  late final Flavor flavor;
}

class ActScreenplay with Act {
  final ActScenario scenario;

  ActScreenplay(this.scenario, Flavor flavor, PlatformType platform) {
    isProd =
        scenario == ActScenario.prod || scenario == ActScenario.prodWithToys;
    isFamily = flavor == Flavor.family;
    isTest = scenario == ActScenario.test;
    isRelease = kReleaseMode;
    hasToys = scenario == ActScenario.prodWithToys;
    this.platform = platform;
    this.flavor = flavor;
  }
}
