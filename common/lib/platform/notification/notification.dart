import 'package:collection/collection.dart';
import 'package:common/core/core.dart';
import 'package:mobx/mobx.dart';

import '../../util/mobx.dart';
import '../account/account.dart';
import '../stage/stage.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'notification.g.dart';

class NotificationEvent {
  final NotificationId id;
  final NotificationEventType type;
  final DateTime? when;
  final String? body;

  NotificationEvent.shown(this.id, this.when, {this.body})
      : type = NotificationEventType.show;

  NotificationEvent.dismissed()
      : id = NotificationId.all,
        type = NotificationEventType.dismiss,
        when = null,
        body = null;
}

enum NotificationId {
  all,
  accountExpired,
  accountExpiredFamily,
  supportNewMessage,
}

enum NotificationEventType {
  show,
  dismiss,
}

/// NotificationStore
///
/// Manages notifications, which are used to display information to the user.
/// They are also used to grab user attention to come back to the app, so that
/// we can do stuff in foreground (like refresh account).

class NotificationStore = NotificationStoreBase with _$NotificationStore;

abstract class NotificationStoreBase with Store, Logging, Dependable {
  late final _ops = dep<NotificationOps>();
  late final _stage = dep<StageStore>();
  late final _account = dep<AccountStore>();
  late final _json = dep<NotificationJson>();

  String? appleToken;

  NotificationStoreBase() {
    _stage.addOnValue(routeChanged, onRouteChanged);
    _account.addOn(accountChanged, sendAppleToken);

    reactionOnStore((_) => notificationChanges, (_) async {
      final event = notifications.last;
      if (event.type == NotificationEventType.show) {
        await _ops.doShow(
            event.id.name, event.when!.toUtc().toIso8601String(), event.body);
      } else if (event.type == NotificationEventType.dismiss) {
        await _ops.doDismissAll();
      }
    });
  }

  @override
  attach(Act act) {
    depend<NotificationOps>(getOps(act));
    depend<NotificationJson>(NotificationJson());
    depend<NotificationStore>(this as NotificationStore);
  }

  @observable
  ObservableList<NotificationEvent> notifications = ObservableList();

  // I don't get how triggers for lists/maps work in mobx
  @observable
  int notificationChanges = 0;

  @action
  Future<void> showWithBody(NotificationId id, Marker m, String body,
      {DateTime? when}) async {
    return await log(m).trace("showWithPayload", (m) async {
      _addCapped(NotificationEvent.shown(
          id, when ?? DateTime.now().add(const Duration(seconds: 3)),
          body: body));
      log(m).pair("notificationId", id);
    });
  }

  @action
  Future<void> show(NotificationId id, Marker m, {DateTime? when}) async {
    return await log(m).trace("show", (m) async {
      // Always add time to current, otherwise iOS skips it
      _addCapped(NotificationEvent.shown(
          id, when ?? DateTime.now().add(const Duration(seconds: 3))));
      log(m).pair("notificationId", id);
    });
  }

  // Only dismisses all notifications for now
  @action
  Future<void> dismiss(Marker m,
      {NotificationId id = NotificationId.all}) async {
    return await log(m).trace("dismissAll", (m) async {
      _addCapped(NotificationEvent.dismissed());
    });
  }

  @action
  Future<void> onRouteChanged(StageRouteState route, Marker m) async {
    if (!route.isBecameForeground()) return;

    return await log(m).trace("dismissNotifications", (m) async {
      await dismiss(m);
    });
  }

  @action
  Future<void> sendAppleToken(Marker m) async {
    if (appleToken == null) return;
    if (act.isFamily()) return;
    return await log(m).trace("sendAppleToken", (m) async {
      await _json.postToken(appleToken!, m);
      appleToken = null;
    });
  }

  @action
  Future<void> saveAppleToken(String appleToken, Marker m) async {
    return await log(m).trace("saveAppleToken", (m) async {
      this.appleToken = appleToken;
    });
  }

  notificationTapped(String notificationId, Marker m) async {
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
    notifications.add(event);
    if (notifications.length > 100) {
      notifications.removeAt(0);
    }
    notificationChanges++;
  }
}
