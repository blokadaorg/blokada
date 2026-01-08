part of 'family.dart';

mixin FamilyChannel {
  Future<void> doShareUrl(String url);
}

class PlatformFamilyChannel with FamilyChannel {
  late final _platform = FamilyOps();

  @override
  Future<void> doShareUrl(String url) => _platform.doShareUrl(url);
}

class NoOpFamilyChannel with FamilyChannel {
  @override
  Future<void> doShareUrl(String url) async {}
}
