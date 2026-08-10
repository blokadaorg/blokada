class AdaptyUIPermission {
  final String value; // wire string (inverse of iOS init(jsString:))

  const AdaptyUIPermission(this.value);

  static const push = AdaptyUIPermission('push');
  static const camera = AdaptyUIPermission('camera');
  static const microphone = AdaptyUIPermission('microphone');
  static const locationWhenInUse = AdaptyUIPermission('location_when_use');
  static const locationAlways = AdaptyUIPermission('location_always');
  static const locationFullAccuracy = AdaptyUIPermission('location_full_accuracy');
  static const photos = AdaptyUIPermission('photos');
  static const contacts = AdaptyUIPermission('contacts');
  static const tracking = AdaptyUIPermission('tracking');
  static const calendar = AdaptyUIPermission('calendar');
  static const bluetooth = AdaptyUIPermission('bluetooth');
  static const motion = AdaptyUIPermission('motion');
  static const reminders = AdaptyUIPermission('reminders');
  static const speech = AdaptyUIPermission('speech');
  static const mediaLibrary = AdaptyUIPermission('media_library');
  static const localNetwork = AdaptyUIPermission('local_network');
  static const focusStatus = AdaptyUIPermission('focus_status');
  static const homekit = AdaptyUIPermission('homekit');
  static const health = AdaptyUIPermission('health');
  static const siri = AdaptyUIPermission('siri');
  static const music = AdaptyUIPermission('music');

  @override
  bool operator ==(Object other) => other is AdaptyUIPermission && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AdaptyUIPermission($value)';
}
