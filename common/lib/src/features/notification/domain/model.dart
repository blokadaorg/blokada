part of 'notification.dart';

class NotificationEvent {
  final NotificationId id;
  final NotificationEventType type;
  final DateTime? when;
  final String? body;

  NotificationEvent.shown(this.id, this.when, {this.body}) : type = NotificationEventType.show;

  NotificationEvent.dismissed({this.id = NotificationId.all})
      : type = NotificationEventType.dismiss,
        when = null,
        body = null;
}

enum NotificationId {
  all,
  accountExpired,
  accountExpiredFamily,
  supportNewMessage,
  weeklyReport,
  weeklyRefresh,
  activityLoggingReminder,
}

enum NotificationEventType {
  show,
  dismiss,
}
