import 'package:flutter/material.dart';

import '../../util/trace.dart';
import '../theme.dart';

class OnboardTexts extends StatefulWidget {
  final int step;

  const OnboardTexts({super.key, required this.step});

  @override
  State<StatefulWidget> createState() => OnboardTextsState();
}

class OnboardTextsState extends State<OnboardTexts>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: AnimatedSwitcher(
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(1, 0),
                    end: Offset(0, 0),
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            duration: const Duration(milliseconds: 400),
            child: widget.step == 0
                ? Column(
                    key: ValueKey<int>(1),
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Hi there!",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Activate or restore your account to continue" + "\n\n",
                        style:
                            TextStyle(fontSize: 18, color: theme.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                      ),
                    ],
                  )
                : Column(
                    key: ValueKey<int>(0),
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "App is ready!",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Add your first device now" + "\n\n",
                        style:
                            TextStyle(fontSize: 18, color: theme.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 72),
      ],
    );
  }
}
