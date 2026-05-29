part of 'family.dart';

const familyLinkBase = "https://go.blokada.org/family/link_device";
const linkTemplate = "$familyLinkBase?token=TOKEN";

class LinkActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();

  late final _device = Core.get<DeviceActor>();
  late final _auth = Core.get<AuthActor>();
  late final _thisDevice = Core.get<ThisDevice>();

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

  // Updates the name and/or profile of the device currently being linked,
  // without minting a new token or device tag. The token and QR stay valid, so
  // a child that already scanned keeps linking, and the live profile picker
  // keeps pointing at an existing device.
  Future<LinkingDevice?> updateLinkingDevice({
    String? name,
    JsonProfile? profile,
    required Marker m,
  }) async {
    return await log(m).trace("updateLinkingDevice", (m) async {
      final current = _linkingDevice;
      // The link can finish (heartbeat) or be cancelled (dispose) while an edit
      // dialog is still open. A tap after that is a no-op, not an error thrown
      // into the UI caller's uncaught Future.
      if (current == null) return null;

      // The session can finish, be cancelled, or be replaced by a newer edit
      // while we await network calls below. If it does, abort instead of writing
      // _linkingDevice back to a stale (or deleted) device. cancelLinkDevice
      // already deleted that device, so resurrecting it would leak state.
      bool sessionGone() => !identical(_linkingDevice, current);

      var device = current.device;
      if (name != null) {
        device = await _device.renameDevice(device, name, m);
        if (sessionGone()) return null;
      }

      var newProfile = current.profile;
      if (profile != null && profile.profileId != device.profileId) {
        // select: false, the linking device is a child, changing its profile
        // must not rewrite this (parent) device's own filter config.
        device = await _device.changeDeviceProfile(device, profile, m,
            select: false);
        if (sessionGone()) return null;
        newProfile = profile;
      }

      final updated = LinkingDevice(
        device: device,
        relink: current.relink,
        profile: newProfile,
      );
      updated.token = current.token;
      updated.qrUrl = current.qrUrl;
      _linkingDevice = updated;
      return updated;
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
      final linked = _linkingDevice!.device;
      _linkingDevice = null;
      _device.stopHeartbeatMonitoring();
      linkDeviceHeartbeatReceived();
      linkDeviceFinished(m);
      // Seed the kid device's School/Bedtime templates + locked schedule
      // only now that the link has actually completed. Running this from
      // `DeviceActor.addDevice` would leak the seeded profiles into the
      // parent's profile picker if the parent cancelled before the kid
      // device accepted.
      await _device.seedScheduleForLinkedDevice(linked, m);
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
