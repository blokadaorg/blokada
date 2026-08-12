// ignore_for_file: deprecated_member_use_from_same_package
import 'package:meta/meta.dart' show immutable;

import '../../adapty.dart';
import 'adaptyui_dialog.dart';
import 'adaptyui_ios_presentation_style.dart';
import '../private/json_builder.dart';

part '../private/adaptyui_onboarding_view_json_builder.dart';

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
@immutable
class AdaptyUIOnboardingView {
  /// The unique identifier of the view.
  final String id;

  /// The identifier of paywall.
  final String placementId;

  /// The identifier of paywall variation.
  final String variationId;

  const AdaptyUIOnboardingView._(
    this.id,
    this.placementId,
    this.variationId,
  );

  /// Whether the onboarding is rendered in a Flutter widget.
  bool get isWidgetRendering => id.startsWith('flutter_native_');

  /// Whether the onboarding is rendered as a native modal view.
  bool get isNativeRendering => !isWidgetRendering;

  @override
  String toString() => 'AdaptyUIOnboardingView(id: $id, '
      'placementId: $placementId, '
      'variationId: $variationId)';

  /// Call this function if you wish to present the view.
  Future<void> present({
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) =>
      AdaptyUI().presentOnboardingView(this, iosPresentationStyle: iosPresentationStyle);

  /// Call this function if you wish to dismiss the view.
  Future<void> dismiss() => AdaptyUI().dismissOnboardingView(this);

  /// Call this function if you wish to present the dialog.
  ///
  /// **Parameters**
  /// - [title]: The title of the dialog.
  /// - [content]: Descriptive text that provides additional details about the reason for the dialog.
  /// - [primaryActionTitle]: The action title to display as part of the dialog. If you provide two actions, be sure the `defaultAction` cancels the operation and leaves things unchanged.
  /// - [secondaryActionTitle]: The secondary action title to display as part of the dialog.
  Future<AdaptyUIDialogActionType> showDialog({
    required String title,
    required String content,
    required String primaryActionTitle,
    String? secondaryActionTitle,
  }) =>
      AdaptyUI().showDialog(
        id,
        title: title,
        content: content,
        primaryActionTitle: primaryActionTitle,
        secondaryActionTitle: secondaryActionTitle,
      );
}
