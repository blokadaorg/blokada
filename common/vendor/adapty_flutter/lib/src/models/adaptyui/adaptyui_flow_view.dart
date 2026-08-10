import 'package:meta/meta.dart' show immutable;

import '../../adapty.dart';
import 'adaptyui_dialog.dart';
import 'adaptyui_ios_presentation_style.dart';
import '../private/json_builder.dart';

part '../private/adaptyui_flow_view_json_builder.dart';

@immutable
class AdaptyUIFlowView {
  /// The unique identifier of the view.
  final String id;

  /// The identifier of placement.
  final String placementId;

  /// The identifier of flow variation.
  final String variationId;

  /// The localization the view was actually built with.
  ///
  /// It is the locale passed to [AdaptyUI.createFlowView] when the flow has that
  /// localization, `en` when no locale was passed and the flow has `en`, and the
  /// flow's default localization in every other case. `null` when the native SDK
  /// is older than iOS 4.0.2 / Android 4.0.1 and does not report it.
  final String? locale;

  const AdaptyUIFlowView._(
    this.id,
    this.placementId,
    this.variationId,
    this.locale,
  );

  @override
  String toString() => '(id: $id, '
      'placementId: $placementId, '
      'variationId: $variationId, '
      'locale: $locale)';

  /// Call this function if you wish to present the view.
  Future<void> present({
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) =>
      AdaptyUI().presentFlowView(this, iosPresentationStyle: iosPresentationStyle);

  /// Call this function if you wish to dismiss the view.
  Future<void> dismiss() => AdaptyUI().dismissFlowView(this);

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
