part of 'payment.dart';

const _adaptyPaywallMountDelay = Duration(milliseconds: 320);
const _adaptyPaywallFadeDuration = Duration(milliseconds: 450);
const _adaptyPaywallRevealDelay = Duration(milliseconds: 50);

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
  bool _mountPaywallView = false;
  bool _revealPaywall = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_adaptyPaywallMountDelay, () {
      if (!mounted) return;
      setState(() => _mountPaywallView = true);
    });
  }

  @override
  void dispose() {
    widget.channel.handleEmbeddedPaywallDisposed();
    super.dispose();
  }

  void _onPaywallAppeared(AdaptyUIPaywallView view) {
    widget.channel.paywallViewDidAppear(view);
    Future.delayed(_adaptyPaywallRevealDelay, () {
      if (!mounted) return;
      setState(() => _revealPaywall = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColorCard,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_mountPaywallView)
            AdaptyUIPaywallPlatformView(
              key: ValueKey(widget.paywall.instanceIdentity),
              paywall: widget.paywall,
              onDidAppear: _onPaywallAppeared,
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
              onDidFinishWebPaymentNavigation:
                  widget.channel.paywallViewDidFinishWebPaymentNavigation,
            ),
          AnimatedOpacity(
            opacity: _revealPaywall ? 0 : 1,
            duration: _adaptyPaywallFadeDuration,
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: true,
              child: ColoredBox(
                color: context.theme.bgColorCard,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.theme.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
