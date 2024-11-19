part of 'perm.dart';

class PlatformPermChannel with PermChannel {
  late final _platform = PermOps();

  @override
  Future<void> doAskNotificationPerms() => _platform.doAskNotificationPerms();

  @override
  Future<bool> doNotificationEnabled() => _platform.doNotificationEnabled();

  @override
  Future<void> doOpenPermSettings() => _platform.doOpenSettings();

  @override
  Future<void> doSetDns(String tag) => _platform.doSetDns(tag);

  @override
  Future<void> doSetPrivateDnsEnabled(String tag, String alias) =>
      _platform.doSetPrivateDnsEnabled(tag, alias);

  @override
  Future<bool> doVpnEnabled() => _platform.doVpnEnabled();

  @override
  Future<String> getPrivateDnsSetting() => _platform.getPrivateDnsSetting();
}

class NoOpPermChannel with PermChannel {
  @override
  Future<void> doAskNotificationPerms() => Future.value();

  @override
  Future<bool> doNotificationEnabled() => Future.value(false);

  @override
  Future<void> doOpenPermSettings() => Future.value();

  @override
  Future<void> doSetDns(String tag) => Future.value();

  @override
  Future<void> doSetPrivateDnsEnabled(String tag, String alias) =>
      Future.value();

  @override
  Future<bool> doVpnEnabled() => Future.value(false);

  @override
  Future<String> getPrivateDnsSetting() => Future.value("");
}
