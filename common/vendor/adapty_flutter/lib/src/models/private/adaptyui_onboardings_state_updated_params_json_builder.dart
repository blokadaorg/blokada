// ignore_for_file: deprecated_member_use_from_same_package
part of '../adaptyui/adaptyui_onboarding_state_updated_params.dart';

extension AdaptyOnboardingsStateUpdatedParamsJSONBuilder on AdaptyOnboardingsStateUpdatedParams {
  static AdaptyOnboardingsStateUpdatedParams fromJsonValue(Map<String, dynamic> json) {
    final elementType = json[_StateUpdatedParamsKeys.elementType] as String;

    switch (elementType) {
      case _StateUpdatedParamsKeys.elementTypeSelect:
        final value = json[_StateUpdatedParamsKeys.value] as Map<String, dynamic>;

        return AdaptyOnboardingsSelectParamsJSONBuilder.fromJsonValue(value);
      case _StateUpdatedParamsKeys.elementTypeMultiSelect:
        final value = json[_StateUpdatedParamsKeys.value] as List<dynamic>;

        final params = value.map((e) => AdaptyOnboardingsSelectParamsJSONBuilder.fromJsonValue(e)).toList();

        return AdaptyOnboardingsMultiSelectParams(params: params);
      case _StateUpdatedParamsKeys.elementTypeInput:
        final inputValue = json[_StateUpdatedParamsKeys.value] as Map<String, dynamic>;
        final input = AdaptyOnboardingsInputJSONBuilder.fromJsonValue(inputValue);

        return AdaptyOnboardingsInputParams(input: input);
      case _StateUpdatedParamsKeys.elementTypeDatePicker:
        final value = json[_StateUpdatedParamsKeys.value] as Map<String, dynamic>;

        final day = value[_StateUpdatedParamsKeys.elementTypeDatePickerValueDay];
        final month = value[_StateUpdatedParamsKeys.elementTypeDatePickerValueMonth];
        final year = value[_StateUpdatedParamsKeys.elementTypeDatePickerValueYear];

        return AdaptyOnboardingsDatePickerParams(
          day: day,
          month: month,
          year: year,
        );
      default:
        throw Exception('Unknown element type: $elementType');
    }
  }
}

class _StateUpdatedParamsKeys {
  static const elementType = 'element_type';
  static const value = 'value';

  static const elementTypeSelect = 'select';

  static const elementTypeMultiSelect = 'multi_select';

  static const elementTypeInput = 'input';

  static const elementTypeDatePicker = 'date_picker';
  static const elementTypeDatePickerValueDay = 'day';
  static const elementTypeDatePickerValueMonth = 'month';
  static const elementTypeDatePickerValueYear = 'year';
}

extension AdaptyOnboardingsSelectParamsJSONBuilder on AdaptyOnboardingsSelectParams {
  static AdaptyOnboardingsSelectParams fromJsonValue(Map<String, dynamic> json) {
    return AdaptyOnboardingsSelectParams(
      id: json[_SelectKeys.elementTypeSelectId],
      value: json[_SelectKeys.elementTypeSelectValue],
      label: json[_SelectKeys.elementTypeSelectLabel],
    );
  }
}

class _SelectKeys {
  static const elementTypeSelectId = 'id';
  static const elementTypeSelectValue = 'value';
  static const elementTypeSelectLabel = 'label';
}

extension AdaptyOnboardingsInputJSONBuilder on AdaptyOnboardingsInput {
  static AdaptyOnboardingsInput fromJsonValue(Map<String, dynamic> json) {
    return AdaptyOnboardingsTextInput(value: json[_InputKeys.elementTypeInputValue]);
  }
}

class _InputKeys {
  static const elementTypeInputValue = 'value';
}
