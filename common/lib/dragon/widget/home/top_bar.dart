import 'dart:math';
import 'dart:ui';

import 'package:common/common/model.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TopBar extends StatefulWidget {
  final String title;
  final double height;
  final bool animateBg;
  final Color bgColor;
  final Widget? trailing;
  final double bottomPadding;

  TopBar({
    super.key,
    required this.title,
    this.height = 100,
    this.animateBg = false,
    this.bgColor = Colors.transparent,
    this.trailing,
    this.bottomPadding = 12,
  });

  @override
  State<StatefulWidget> createState() => TopBarState();
}

class TopBarState extends State<TopBar> {
  double transition = 1.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<TopBarController>(builder: (context, ctrl, child) {
      if (transition == 1.0 && ctrl.show == 0.0) {
        // ignore edge case
      } else {
        transition = ctrl.show;
        if (ctrl.nav.last != widget.title) transition = 1.0 - ctrl.show;
      }

      return SizedBox(
        height: widget.height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              color: widget.animateBg ? Colors.transparent : widget.bgColor,
            ),
            Opacity(
              opacity:
                  widget.animateBg ? min(max(ctrl.scroll - 10, 0.0), 1.0) : 1.0,
              child: Column(
                children: [
                  ClipRect(
                    child: SizedBox(
                      height: widget.height - 1,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 25,
                          sigmaY: 25,
                        ),
                        child: Container(
                          color: context.theme.shadow.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: context.theme.divider.withOpacity(0.08),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(50 - 50 * transition, 0),
                    //offset: Offset(0, 0),
                    child: Opacity(
                      opacity: xpow(transition, 8),
                      //opacity: 1.0,
                      child: Text(widget.title,
                          style: TextStyle(
                            color: context.theme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                  // Other elements...
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding - 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.trailing != null)
                    Opacity(
                      opacity: 1.0,
                      child: widget.trailing,
                    ),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class TopCommonBar extends StatefulWidget {
  final double height;

  const TopCommonBar({super.key, this.height = 100});

  @override
  State<StatefulWidget> createState() => TopCommonBarState();
}

class TopCommonBarState extends State<TopCommonBar> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TopBarController>(builder: (context, ctrl, child) {
      return SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              ctrl.nav.length > 1
                  ? Opacity(
                      opacity: ctrl.show <= 0.5
                          ? (ctrl.nav.length > 2
                              ? (1.0 - ctrl.show)
                              : xpow(ctrl.show, 8))
                          : ctrl.show,
                      child: GestureDetector(
                        onTap: () {
                          ctrl.navigatorKey.currentState!.pop();
                        },
                        child: Icon(Icons.arrow_back_ios,
                            color: context.theme.accent),
                      ),
                    )
                  : Container(),
              ctrl.nav.length > 1
                  ? Transform.translate(
                      offset: Offset(20 + (1.0 - ctrl.show) * 100, 0),
                      child: Opacity(
                        opacity: xpow(ctrl.show, 8),
                        child: GestureDetector(
                          onTap: () {
                            ctrl.navigatorKey.currentState!.pop();
                          },
                          child: Text(ctrl.nav.elementAt(ctrl.nav.length - 2),
                              style: TextStyle(
                                  color: context.theme.accent,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400)),
                        ),
                      ),
                    )
                  : Container(),
              ctrl.nav.length > 2
                  ? Transform.translate(
                      offset: Offset(-80 + (1.0 - ctrl.show) * 100, 0),
                      child: Opacity(
                        opacity: xpow(1.0 - ctrl.show, 8),
                        child: GestureDetector(
                          onTap: () {
                            ctrl.navigatorKey.currentState!.pop();
                          },
                          child: Text(ctrl.nav.elementAt(ctrl.nav.length - 3),
                              style: TextStyle(
                                  color: context.theme.accent,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400)),
                        ),
                      ),
                    )
                  : Container(),
            ],
          ),
        ),
      );
    });
  }
}

class TopBarController extends NavigatorObserver with ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool userGesture = false;

  double show = 0.0;
  double scroll = 0.0;

  List<String> nav = [];

  String? waitingPush;
  bool waitingPop = false;
  bool delayPop = false;

  Color backgroundColor = const Color(0xFFF2F1F6);
  bool blurBackground = false;

  int ignoreRoutes = 0;
  bool ignoreGesture = false;

  void updateScrollPos(double pos) {
    if (pos <= 40) {
      scroll = pos;
      notifyListeners();
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is StandardRoute) {
      final s = route.settings;
      String title = "Home";

      switch (s.name) {
        case "/device":
          final device = s.arguments as FamilyDevice;
          title = device.displayName;
        case "/device/filters":
          title = "Blocklists";
        case "/device/stats":
          title = "Activity";
        case "/device/stats/detail":
          title = "Details";
        case "/settings":
          title = "Settings";
        case "/settings/exceptions":
          title = "My exceptions";
        default:
          title = "Home";
      }

      if (userGesture) {
        waitingPush = title;
        return;
      }

      _push(title);
      notifyListeners();
    } else {
      ignoreRoutes++;
      ignoreGesture = true;
      show = 0.0;
      notifyListeners();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ignoreRoutes > 0) {
      if (--ignoreRoutes == 0) {
        show = 1.0;
        notifyListeners();
      }
      return;
    }

    if (userGesture) {
      waitingPop = true;
      return;
    }

    // Clicked back button without swiping (let the anim finish first)
    Future.delayed(const Duration(milliseconds: 600), () {
      _pop();
      notifyListeners();
    });
  }

  manualPush(String title) {
    _push(title);
    notifyListeners();
  }

  _push(String title) {
    nav.add(title);
  }

  _pop() {
    show = 1.0;
    if (nav.length == 1) return;
    nav.removeLast();
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ignoreGesture) return;

    userGesture = true;
    notifyListeners();
  }

  void updateUserGesturePos(double pos) {
    if (pos == show) return;
    if (ignoreRoutes > 0) return;

    if (ignoreGesture) {
      // Stop ignoring once the pop gesture finishes
      if (pos == 0.0) {
        Future.delayed(const Duration(milliseconds: 100), () {
          ignoreGesture = false;
        });
      }
      return;
    }

    // Clicked back button without swiping
    // if (!userGesture) delayPop = true;

    show = pos;
    notifyListeners();
  }

  @override
  void didStopUserGesture() {
    if (ignoreRoutes > 0) return;

    userGesture = false;
    if (waitingPop) {
      _pop();
      waitingPop = false;
    }

    if (waitingPush != null) {
      _push(waitingPush!);
      waitingPush = null;
    }
    notifyListeners();
  }
}

// For some reason math.pow wont compile
double xpow(double base, double exponent) {
  if (exponent == 0) {
    return 1;
  } else if (exponent > 0) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  } else {
    throw ArgumentError('Exponent must be non-negative.');
  }
}
