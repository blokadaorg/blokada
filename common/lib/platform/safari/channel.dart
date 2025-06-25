part of 'safari.dart';

class PlatformSafariChannel with SafariChannel {
  late final _platform = SafariOps();

  @override
  Future<bool> doGetStateOfContentFilter() => _platform.doGetStateOfContentFilter();

  @override
  Future<void> doOpenPermsFlowForContentFilter() => _platform.doOpenPermsFlowForContentFilter();

  @override
  Future<void> doOpenPermsFlowForYoutube() => _platform.doOpenPermsFlowForYoutube();

  @override
  Future<void> doUpdateContentFilterRules(bool filtering) =>
      _platform.doUpdateContentFilterRules(filtering);
}

class NoOpSafariChannel with SafariChannel {
  @override
  Future<bool> doGetStateOfContentFilter() => Future.value(false);

  @override
  Future<void> doOpenPermsFlowForContentFilter() => Future.value();

  @override
  Future<void> doOpenPermsFlowForYoutube() => Future.value();

  @override
  Future<void> doUpdateContentFilterRules(bool filtering) => Future.value();
}
