import '../private/json_builder.dart';
import 'package:meta/meta.dart' show immutable;

import '../adapty_web_presentation.dart';

part '../private/adaptyui_action_json_builder.dart';

@immutable
sealed class AdaptyUIAction {
  const AdaptyUIAction();
}

// Close Button was pressed by user
final class CloseAction extends AdaptyUIAction {
  const CloseAction();
}

/// Some button which contains url (e.g. Terms or Privacy & Policy) was pressed by user
final class OpenUrlAction extends AdaptyUIAction {
  final String url;

  /// Where the URL should be opened — in an external browser or in an in-app browser.
  final AdaptyWebPresentation openIn;

  const OpenUrlAction(this.url, this.openIn);
}

/// Some button with custom action (e.g. Login) was pressed by user
final class CustomAction extends AdaptyUIAction {
  final String action;
  const CustomAction(this.action);
}

/// Android Back Button was pressed by user
final class AndroidSystemBackAction extends AdaptyUIAction {
  const AndroidSystemBackAction();
}
