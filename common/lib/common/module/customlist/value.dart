part of 'customlist.dart';

class CustomlistPayloadValue extends Value<CustomlistPayload> {
  CustomlistPayloadValue()
      : super(load: () => CustomlistPayload(denied: [], allowed: []));

  reset() => now = CustomlistPayload(denied: [], allowed: []);
}
