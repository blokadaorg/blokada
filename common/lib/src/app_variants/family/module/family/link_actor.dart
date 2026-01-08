part of 'family.dart';

const familyLinkBase = "https://go.blokada.org/family/link_device";
const linkTemplate = "$familyLinkBase?token=TOKEN";

class LinkActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();

  late final _device = Core.get<DeviceActor>();
  late final _auth = Core.get<AuthActor>();
  late final _thisDevice = Core.get<ThisDevice>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _topBarController = Core.get<TopBarController>();

  late final linkedMode = Core.get<FamilyLinkedMode>();

  bool linkedTokenOk = false;
  String onboardLinkTemplate = linkTemplate;

  LinkingDevice? _linkingDevice;
  var linkDeviceHeartbeatReceived = () {};
  var linkDeviceFinished = (Marker m) {};

  @override
  onCreate(Marker m) async {
    _auth.onTokenExpired = (m) {
      log(m).i("token expired");
      linkedTokenOk = false;
      linkedMode.now = false;
      _thisDevice.change(m, null);
    };
    _auth.onTokenRefreshed = (m) {
      log(m).i("token refreshed");
      linkedTokenOk = true;
      linkedMode.now = true;
    };
  }

  // Initiates the QR code based child device registration process,
  // Returns URL to be used in QR code.
  Future<LinkingDevice> initiateLinkDevice(
      String deviceName, JsonProfile? profile, JsonDevice? device, Marker m) async {
    return await log(m).trace("setWaitingForDevice", (m) async {
      LinkingDevice d = device == null
          ? await _device.addDevice(deviceName, profile, m)
          : LinkingDevice(device: device, relink: true);
      d.token = await _auth.createToken(d.device.deviceTag, m);
      log(m).i("Linking device ${d.device.deviceTag} token: ${d.token}");
      _linkingDevice = d;
      _device.onHeartbeat = (tag) => _finishLinkDevice(m, tag);
      _device.startHeartbeatMonitoring(d.device.deviceTag, m);
      d.qrUrl = _generateLink(d.token);
      return d;
    });
  }

  cancelLinkDevice(Marker m) async {
    return await log(m).trace("cancelAddDevice", (m) async {
      if (_linkingDevice == null) return;
      final d = _linkingDevice!;
      log(m).i("cancelling device ${d.device.deviceTag}");
      if (!d.relink) await _device.deleteDevice(d.device, m);
      _device.stopHeartbeatMonitoring();
      _linkingDevice = null;
    });
  }

  _finishLinkDevice(Marker m, DeviceTag tag) async {
    if (tag == _linkingDevice!.device.deviceTag) {
      _linkingDevice = null;
      _device.stopHeartbeatMonitoring();
      linkDeviceHeartbeatReceived();
      linkDeviceFinished(m);
    } else {
      log(m).e(msg: "addDevice: unexpected device tag: $tag");
    }
  }

  String _generateLink(String token) {
    return onboardLinkTemplate.replaceAll("TOKEN", token.urlEncode);
  }

  link(String qrUrl, Marker m) async {
    return await log(m).trace("link", (m) async {
      try {
        final token = qrUrl.split("?token=").last;
        final deviceTag = await _auth.useToken(token, m);
        log(m).i("received proper token for device: $deviceTag: $token");
        await _device.setThisDeviceForLinked(deviceTag, token, m);
        _auth.startHeartbeat();
        linkedTokenOk = true;
        linkedMode.now = true;
        await _stage.dismissModal(m);
      } on AlreadyLinkedException catch (e) {
        await _stage.showModal(StageModal.faultLinkAlready, m);
        rethrow;
      } catch (e) {
        await _stage.showModal(StageModal.fault, m);
        rethrow;
      }
    });
  }
}
