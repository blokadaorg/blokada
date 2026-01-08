part of 'safari.dart';

class PlatformSafariChannel with SafariChannel {
  late final _platform = SafariOps();

  @override
  Future<void> doOpenSafariSetup() => _platform.doOpenSafariSetup();
}

class NoOpSafariChannel with SafariChannel {
  @override
  Future<void> doOpenSafariSetup() => Future.value();
}
