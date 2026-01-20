part of 'notification.dart';

class NotificationCommand with Command, Logging {
  late final _actor = Core.get<NotificationActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("notificationTapped",
          fn: cmdNotificationTapped, argsNum: 1),
      registerCommand("appleNotificationToken",
          fn: cmdAppleNotificationToken, argsNum: 1),
      registerCommand("fcmNotificationToken",
          fn: cmdFcmNotificationToken, argsNum: 1),
    ];
  }

  Future<void> cmdNotificationTapped(Marker m, dynamic args) async {
    final id = args[0] as String;
    await _actor.notificationTapped(m, id);
  }

  Future<void> cmdAppleNotificationToken(Marker m, dynamic args) async {
    final token = args[0] as String;
    await _actor.saveAppleToken(token);
  }

  Future<void> cmdFcmNotificationToken(Marker m, dynamic args) async {
    final token = args[0] as String;
    await _actor.saveFcmToken(token);
  }
}
