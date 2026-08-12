// ignore_for_file: deprecated_member_use_from_same_package
import 'adaptyui_onboardings_input.dart';

part '../private/adaptyui_onboardings_state_updated_params_json_builder.dart';

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
sealed class AdaptyOnboardingsStateUpdatedParams {
  const AdaptyOnboardingsStateUpdatedParams();
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsSelectParams extends AdaptyOnboardingsStateUpdatedParams {
  final String id;
  final String value;
  final String label;

  const AdaptyOnboardingsSelectParams({
    required this.id,
    required this.value,
    required this.label,
  });

  @override
  String toString() {
    return 'AdaptyOnboardingsSelectParams(id: $id, value: $value, label: $label)';
  }
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsMultiSelectParams extends AdaptyOnboardingsStateUpdatedParams {
  final List<AdaptyOnboardingsSelectParams> params;

  const AdaptyOnboardingsMultiSelectParams({
    required this.params,
  });

  @override
  String toString() {
    return 'AdaptyOnboardingsMultiSelectParams(params: $params)';
  }
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsInputParams extends AdaptyOnboardingsStateUpdatedParams {
  final AdaptyOnboardingsInput input;

  const AdaptyOnboardingsInputParams({
    required this.input,
  });

  @override
  String toString() {
    return 'AdaptyOnboardingsInputParams(input: $input)';
  }
}

@Deprecated('Starting Adapty SDK 4.0.0, Onboarding Feature is deprecated. Please consider migrating to Flows')
class AdaptyOnboardingsDatePickerParams extends AdaptyOnboardingsStateUpdatedParams {
  final int? day;
  final int? month;
  final int? year;

  const AdaptyOnboardingsDatePickerParams({
    this.day,
    this.month,
    this.year,
  });

  @override
  String toString() {
    return 'AdaptyOnboardingsDatePickerParams(day: $day, month: $month, year: $year)';
  }
}
