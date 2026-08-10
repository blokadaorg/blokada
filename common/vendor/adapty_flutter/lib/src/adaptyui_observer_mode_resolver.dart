import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adapty_paywall_product.dart';

abstract class AdaptyUIObserverModeResolver {
  void observerModeDidInitiatePurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product,
      void Function() onStartPurchase, void Function() onFinishPurchase);

  void observerModeDidInitiateRestore(AdaptyUIFlowView view,
      void Function() onStartRestore, void Function() onFinishRestore);
}
