part of '../adaptyui/adaptyui_action.dart';

extension AdaptyUIActionJSONBuilder on AdaptyUIAction {
  static AdaptyUIAction fromJsonValue(Map<String, dynamic> json) {
    final typeString = json.string(_Keys.type);

    switch (typeString) {
      case 'close':
        return const CloseAction();
      case 'system_back':
        return const AndroidSystemBackAction();
      case 'open_url':
        final value = json.string(_Keys.value);
        final openIn = AdaptyWebPresentationJSONBuilder.fromJsonValue(json.string(_Keys.openIn));
        return OpenUrlAction(value, openIn);
      case 'custom':
        final value = json.string(_Keys.value);
        return CustomAction(value);
      default:
        return CustomAction('Unknown action type: $typeString');
    }
  }
}

class _Keys {
  static const type = 'type';
  static const value = 'value';
  static const openIn = 'open_in';
}
