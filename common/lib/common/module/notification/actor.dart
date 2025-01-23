part of 'notification.dart';

/// NotificationActor
///
/// Manages notifications, which are used to display information to the user.
/// They are also used to grab user attention to come back to the app, so that
/// we can do stuff in foreground (like refresh account).

class NotificationActor with Logging, Actor {
  // TODO: fix those dependencies
  late final _stage = Core.get<StageStore>();
  late final _account = Core.get<AccountStore>();
  late final _keypair = Core.get<PlusKeypairStore>();

  late final _channel = Core.get<NotificationChannel>();
  late final _json = Core.get<NotificationApi>();
  late final _notifications = Core.get<NotificationsValue>();

  String? _appleToken;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, sendAppleToken);
  }

  showWithBody(NotificationId id, Marker m, String body,
      {DateTime? when}) async {
    return await log(m).trace("showWithPayload", (m) async {
      _addCapped(NotificationEvent.shown(
          id, when ?? DateTime.now().add(const Duration(seconds: 3)),
          body: body));
      await _updateChannel();
      log(m).pair("notificationId", id);
    });
  }

  show(NotificationId id, Marker m, {DateTime? when}) async {
    return await log(m).trace("show", (m) async {
      // Always add time to current, otherwise iOS skips it
      _addCapped(NotificationEvent.shown(
          id, when ?? DateTime.now().add(const Duration(seconds: 3))));
      await _updateChannel();
      log(m).pair("notificationId", id);
    });
  }

  // Only dismisses all notifications for now
  dismiss(Marker m, {NotificationId id = NotificationId.all}) async {
    return await log(m).trace("dismissAll", (m) async {
      _addCapped(NotificationEvent.dismissed());
      await _updateChannel();
    });
  }

  onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;

    return await log(m).trace("dismissNotifications", (m) async {
      await dismiss(m);
    });
  }

  sendAppleToken(Marker m) async {
    if (_appleToken == null) return;
    if (Core.act.isFamily) return;
    return await log(m).trace("sendAppleToken", (m) async {
      await _json.postToken(
          _keypair.currentKeypair!.publicKey, _appleToken!, m);
      _appleToken = null;
    });
  }

  saveAppleToken(String appleToken) async {
    _appleToken = appleToken;
  }

  notificationTapped(Marker m, String notificationId) async {
    return await log(m).trace("notificationTapped", (m) async {
      final id = NotificationId.values
          .firstWhereOrNull((it) => it.name == notificationId);

      log(m).pair("id", id);
      if (id == NotificationId.supportNewMessage) {
        // await sleepAsync(const Duration(seconds: 1));
        // await _stage.setRoute(Paths.settings.path, m);
        // await sleepAsync(const Duration(seconds: 3));
        // await _stage.setRoute(Paths.support.path, m);
      }
    });
  }

  _addCapped(NotificationEvent event) {
    final notifications = _notifications.now.toList();
    notifications.add(event);
    if (notifications.length > 100) {
      notifications.removeAt(0);
    }
    _notifications.now = notifications;
  }

  _updateChannel() async {
    final event = _notifications.now.last;
    if (event.type == NotificationEventType.show) {
      await _channel.doShow(
          event.id.name, event.when!.toUtc().toIso8601String(), event.body);
    } else if (event.type == NotificationEventType.dismiss) {
      await _channel.doDismissAll();
    }
  }
}
