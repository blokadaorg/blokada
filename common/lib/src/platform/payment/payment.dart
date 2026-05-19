import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/payment/channel.pg.dart';

part 'channel.dart';

class PlatformPaymentModule with Module, Logging {
  @override
  onCreateModule() async {
    if (Core.act.isMocked) {
      // Adapty's StoreKit2 init crashes on iOS Simulator. The mocked entry
      // points pre-seed an active dev account so the paywall never opens.
      await register<PaymentChannel>(MockPaymentChannel());
    } else if (Core.act.isAndroid && !Core.act.isFamily) {
      // This is a temporary android Adapty SDK integration.
      // We are using it only until Adapty flutter SDK supports prorate modes.
      // Then this "if" can be dropped
      await register<PaymentChannel>(PlatformPaymentChannel());
    } else {
      await register<PaymentChannel>(AdaptyPaymentChannel());
    }
  }
}
