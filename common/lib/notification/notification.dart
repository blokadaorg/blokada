import 'package:mobx/mobx.dart';

import '../account/account.dart';
import '../stage/stage.dart';
import '../util/di.dart';
import '../util/mobx.dart';
import '../util/trace.dart';
import 'channel.act.dart';
import 'channel.pg.dart';
import 'json.dart';

part 'notification.g.dart';

class NotificationEvent {
  final NotificationId id;
  final NotificationEventType type;
  final DateTime? when;
  final NotificationPayload? payload;

  NotificationEvent.shown(this.id, this.when, {this.payload})
      : type = NotificationEventType.show;

  NotificationEvent.dismissed()
      : id = NotificationId.all,
        type = NotificationEventType.dismiss,
        when = null,
        payload = null;
}

class NotificationPayload {}

enum NotificationId {
  all,
  accountExpired,
  accountExpiredFamily,
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

abstract class NotificationStoreBase with Store, Traceable, Dependable {
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
        await _ops.doShow(event.id.name, event.when!.toIso8601String());
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
  Future<void> showWithPayload(
      Trace parentTrace, NotificationId id, NotificationPayload payload,
      {DateTime? when}) async {
    return await traceWith(parentTrace, "showWithPayload", (trace) async {
      _addCapped(NotificationEvent.shown(id, when ?? DateTime.now(),
          payload: payload));
      trace.addAttribute("notificationId", id);
    });
  }

  @action
  Future<void> show(Trace parentTrace, NotificationId id,
      {DateTime? when}) async {
    return await traceWith(parentTrace, "show", (trace) async {
      _addCapped(NotificationEvent.shown(id, when ?? DateTime.now()));
      trace.addAttribute("notificationId", id);
    });
  }

  // TODO: for now we just have one notification so dismiss all
  @action
  Future<void> dismiss(Trace parentTrace,
      {NotificationId id = NotificationId.all}) async {
    return await traceWith(parentTrace, "dismissAll", (trace) async {
      _addCapped(NotificationEvent.dismissed());
    });
  }

  @action
  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isBecameForeground()) return;

    return await traceWith(parentTrace, "dismissNotifications", (trace) async {
      await dismiss(trace);
    });
  }

  @action
  Future<void> sendAppleToken(Trace parentTrace) async {
    if (appleToken == null) return;
    if (act.isFamily()) return;
    return await traceWith(parentTrace, "sendAppleToken", (trace) async {
      await _json.postToken(trace, appleToken!);
      appleToken = null;
    });
  }

  @action
  Future<void> saveAppleToken(Trace parentTrace, String appleToken) async {
    return await traceWith(parentTrace, "saveAppleToken", (trace) async {
      this.appleToken = appleToken;
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
