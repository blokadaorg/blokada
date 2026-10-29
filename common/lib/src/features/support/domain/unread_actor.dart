part of 'support.dart';

/// Keeps the unread flag (and the reply notification) for support replies
/// that land while the user is not looking at the chat.
///
/// The chat is being read while the app is in the foreground and either the
/// support route is on screen or the support sheet is open. Without the sheet
/// check, a reply arriving while the sheet is up would be flagged unread
/// although the user just read it.
class SupportUnreadActor with Logging, Actor {
  late final _unread = Core.get<SupportUnread>();
  late final _notification = Core.get<NotificationActor>();
  late final _stage = Core.get<StageStore>();

  bool isForeground = true;
  bool isOnSupportScreen = false;
  bool isSheetOpen = false;

  /// Whether the chat is on screen, as a route or as the sheet.
  bool get isShowingChat => isOnSupportScreen || isSheetOpen;

  @override
  onStart(Marker m) async {
    Navigation.onNavigated = (path) {
      _update(Markers.support, isOnSupportScreen: path == Paths.support);
    };
    _stage.addOnValue(routeChanged, onRouteChanged);
    await _unread.fetch(m);
  }

  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (route.isBecameForeground()) {
      _update(m, isForeground: true);
    } else if (!route.isForeground()) {
      _update(m, isForeground: false);
    }
  }

  newMessage(Marker m, String content) async {
    log(m).t("New chat message");
    // A chat left open in the background is not being read, so its replies
    // still get the flag and the notification.
    if (!(isForeground && isShowingChat)) {
      log(m).i("Setting chat unread flag");
      await _unread.change(m, true);
      if (!isForeground) {
        // Without notification permission iOS refuses it; the reply itself
        // already arrived, so this must not fail the send.
        try {
          await _notification.showWithBody(NotificationId.supportNewMessage, m, content);
        } catch (e) {
          log(m).w("Could not show the reply notification: $e");
        }
      }
    }
  }

  wentBackFromSupport() {
    _update(Markers.support, isOnSupportScreen: false);
  }

  /// Called by the sheet itself, so the flag follows the sheet however it
  /// was opened or closed (the × button, a swipe down, or a tap outside).
  void sheetOpened() {
    _update(Markers.support, isSheetOpen: true);
  }

  void sheetClosed() {
    _update(Markers.support, isSheetOpen: false);
  }

  void _update(Marker m, {bool? isForeground, bool? isOnSupportScreen, bool? isSheetOpen}) {
    this.isForeground = isForeground ?? this.isForeground;
    this.isOnSupportScreen = isOnSupportScreen ?? this.isOnSupportScreen;
    this.isSheetOpen = isSheetOpen ?? this.isSheetOpen;

    log(m).params({
      "isForeground": this.isForeground,
      "isOnSupportScreen": this.isOnSupportScreen,
      "isSheetOpen": this.isSheetOpen,
    });

    if (this.isForeground && isShowingChat) {
      _unread.change(m, false);
      log(m).i("Clearing chat unread flag");
    }
  }
}
