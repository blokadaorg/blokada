part of 'payment.dart';

class AdaptyApiKey {
  String get() {
    var apiKey = "public_live_jIrWAAbd.q43qsMhj7rTLOpF3zGBd";
    if (Core.act.isFamily) {
      apiKey = "public_live_6b1uSAaQ.EVLlSnbFDIarK82Qkqiv";
    }
    return apiKey;
  }
}
