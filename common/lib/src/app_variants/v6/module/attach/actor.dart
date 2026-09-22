part of 'attach.dart';

/// Where the hand-off lands. The token rides in the fragment so it stays out
/// of server logs and of the Referer header of whatever the dashboard loads.
const _attachLinkBase = "https://app.blokada.org/link#token=";

class AttachActor with Logging, Actor {
  late final _api = Core.get<AttachApi>();
  late final _stage = Core.get<StageStore>();
  late final _config = Core.get<ConfigChannel>();

  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  // A tap mints a token, which costs a roundtrip. Impatient double taps would
  // otherwise burn a token each (they are single use) and race to open two
  // browsers, so only the first tap of a batch is served.
  bool _creating = false;

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.attachDevice) {
        _modalWidget.change(it.m, (context) => const AttachSheet());
      }
    });
  }

  /// Opens the hand-off link in this device's browser.
  Future<void> openInBrowser(Marker m) async {
    final url = await _createLinkUrl(m);
    if (url == null) return;
    await _stage.openUrl(url, m);
  }

  /// Offers the hand-off link to the system share sheet, to be opened on
  /// another device.
  Future<void> share(Marker m) async {
    final url = await _createLinkUrl(m);
    if (url == null) return;
    // To prevent UI freeze when the share screen opens (same wait as the
    // family link sheet).
    await sleepAsync(const Duration(milliseconds: 500));
    await _config.doShareText(url);
  }

  /// Mints a link, or returns null when one is already being minted.
  ///
  /// Always a fresh token: it is single use and expires in five minutes, so a
  /// cached one would land the other device on "expired or already used".
  Future<String?> _createLinkUrl(Marker m) async {
    if (_creating) {
      log(m).i("attach link already in flight, ignoring");
      return null;
    }

    _creating = true;
    try {
      final link = await _api.createLink(m);
      return "$_attachLinkBase${link.token}";
    } on HttpCodeException catch (e, s) {
      // 403 means the account is not active. The settings row is hidden for
      // those accounts, so seeing this means the account lapsed while the
      // sheet was open.
      log(m).e(msg: "Failed creating attach link, code ${e.code}", err: e, stack: s);
      rethrow;
    } catch (e, s) {
      log(m).e(msg: "Failed creating attach link", err: e, stack: s);
      rethrow;
    } finally {
      _creating = false;
    }
  }
}
