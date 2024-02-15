import 'package:common/common/widget.dart';
import 'package:common/mock/widget/common_card.dart';
import 'package:common/mock/widget/nav_close_button.dart';
import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../common/widget/family/home/animated_bg.dart';
import '../../common/widget/family/home/big_icon.dart';
import '../../common/widget/family/home/top_bar.dart';
import 'common_clickable.dart';
import 'common_text_button.dart';
import 'profile_button.dart';

class PaymentSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => PaymentSheetState();
}

class PaymentSheetState extends State<PaymentSheet> {
  final _topBarController = TopBarController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _topBarController.manualPush("");
    //_scrollController.addListener(_updateTopBar);
  }

  _updateTopBar() {
    _topBarController.updateScrollPos(_scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateTopBar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColorCard,
      body: ChangeNotifierProvider(
        create: (context) => _topBarController,
        child: Stack(
          children: [
            AnimatedBg(),
            Column(children: [
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      SizedBox(
                        height: 28,
                        child: Image(
                          image: AssetImage('assets/images/header.png'),
                          width: 150,
                        ),
                      ),
                      Text("FAMILY",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Cursive',
                              fontSize: 16,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 52),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Text("family payment slug".i18n,
                        style: TextStyle(color: Colors.white, fontSize: 15),
                        textAlign: TextAlign.center),
                    SizedBox(height: 46),
                    CommonCard(
                        bgBorder: Border.all(
                          color: context.theme.bgColorCard.withOpacity(0.8),
                          width: 2,
                        ),
                        bgColor: Colors.transparent,
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "14 days free, then",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                Spacer(),
                                Transform.translate(
                                  offset: Offset(6, -6),
                                  child: Icon(
                                    CupertinoIcons.check_mark,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                )
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              "129,99 PLN per year",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 12),
                            Text(
                              "Yearly subscription, 10.83 PLN per month",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        )),
                    SizedBox(height: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_alt_circle,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Monitor all family devices",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            )
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_alt_circle,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Great performance",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            )
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.checkmark_alt_circle,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 16),
                            Text(
                              "Cancel anytime",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            )
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: CommonClickable(
                        onTap: () {},
                        //bgColor: Colors.white.withOpacity(0.1),
                        tapBgColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          "See all features".i18n,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: CommonClickable(
                    onTap: () {},
                    bgColor: context.theme.accent,
                    tapBgColor: context.theme.accent,
                    child: Center(
                      child: Text(
                        "Subscribe Now",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    )),
              ),
              SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  "Restore Purchases",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text("  |  ",
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                Text(
                  "Terms & Privacy",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ]),
              SizedBox(height: 40),
            ]),
            // Positioned(
            //   top: 0,
            //   left: 0,
            //   right: 0,
            //   child: Stack(
            //     children: [
            //       TopBar(
            //           height: 58,
            //           bottomPadding: 16,
            //           title: "",
            //           animateBg: true,
            //           trailing: CommonClickable(
            //             onTap: () => Navigator.of(context).pop(),
            //             //bgColor: Colors.white.withOpacity(0.1),
            //             tapBgColor: Colors.white.withOpacity(0.2),
            //             child: Text("Close",
            //                 style: TextStyle(color: Colors.white)),
            //           )),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
