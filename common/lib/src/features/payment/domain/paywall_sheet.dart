part of 'payment.dart';

const _adaptyPaywallMountDelay = Duration(milliseconds: 320);
const _adaptyPaywallFadeDuration = Duration(milliseconds: 450);
const _adaptyPaywallRevealDelay = Duration(milliseconds: 50);

/// Hosts the Adapty platform view inside our own modal sheet so the app, not
/// Adapty's presenter, controls tablet width and centering.
///
/// Flow events are not wired here: the SDK also delivers an embedded view's
/// events to the global observer ([AdaptyPaymentChannel]), so forwarding them
/// would handle each purchase twice.
class AdaptyEmbeddedPaywallSheet extends StatefulWidget {
  final AdaptyPaymentChannel channel;
  final AdaptyFlow flow;
  final int openSeq;

  const AdaptyEmbeddedPaywallSheet({
    super.key,
    required this.channel,
    required this.flow,
    required this.openSeq,
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
    widget.channel.handleEmbeddedPaywallMounted(this);
    Future.delayed(_adaptyPaywallMountDelay, () {
      if (!mounted) return;
      setState(() => _mountPaywallView = true);
    });
  }

  @override
  void dispose() {
    widget.channel.handleEmbeddedPaywallDisposed(this);
    super.dispose();
  }

  // Pops this sheet's own route, together with anything shown on top of it
  // (e.g. the restore message), so a plain pop never closes only the dialog.
  void dismiss() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  void showMessage({required String title, required String content, required String closeTitle}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(closeTitle)),
        ],
      ),
    );
  }

  void _onPaywallAppeared(AdaptyUIFlowView view) {
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
            AdaptyUIFlowPlatformView(
              key: ValueKey(widget.flow.instanceIdentity),
              flow: widget.flow,
              // Same exact-match localization id as the presented view.
              locale: I18n.languageOnly,
              onDidAppear: _onPaywallAppeared,
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.theme.accent),
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
