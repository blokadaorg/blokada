part of 'common.dart';

abstract class CommonChannel
    with
        RateChannel,
        EnvChannel,
        LinkChannel,
        HttpChannel,
        NotificationChannel, ConfigChannel {}

class PlatformCommonChannel extends CommonChannel {
  late final _ops = CommonOps();

  // RateChannel

  @override
  Future<void> doShowRateDialog() => _ops.doShowRateDialog();

  // EnvChannel

  @override
  Future<EnvInfo> doGetEnvInfo() async {
    final e = await _ops.doGetEnvInfo();
    return EnvInfo(
      e.appVersion,
      e.osName,
      e.osVersion,
      e.buildFlavor,
      e.buildType,
      e.cpu,
      e.deviceBrand,
      e.deviceModel,
      e.deviceName,
    );
  }

  // LinkChannel

  @override
  Future<void> doLinksChanged(Map<LinkId, String> links) async =>
      await _ops.doLinksChanged(
        links.entries
            .map((e) => OpsLink(id: e.key.name, url: e.value))
            .toList(),
      );

  // HttpChannel

  @override
  Future<String> doGet(String url) => _ops.doGet(url);

  @override
  Future<String> doRequest(String url, String? payload, String type) =>
      _ops.doRequest(url, payload, type);

  @override
  Future<String> doRequestWithHeaders(
          String url, String? payload, String type, Map<String?, String?> h) =>
      _ops.doRequestWithHeaders(url, payload, type, h);

  // NotificationChannel

  @override
  Future<void> doDismissAll() => _ops.doDismissAll();

  @override
  Future<void> doShow(String notificationId, String atWhen, String? body) =>
      _ops.doShow(notificationId, atWhen, body);

  @override
  Future<void> doConfigChanged(bool skipBypassList) => _ops.doConfigChanged(skipBypassList);

  @override
  Future<void> doShareText(String text) => _ops.doShareText(text);
}

class NoOpCommonChannel extends CommonChannel {
  // RateChannel

  @override
  Future<void> doShowRateDialog() => Future.value();

  // EnvChannel

  @override
  Future<EnvInfo> doGetEnvInfo() async => EnvInfo(
        "mockVersion",
        "mockOsName",
        "mockOsVersion",
        "mockBuildFlavor",
        "mockBuildType",
        "mockCpu",
        "mockDeviceBrand",
        "mockDeviceModel",
        "mockDevice",
      );

  // LinkChannel

  @override
  Future<void> doLinksChanged(Map<LinkId, String> links) => Future.value();

  // HttpChannel

  @override
  Future<String> doGet(String url) =>
      throw Exception("Mock http not implemented");

  @override
  Future<String> doRequest(String url, String? payload, String type) =>
      throw Exception("Mock http not implemented");

  @override
  Future<String> doRequestWithHeaders(
          String url, String? payload, String type, Map<String?, String?> h) =>
      throw Exception("Mock http not implemented");

  // NotificationChannel

  @override
  Future<void> doDismissAll() => Future.value();

  @override
  Future<void> doShow(String notificationId, String atWhen, String? body) =>
      Future.value();

  @override
  Future<void> doConfigChanged(bool skipBypassList) => Future.value();

  @override
  Future<void> doShareText(String text) => Future.value();
}
