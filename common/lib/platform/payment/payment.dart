import 'package:common/common/module/payment/payment.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/payment/channel.pg.dart';

part 'channel.dart';

class PlatformPaymentModule with Module, Logging {
  @override
  onCreateModule() async {
    if (Core.act.platform == PlatformType.android && !Core.act.isFamily) {
      // This is a temporary android Adapty SDK integration.
      // We are using it only until Adapty flutter SDK supports prorate modes.
      // Then this "if" can be dropped
      await register<PaymentChannel>(PlatformPaymentChannel());
    } else {
      await register<PaymentChannel>(AdaptyPaymentChannel());
    }
  }
}
