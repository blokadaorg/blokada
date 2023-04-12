import 'package:common/notification/channel.pg.dart';
import 'package:mobx/mobx.dart';

import '../util/di.dart';
import '../util/trace.dart';

part 'notification.g.dart';

class NotificationEvent {
  final NotificationId id;
  final NotificationEventType type;
  final DateTime? when;
  final NotificationPayload? payload;

  NotificationEvent.shown(this.id, this.when, {this.payload})
      : type = NotificationEventType.show;

  NotificationEvent.dismissed(this.id)
      : type = NotificationEventType.dismiss,
        when = null,
        payload = null;
}

class NotificationPayload {}

enum NotificationId {
  accountExpired,
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

abstract class NotificationStoreBase with Store, Traceable {
  @observable
  List<NotificationEvent> notifications = [];

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

  @action
  Future<void> dismiss(Trace parentTrace, NotificationId id) async {
    return await traceWith(parentTrace, "dismiss", (trace) async {
      _addCapped(NotificationEvent.dismissed(id));
      trace.addAttribute("notificationId", id);
    });
  }

  _addCapped(NotificationEvent event) {
    notifications.add(event);
    if (notifications.length > 100) {
      notifications.removeAt(0);
    }
  }
}

class NotificationBinder extends NotificationEvents with Traceable {
  late final _store = di<NotificationStore>();
  late final _ops = di<NotificationOps>();

  NotificationBinder() {
    NotificationEvents.setup(this);
    _onNotificationEvent();
  }

  NotificationBinder.forTesting() {
    _onNotificationEvent();
  }

  @override
  Future<void> onUserAction(String notificationId) async {
    await traceAs("onUserAction", (trace) async {
      await _store.dismiss(trace, NotificationId.values.byName(notificationId));
    });
  }

  _onNotificationEvent() {
    reaction((_) => _store.notifications.last, (event) async {
      await traceAs("onNotificationEvent", (trace) async {
        if (event.type == NotificationEventType.show) {
          await _ops.doShow(event.id.name, event.when!.toIso8601String());
        } else if (event.type == NotificationEventType.dismiss) {
          await _ops.doDismiss(event.id.name);
        } else {
          throw Exception("Unknown event type: ${event.type}");
        }
      });
    });
  }
}

Future<void> init() async {
  di.registerSingleton<NotificationOps>(NotificationOps());
  di.registerSingleton<NotificationStore>(NotificationStore());
  NotificationBinder();
}
