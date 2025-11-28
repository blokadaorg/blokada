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
  late final _publicKey = Core.get<PublicKeyProvidedValue>();

  late final _channel = Core.get<NotificationChannel>();
  late final _json = Core.get<NotificationApi>();
  late final _notifications = Core.get<NotificationsValue>();

  late final _scheduler = Core.get<Scheduler>();

  String? _appleToken;

  @override
  onStart(Marker m) async {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, sendAppleTokenAsync);
  }

  showWithBody(NotificationId id, Marker m, String body, {DateTime? when}) async {
    return await log(m).trace("showWithPayload", (m) async {
      _addCapped(NotificationEvent.shown(id, when ?? DateTime.now().add(const Duration(seconds: 3)),
          body: body));
      await _updateChannel();
      log(m).pair("notificationId", id);
    });
  }

  show(NotificationId id, Marker m, {DateTime? when}) async {
    return await log(m).trace("show", (m) async {
      log(m).pair("when", when);

      // Always add time to current, otherwise iOS skips it
      _addCapped(
          NotificationEvent.shown(id, when ?? DateTime.now().add(const Duration(seconds: 3))));
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

  sendAppleTokenAsync(Marker m) async {
    if (Core.act.isFamily) return;
    if (_appleToken == null) return;

    // Use scheduler to make sure this does not deadlock
    // (we are in accountChanged callback)
    _scheduler.addOrUpdate(Job(
      "sendAppleToken",
      m,
      before: DateTime.now(),
      callback: sendAppleToken,
    ));
  }

  Future<bool> sendAppleToken(Marker m) async {
    final publicKey = await _publicKey.fetch(m);
    await _json.postToken(publicKey, _appleToken!, m);
    _appleToken = null;
    return false;
  }

  saveAppleToken(String appleToken) async {
    _appleToken = appleToken;
  }

  notificationTapped(Marker m, String notificationId) async {
    return await log(m).trace("notificationTapped", (m) async {
      final id = NotificationId.values.firstWhereOrNull((it) => it.name == notificationId);

      log(m).pair("id", id);
      if (id == NotificationId.supportNewMessage) {
        // await sleepAsync(const Duration(seconds: 1));
        // await _stage.setRoute(Paths.settings.path, m);
        // await sleepAsync(const Duration(seconds: 3));
        // await _stage.setRoute(Paths.support.path, m);
      } else if (id == NotificationId.weeklyReport) {
        await _stage.setRoute(Paths.privacyPulse.path, m);
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
      await _channel.doShow(event.id.name, event.when!.toUtc().toIso8601String(), event.body);
    } else if (event.type == NotificationEventType.dismiss) {
      await _channel.doDismissAll();
    }
  }
}
