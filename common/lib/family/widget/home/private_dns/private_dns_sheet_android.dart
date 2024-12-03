import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:common/family/widget/home/private_dns/private_dns_setting_guide.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivateDnsSheetAndroid extends StatefulWidget {
  const PrivateDnsSheetAndroid({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivateDnsSheetAndroidState();
}

class PrivateDnsSheetAndroidState extends State<PrivateDnsSheetAndroid> {
  late final _channel = Core.get<PermChannel>();
  late final _perm = Core.get<PermActor>();

  final _scrollController = ScrollController();
  bool _isFullyVisible = false;

  @override
  void initState() {
    super.initState();

    // Check if the content is fully visible after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfContentIsFullyVisible();
    });

    _scrollController.addListener(() {
      _checkIfContentIsFullyVisible();
    });
  }

  void _checkIfContentIsFullyVisible() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        _isFullyVisible = true;
      });
    } else {
      setState(() {
        _isFullyVisible = false;
      });
    }
  }

  void _onButtonTap() async {
    if (!_isFullyVisible) {
      // Scroll to the bottom if content is not fully visible
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // await sleepAsync(const Duration(seconds: 3));
      // _performCTA();
    } else {
      _performCTA();
    }
  }

  void _performCTA() async {
    Navigator.of(context).pop();
    await sleepAsync(const Duration(milliseconds: 400));
    Clipboard.setData(
        ClipboardData(text: _perm.getAndroidDnsStringToCopy(Markers.userTap)));
    _channel.doOpenPermSettings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        "family perms header".i18n,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "family perms brief alt"
                              .i18n
                              .withParams("Blokada Family"),
                          softWrap: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.theme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16), // Replaces Spacer
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "1.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting android connections"
                                  .i18n,
                              subtitle:
                                  "family perms setting android similar".i18n,
                              icon: CupertinoIcons.wifi,
                              android: true,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "2.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting android more".i18n,
                              subtitle:
                                  "family perms setting android optional".i18n,
                              android: true,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "3.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting android dns".i18n,
                              android: true,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "4.",
                              style:
                                  TextStyle(color: context.theme.textSecondary),
                            ),
                            PrivateDnsSettingGuideWidget(
                              title: "family perms setting android host".i18n,
                              subtitle:
                                  "family perms setting android similar".i18n,
                              android: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16), // Replaces Spacer
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          "family perms copy android".i18n,
                          softWrap: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.theme.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MiniCard(
                        onTap: _onButtonTap,
                        color: context.theme.accent,
                        child: SizedBox(
                          height: 32,
                          child: Center(
                            child: Text(
                              "dnsprofile action open settings".i18n,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
