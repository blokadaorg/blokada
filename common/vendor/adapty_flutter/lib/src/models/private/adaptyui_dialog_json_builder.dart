part of '../adaptyui/adaptyui_dialog.dart';

extension AdaptyUIDialogJSONBuilder on AdaptyUIDialog {
  dynamic get jsonValue => {
        if (title != null) _DialogKeys.title: title,
        if (content != null) _DialogKeys.content: content,
        _DialogKeys.primaryActionTitle: primaryActionTitle,
        if (secondaryActionTitle != null) _DialogKeys.secondaryActionTitle: secondaryActionTitle,
      };
}

extension AdaptyUIDialogActionTypeJSONBuilder on AdaptyUIDialogActionType {
  static AdaptyUIDialogActionType fromJsonValue(String json) {
    switch (json) {
      case 'secondary':
        return AdaptyUIDialogActionType.secondary;
      default:
        return AdaptyUIDialogActionType.primary;
    }
  }
}

class _DialogKeys {
  static const title = 'title';
  static const content = 'content';
  static const primaryActionTitle = 'default_action_title';
  static const secondaryActionTitle = 'secondary_action_title';
}
