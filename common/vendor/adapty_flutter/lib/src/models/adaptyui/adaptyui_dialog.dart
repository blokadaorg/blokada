import 'package:meta/meta.dart' show immutable;

part '../private/adaptyui_dialog_json_builder.dart';

enum AdaptyUIDialogActionType {
  primary,
  secondary,
}

@immutable
class AdaptyUIDialog {
  final String? title;
  final String? content;
  final String primaryActionTitle;
  final String? secondaryActionTitle;

  const AdaptyUIDialog({
    this.title,
    this.content,
    required this.primaryActionTitle,
    this.secondaryActionTitle,
  });
}
