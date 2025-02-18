import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class CommonOps {
  // --- Http
  @async
  String doGet(String url);

  @async
  String doRequest(String url, String? payload, String type);

  @async
  String doRequestWithHeaders(
      String url, String? payload, String type, Map<String?, String?> headers);

  // -- Env
  @async
  OpsEnvInfo doGetEnvInfo();

  // -- Rate
  @async
  void doShowRateDialog();

  // -- Link
  @async
  void doLinksChanged(List<OpsLink> links);

  // -- Notification
  @async
  void doShow(String notificationId, String atWhen, String? body);

  @async
  void doDismissAll();

  // -- Config
  @async
  void doConfigChanged(bool skipBypassList);

  @async
  void doShareText(String text);
}

class OpsEnvInfo {
  final String appVersion;
  final String osVersion;
  final String buildFlavor;
  final String buildType;
  final String cpu;
  final String deviceBrand;
  final String deviceModel;
  final String deviceName;

  OpsEnvInfo(
    this.appVersion,
    this.osVersion,
    this.buildFlavor,
    this.buildType,
    this.cpu,
    this.deviceBrand,
    this.deviceModel,
    this.deviceName,
  );
}

class OpsLink {
  String id;
  String url;

  OpsLink(this.id, this.url);
}
