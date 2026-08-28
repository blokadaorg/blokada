part of 'family.dart';

const familyLinkBase = "https://go.blokada.org/family/link_device";
const linkTemplate = "$familyLinkBase?token=TOKEN";

// AsyncValue.fetch can stall behind a racing in-flight fetch. Bound it so the
// confirmation decision always completes.
const _predicateTimeout = Duration(seconds: 5);

// Three base64url segments. The token is only structurally validated here;
// the API is the authority on whether it is genuine.
final _jwtFormat = RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$');

/// Extracts the enrolment token from an incoming link.
///
/// Accepts the canonical `familyLinkBase?token=...` URL and the bare token that
/// the Android CommandActivity delivers. Returns null for anything else.
String? parseFamilyLinkToken(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
    if (!trimmed.startsWith(familyLinkBase)) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    final token = uri.queryParameters["token"];
    if (token == null) return null;
    return _jwtFormat.hasMatch(token) ? token : null;
  }

  return _jwtFormat.hasMatch(trimmed) ? trimmed : null;
}

class LinkActor with Logging, Actor {
  late final _stage = Core.get<StageStore>();

  late final _device = Core.get<DeviceActor>();
  late final _auth = Core.get<AuthActor>();
  late final _thisDevice = Core.get<ThisDevice>();
  late final _currentToken = Core.get<CurrentToken>();
  late final _account = Core.get<AccountStore>();
  late final _wasSetUp = Core.get<WasSetUp>();

  late final linkedMode = Core.get<FamilyLinkedMode>();
  late final pendingLink = Core.get<PendingLinkValue>();

  bool linkedTokenOk = false;
  String onboardLinkTemplate = linkTemplate;

  // Claimed synchronously so check-and-claim cannot interleave. PendingLinkValue
  // reports present == null until its first change resolves, so it cannot be
  // the authority for "is a link already awaiting an answer".
  String? _claimedLink;

  LinkingDevice? _linkingDevice;
  var linkDeviceHeartbeatReceived = () {};
  var linkDeviceFinished = (Marker m) {};

  @override
  onCreate(Marker m) async {
    _auth.onTokenExpired = (m) async {
      log(m).i("token expired");
      linkedTokenOk = false;
      linkedMode.now = false;
      // Only a device that already held state was set up. useToken validates a
      // candidate token before persisting it, so a rejected first link reaches
      // here with nothing stored. Recorded before the wipe clears the evidence.
      if (await _currentToken.fetch(m) != null ||
          await _thisDevice.fetch(m) != null) {
        await _wasSetUp.change(m, true);
      }
      await _thisDevice.change(m, null);
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
      log(m).i("Linking device ${d.device.deviceTag}");
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

  /// True when this device has state worth protecting. WasSetUp survives a
  /// token wipe; ThisDevice and CurrentToken do not, and a refresh failure
  /// clears both. Do not gate on FamilyPhase or linkedMode, which default to
  /// the "not set up" value early in boot and would fail open.
  Future<bool> needsConfirmation(Marker m) async {
    try {
      // Read the stored account, not the loaded one: a link can arrive before
      // startup resolves it, and type reports libre while unresolved. On iOS
      // the account survives a reinstall that wipes the device state below.
      if (_account.type.isActive()) return true;
      if (await _account
          .hasActivePersistedAccount(m)
          .timeout(_predicateTimeout)) {
        return true;
      }

      if (await _wasSetUp.fetch(m).timeout(_predicateTimeout)) return true;

      final device = await _thisDevice.fetch(m).timeout(_predicateTimeout);
      if (device != null) return true;
      final token = await _currentToken.fetch(m).timeout(_predicateTimeout);
      return token != null;
    } catch (e) {
      // A racing in-flight fetch can stall. Fail closed: an extra confirmation
      // is a nuisance, a silent re-home is not.
      log(m).e(msg: "needsConfirmation failed, assuming set up: $e");
      return true;
    }
  }

  /// Parks an incoming link. Nothing is persisted until the user answers.
  ///
  /// One at a time: a second link arriving while the first still awaits an
  /// answer is dropped, rather than replacing it under an open prompt. The
  /// user re-scans if they meant the newer one.
  Future<void> requestLink(String rawInput, Marker m) async {
    return await log(m).trace("requestLink", (m) async {
      final token = parseFamilyLinkToken(rawInput);
      if (token == null) {
        // The Android scanner and CommandActivity call this command directly
        // and discard the result, so a throw alone fails silently for them.
        await _stage.showModal(StageModal.fault, m);
        throw Exception("Malformed family link");
      }
      if (_claimedLink != null) {
        log(m).i("a link already awaits an answer, dropping the new one");
        return;
      }
      _claimedLink = token;
      await pendingLink.change(m, token);
    });
  }

  /// Both answers carry the token the prompt was raised for, so an answer can
  /// only ever consume the link it was shown for.
  Future<void> cancelPendingLink(String token, Marker m) async {
    return await log(m).trace("cancelPendingLink", (m) async {
      if (_claimedLink != token) return;
      _claimedLink = null;
      await pendingLink.change(m, null);
    });
  }

  Future<void> confirmPendingLink(String token, Marker m) async {
    if (_claimedLink != token) return;
    try {
      await pendingLink.change(m, null);
      return await _commitLink(token, m);
    } finally {
      // Held across the commit: useToken and setThisDeviceForLinked persist
      // separately, so a link accepted mid-commit could pair one family's
      // token with another's device tag.
      _claimedLink = null;
    }
  }

  Future<void> _commitLink(String token, Marker m) async {
    return await log(m).trace("link", (m) async {
      try {
        final deviceTag = await _auth.useToken(token, m);
        log(m).i("received proper token for device: $deviceTag");
        await _device.setThisDeviceForLinked(deviceTag, token, m,
            confirmed: true);
        await _wasSetUp.change(m, true);
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
