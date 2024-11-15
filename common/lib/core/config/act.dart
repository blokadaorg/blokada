part of '../core.dart';

mixin Act {
  bool isProd();
  bool hasToys();
  bool isFamily();
  bool isTest();
  PlatformType getPlatform();
  Flavor getFlavor();

  bool isRelease = kReleaseMode;
}

enum Flavor { og, family }

class ActScreenplay with Act {
  final ActScenario scenario;
  final Flavor flavor;
  final PlatformType platform;

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
  PlatformType getPlatform() => platform;

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
