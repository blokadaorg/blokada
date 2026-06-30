import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/modal/ui/blur_background.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FreemiumScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Placement placement;

  const FreemiumScreen({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.placement,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _FreemiumScreenState();
}

class _FreemiumScreenState extends State<FreemiumScreen>
    with TickerProviderStateMixin, Logging, Disposables {
  final _payment = Core.get<PaymentActor>();

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          IgnorePointer(
            child: BlurBackground(
              key: bgStateKey,
              bgColor: Colors.black.withOpacity(0.2),
              blur: 4,
              canClose: () => false,
              child: Container(),
            ),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildCtaDialog(context),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaDialog(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: context.theme.bgColorCard.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              widget.title,
              style:
                  Theme.of(context).textTheme.headlineLarge!.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 32),
            MiniCard(
                onTap: () {
                  log(Markers.userTap).trace("tappedUpgrade", (m) async {
                    await _payment.openPaymentScreen(m, placement: widget.placement);
                  });
                },
                color: context.theme.accent,
                child: SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.heart_fill,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Center(
                        child: Text(
                          "universal action upgrade short".i18n,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
