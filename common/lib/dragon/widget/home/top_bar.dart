import 'dart:math';
import 'dart:ui';

import 'package:common/common/model.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/route.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// class TopBar extends StatefulWidget {
//   final bool alwaysShowTitle;
//   final double height;
//   final Widget? trailing;
//   final bool sliding;
//
//   const TopBar({
//     super.key,
//     this.alwaysShowTitle = false,
//     this.height = 100,
//     this.sliding = false,
//     this.trailing,
//   });
//
//   @override
//   State<StatefulWidget> createState() => TopBarState();
// }
//
// class TopBarState extends State<TopBar> with TickerProviderStateMixin {
//   double _show = 0.0;
//   bool _transitioning = false;
//   bool _blurBackground = false;
//
//   bool _showTitle = false;
//   String _title = "";
//   String _waitingTitle = "";
//
//   String _back = "";
//   String _waitingBack = "";
//
//   bool? _playForward;
//
//   late final _ctrlShow = AnimationController(
//     duration: const Duration(milliseconds: 400),
//     vsync: this,
//   );
//
//   late final _showOpacity =
//       Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
//     parent: _ctrlShow,
//     curve: Curves.linear,
//   ));
//
//   late final _ctrlBgOpacity = AnimationController(
//     duration: const Duration(milliseconds: 50),
//     vsync: this,
//   );
//
//   late final _bgOpacity =
//       Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
//     parent: _ctrlBgOpacity,
//     curve: Curves.easeInOut,
//   ));
//
//   late final _ctrlTitleOpacity = AnimationController(
//     duration: const Duration(milliseconds: 200),
//     vsync: this,
//   );
//
//   late final _titleOpacity =
//       Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
//     parent: _ctrlTitleOpacity,
//     curve: Curves.easeInOut,
//   ));
//
//   late final _ctrlWidgetsOpacity = AnimationController(
//     duration: const Duration(milliseconds: 200),
//     vsync: this,
//   );
//
//   late final _widgetsOpacity =
//       Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
//     parent: _ctrlWidgetsOpacity,
//     curve: Curves.easeInOut,
//   ));
//
//   late final _ctrlTextOffset = AnimationController(
//     duration: const Duration(milliseconds: 400),
//     vsync: this,
//   );
//
//   late final _textOffset = TweenSequence([
//     TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -0.8), weight: 1),
//     TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 0.0), weight: 1),
//   ]).animate(CurvedAnimation(
//     parent: _ctrlTextOffset,
//     curve: Curves.easeInOut,
//   ));
//
//   @override
//   void initState() {
//     super.initState();
//
//     _ctrlTextOffset.addStatusListener((status) {
//       if (status == AnimationStatus.forward ||
//           status == AnimationStatus.reverse) {
//         // Update text in the middle of the transition (when it's transparent)
//         Future.delayed(_ctrlTextOffset.duration! * 0.5, () {
//           _title = _waitingTitle;
//           _back = _waitingBack;
//           _ctrlTitleOpacity.forward();
//           _ctrlWidgetsOpacity.forward();
//         });
//       } else if (status == AnimationStatus.completed ||
//           status == AnimationStatus.dismissed) {
//         _playForward = null;
//         //_ctrlTextOffset.reset();
//       }
//     });
//
//     _ctrlShow.addStatusListener((status) {
//       if (status == AnimationStatus.completed ||
//           status == AnimationStatus.dismissed) {
//         Future.delayed(const Duration(milliseconds: 300), () {
//           if (_ctrlShow.isAnimating) return;
//           _transitioning = false;
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     super.dispose();
//     _ctrlTitleOpacity.dispose();
//     _ctrlWidgetsOpacity.dispose();
//     _ctrlBgOpacity.dispose();
//     _ctrlTextOffset.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<TopBarController>(
//       builder: (context, controller, child) {
//         _show = widget.sliding ? controller.show : 1.0;
//         // if (_show == 1.0 && _ctrlShow.value == 0.0) {
//         //   _ctrlShow.forward();
//         //   //_ctrlTextOpacity.forward(from: 0.0);
//         //   _transitioning = true;
//         // } else if (_show == 0.0 && _ctrlShow.value == 1.0) {
//         //   _ctrlShow.reverse();
//         //   //_ctrlTextOpacity.reverse(from: 0.0);
//         //   _transitioning = true;
//         // } else if (!_transitioning) {
//         //   //_ctrlShow.value = _show;
//         //   // _ctrlTextOpacity.value = _show / 2;
//         // }
//         _ctrlShow.value = _show;
//
//         if (controller.blurBackground != _blurBackground) {
//           _blurBackground = controller.blurBackground;
//           if (_blurBackground) {
//             _ctrlBgOpacity.forward();
//           } else {
//             _ctrlBgOpacity.reverse();
//           }
//         }
//
//         if (controller.showTitle != _showTitle || widget.alwaysShowTitle) {
//           _showTitle = controller.showTitle || widget.alwaysShowTitle;
//           if (_title.isBlank) _title = controller.title;
//           if (_showTitle) {
//             _ctrlTitleOpacity.forward();
//           } else {
//             _ctrlTitleOpacity.reverse();
//           }
//         }
//
//         if (controller.title != _title) {
//           //_playForward = controller.playForward;
//           _playForward = true;
//           _waitingTitle = controller.title;
//           _waitingBack = controller.back.lastOrNull ?? "";
//
//           if (_playForward == true) {
//             _ctrlTitleOpacity.reverse();
//             _ctrlWidgetsOpacity.reverse();
//             _ctrlTextOffset.forward(from: 0.0);
//             _ctrlShow.forward();
//           } else if (_playForward == false) {
//             _ctrlTitleOpacity.reverse();
//             _ctrlWidgetsOpacity.reverse();
//             _ctrlTextOffset.value = 1.0;
//             _ctrlTextOffset.reverse(from: 1.0);
//           }
//         }
//
//         final width = MediaQuery.of(context).size.width;
//         return AnimatedBuilder(
//             animation: _showOpacity,
//             builder: (context, child) {
//               return Transform.translate(
//                 offset: Offset(
//                     //widget.sliding ? width - width * _showOffset.value : 0, 0),
//                     0,
//                     0),
//                 child: Opacity(
//                   opacity: _showOpacity.value,
//                   child: Stack(
//                     alignment: Alignment.bottomCenter,
//                     children: [
//                       AnimatedBuilder(
//                           animation: _bgOpacity,
//                           builder: (context, child) {
//                             return Stack(
//                               children: [
//                                 Container(
//                                   height: widget.height,
//                                   color: _bgOpacity.value == 1
//                                       ? Colors.transparent
//                                       : controller.backgroundColor,
//                                 ),
//                                 Opacity(
//                                   opacity: _bgOpacity.value,
//                                   child: Column(
//                                     children: [
//                                       ClipRect(
//                                         child: SizedBox(
//                                           height: widget.height,
//                                           child: BackdropFilter(
//                                             filter: ImageFilter.blur(
//                                               sigmaX: 25,
//                                               sigmaY: 25,
//                                             ),
//                                             child: Container(
//                                               color: context.theme.shadow
//                                                   .withOpacity(0.2),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                       Container(
//                                         height: 1,
//                                         color: context.theme.divider
//                                             .withOpacity(0.08),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             );
//                           }),
//                       Padding(
//                         padding: const EdgeInsets.all(12.0),
//                         child: AnimatedBuilder(
//                             animation: Listenable.merge([
//                               _titleOpacity,
//                               _widgetsOpacity,
//                               _textOffset,
//                             ]),
//                             builder: (context, child) {
//                               return Stack(
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Transform.translate(
//                                         offset:
//                                             Offset(_textOffset.value * 100, 0),
//                                         child: Opacity(
//                                           opacity: _titleOpacity.value *
//                                               (_showTitle ? 1.0 : 0.0),
//                                           child: Text(_title,
//                                               style: TextStyle(
//                                                   color:
//                                                       context.theme.textPrimary,
//                                                   fontSize: 17,
//                                                   fontWeight: FontWeight.w600)),
//                                         ),
//                                       ),
//                                       // Other elements...
//                                     ],
//                                   ),
//                                   Opacity(
//                                     opacity: _widgetsOpacity.value *
//                                         (_back.isNotBlank ? 1.0 : 0.0),
//                                     child: Icon(Icons.arrow_back_ios,
//                                         color: context.theme.family),
//                                   ),
//                                   Transform.translate(
//                                     offset: Offset(
//                                         20 + _textOffset.value * 100 * 0.3, 0),
//                                     child: Opacity(
//                                       opacity: _widgetsOpacity.value,
//                                       child: Text(_back,
//                                           style: TextStyle(
//                                               color: context.theme.family,
//                                               fontSize: 17,
//                                               fontWeight: FontWeight.w400)),
//                                     ),
//                                   ),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.end,
//                                     children: [
//                                       if (widget.trailing != null)
//                                         Transform.translate(
//                                           offset:
//                                               //Offset(_textOffset.value * 100, 0),
//                                               Offset(0, 0),
//                                           child: Opacity(
//                                             opacity: 1.0,
//                                             child: widget.trailing,
//                                           ),
//                                         ),
//                                       SizedBox(width: 8),
//                                     ],
//                                   ),
//                                 ],
//                               );
//                             }),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             });
//       },
//     );
//   }
// }

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
      print("topbar: unknown route: $route");
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
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
    userGesture = true;
    notifyListeners();
  }

  void updateUserGesturePos(double pos) {
    if (pos == show) return;

    // Clicked back button without swiping
    if (!userGesture) delayPop = true;

    show = pos;
    notifyListeners();
  }

  @override
  void didStopUserGesture() {
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
