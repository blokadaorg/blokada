import 'package:common/core/core.dart';
import 'package:common/dragon/navigation.dart';
import 'package:common/platform/notification/notification.dart';
import 'package:common/platform/stage/stage.dart';

class SupportUnread extends AsyncValue<bool> {
  late final _persistence = DI.get<Persistence>();

  static const key = "support_unread";

  @override
  Future<bool> doLoad() async {
    return (await _persistence.load(key)) == "1";
  }

  @override
  doSave(bool value) async {
    await _persistence.save(key, value ? "1" : "0");
  }
}

class SupportUnreadController with Logging, Actor {
  late final _unread = DI.get<SupportUnread>();
  late final _notification = DI.get<NotificationStore>();
  late final _stage = DI.get<StageStore>();

  bool isForeground = true;
  bool isOnSupportScreen = false;

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
    if (!isOnSupportScreen) {
      log(m).i("Setting chat unread flag");
      _unread.change(m, true);
      if (!isForeground) {
        await _notification.showWithBody(
            NotificationId.supportNewMessage, m, content);
      }
    }
  }

  wentBackFromSupport() {
    _update(Markers.support, isOnSupportScreen: false);
  }

  _update(Marker m, {bool? isForeground, bool? isOnSupportScreen}) {
    this.isForeground = isForeground ?? this.isForeground;
    this.isOnSupportScreen = isOnSupportScreen ?? this.isOnSupportScreen;

    log(m).params({
      "isForeground": this.isForeground,
      "isOnSupportScreen": this.isOnSupportScreen,
    });

    if (this.isForeground && this.isOnSupportScreen) {
      _unread.change(m, false);
      log(m).i("Clearing chat unread flag");
    }
  }
}
