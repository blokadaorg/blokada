part of 'payment.dart';

const _adaptyPaywallHeightFactor = 0.9;

/// Hosts the Adapty platform view inside our own modal sheet so the app, not
/// Adapty's presenter, controls tablet width and centering.
class AdaptyEmbeddedPaywallSheet extends StatefulWidget {
  final AdaptyPaymentChannel channel;
  final AdaptyPaywall paywall;

  const AdaptyEmbeddedPaywallSheet({
    super.key,
    required this.channel,
    required this.paywall,
  });

  @override
  State<AdaptyEmbeddedPaywallSheet> createState() => _AdaptyEmbeddedPaywallSheetState();
}

class _AdaptyEmbeddedPaywallSheetState extends State<AdaptyEmbeddedPaywallSheet> {
  @override
  void dispose() {
    widget.channel.handleEmbeddedPaywallDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * _adaptyPaywallHeightFactor;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.theme.bgColorCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdaptyUIPaywallPlatformView(
            key: ValueKey(widget.paywall.instanceIdentity),
            paywall: widget.paywall,
            onDidAppear: widget.channel.paywallViewDidAppear,
            onDidDisappear: widget.channel.paywallViewDidDisappear,
            onDidPerformAction: widget.channel.paywallViewDidPerformAction,
            onDidSelectProduct: widget.channel.paywallViewDidSelectProduct,
            onDidStartPurchase: widget.channel.paywallViewDidStartPurchase,
            onDidFinishPurchase: widget.channel.paywallViewDidFinishPurchase,
            onDidFailPurchase: widget.channel.paywallViewDidFailPurchase,
            onDidStartRestore: widget.channel.paywallViewDidStartRestore,
            onDidFinishRestore: widget.channel.paywallViewDidFinishRestore,
            onDidFailRestore: widget.channel.paywallViewDidFailRestore,
            onDidFailRendering: widget.channel.paywallViewDidFailRendering,
            onDidFailLoadingProducts: widget.channel.paywallViewDidFailLoadingProducts,
            onDidFinishWebPaymentNavigation: widget.channel.paywallViewDidFinishWebPaymentNavigation,
          ),
        ),
      ),
    );
  }
}
