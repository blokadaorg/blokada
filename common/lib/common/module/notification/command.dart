part of 'notification.dart';

class SupportCommand with Command, Logging {
  late final _actor = Core.get<NotificationActor>();

  @override
  List<CommandSpec> onRegisterCommands() {
    return [
      registerCommand("notificationTapped", fn: cmdNotificationTapped),
      registerCommand("appleNotificationToken", fn: cmdAppleNotificationToken),
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
}
