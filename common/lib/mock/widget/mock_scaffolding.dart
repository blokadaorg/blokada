import 'dart:io';

import 'package:common/common/model.dart';
import 'package:common/common/widget/back_edit_header.dart';
import 'package:common/common/widget/home/header/header.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/touch.dart';
import 'package:common/common/widget/two_letter_icon.dart';
import 'package:common/family/widget/home/animated_bg.dart';
import 'package:common/family/widget/home/private_dns/private_dns_setting_guide.dart';
import 'package:common/family/widget/home/smart_onboard.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MockScaffoldingWidget extends StatelessWidget {
  MockScaffoldingWidget({Key? key}) : super(key: key);

  late final _pages = <Map<String, Widget Function(BuildContext)>>[
    {"Filter components": _buildFilterComponents},
    {"Family components": _buildFamilyComponents},
    {"Home preview": _buildFamilyHome},
    {"": _buildHome},
    {"Screens": (c) => _buildScreens(c)},
  ];

  final _ctrl = PageController(initialPage: 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBg(),
          Container(
            //color: context.theme.bgColor,
            child: PageView(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              children: _buildPages(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    return SizedBox(
      height: 100,
      child: MaterialButton(
        onPressed: () => _ctrl.animateToPage(0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut),
        child: const Text("< go home"),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context) {
    return _pages.map((e) {
      return e.entries.first.value(context);
    }).toList();
  }

  Widget _buildHome(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _pages.map((e) {
          return MaterialButton(
              onPressed: () {
                _ctrl.animateToPage(
                  _pages.indexOf(e),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(e.entries.first.key));
        }).toList());
  }

  Widget _buildFilterComponents(BuildContext context) {
    return Column(
      children: [
        _buildBack(context),
        _buildTwoLetterIcon(context, "hello", false),
        _buildTwoLetterIcon(context, "wworld", false),
        _buildTwoLetterIcon(context, "lol", true),
        _buildTwoLetterIcon(context, "ad", true),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 8),
      child: Row(
        children: [
          Text("Blocklists",
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          Expanded(child: Container()),
          Touch(
            onTap: () => {_showEditProfileNameDialog(context)},
            decorationBuilder: (value) {
              return BoxDecoration(
                color: context.theme.bgMiniCard.withOpacity(value),
                borderRadius: BorderRadius.circular(4),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text("Alva"),
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.folder,
                      color: context.theme.textSecondary, size: 18),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _showEditProfileNameDialog(BuildContext context) {
    _showAdaptiveDialog(
      context,
      title: const Text("Profile"),
      content: Column(
        children: [
              const Text("Choose a profile to use for Alva."),
              SizedBox(height: 16),
            ] +
            ["Alva", "Adblocking only"]
                .map((it) => _buildProfileEditItem(context, it))
                .flatten()
                .toList()
                .dropLast(1),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showNameProfileDialog(context, null);
          },
          child: const Text("New profile"),
        ),
      ],
    );
  }

  List<Widget> _buildProfileEditItem(BuildContext context, String name) {
    return [
      Touch(
        onTap: () => {},
        decorationBuilder: (value) {
          return BoxDecoration(
            color: context.theme.bgMiniCard.withOpacity(value),
            borderRadius: BorderRadius.circular(4),
          );
        },
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(CupertinoIcons.doc,
                      color: context.theme.textSecondary, size: 18),
                  SizedBox(width: 8),
                  Text(name,
                      style: TextStyle(
                          color: context.theme.textPrimary, fontSize: 16)),
                ],
              ),
            ),
            Expanded(child: Container()),
            Touch(
              onTap: () {
                Navigator.of(context).pop();
                _showNameProfileDialog(context, name);
              },
              decorationBuilder: (value) {
                return BoxDecoration(
                  color: context.theme.bgMiniCard.withOpacity(value),
                  borderRadius: BorderRadius.circular(4),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(CupertinoIcons.pencil,
                    color: context.theme.textSecondary, size: 18),
              ),
            ),
          ],
        ),
      ),
      Divider(
          indent: 4,
          endIndent: 4,
          thickness: 0.4,
          height: 4,
          color: context.theme.divider),
    ];
  }

  void _showNameProfileDialog(BuildContext context, String? name) {
    _showAdaptiveDialog(
      context,
      title: Text(name == null ? "New Profile" : "Rename Profile"),
      content: Column(
        children: [
          const Text("Enter a name for your profile."),
          const SizedBox(height: 16),
          Material(
            child: TextField(
              controller: TextEditingController(text: name),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.theme.panelBackground,
                focusColor: context.theme.panelBackground,
                hoverColor: context.theme.panelBackground,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.divider, width: 1.0),
                  borderRadius: BorderRadius.circular(2.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.divider, width: 1.0),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Save"),
        ),
      ],
    );
  }

  void _showAdaptiveDialog(
    context, {
    required Text title,
    required Widget content,
    required List<Widget> actions,
  }) {
    Platform.isIOS || Platform.isMacOS
        ? showCupertinoDialog<String>(
            context: context,
            builder: (BuildContext context) => CupertinoAlertDialog(
              title: title,
              content: content,
              actions: actions,
            ),
          )
        : showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: title,
              content: content,
              actions: actions,
            ),
          );
  }

  Widget _buildBackEditHeader(BuildContext context) {
    return BackEditHeaderWidget(name: "Alva");
  }

  Widget _buildTwoLetterIcon(BuildContext context, String name, bool big) {
    return TwoLetterIconWidget(name: name, big: big);
  }

  Widget _buildFamilyComponents(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ListView(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(height: 150),
                PrivateDnsSettingGuideWidget(
                    title: "General", icon: Icons.settings),
                PrivateDnsSettingGuideWidget(title: "VPN & Device Management"),
                PrivateDnsSettingGuideWidget(
                    title: "DNS",
                    icon: CupertinoIcons.ellipsis,
                    edgeText: "Automatic"),
                PrivateDnsSettingGuideWidget(
                  title: "Blokada Family",
                  subtitle: "Blokada Family",
                  icon: CupertinoIcons.shield_fill,
                  chevron: false,
                ),
                SizedBox(height: 28),
                SizedBox(height: 48),
              ],
            ),
          ],
        )
      ],
    );
  }

  Widget _buildScreens(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaterialButton(
              onPressed: () {
                // Navigator.push(
                //   context,
                //   StandardRoute(builder: (context) => const HomeScreen()),
                // );
              },
              child: const Text("Family Home"),
            ),
            MaterialButton(
              onPressed: () {
                // Navigator.push(
                //   context,
                //   StandardRoute(builder: (context) => MockSettingsScreen()),
                // );
              },
              child: const Text("Settings"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyHome(BuildContext context) {
    final phase = FamilyPhase.parentHasDevices;
    return Stack(
      children: [
        Column(
          children: [
            SizedBox(height: 48),
            SmartOnboard(phase: phase, deviceCount: 0),
            //SmartFooter(phase: phase, hasPin: true),
          ],
        ),
        phase == FamilyPhase.parentHasDevices
            ? ListView(
                reverse: true,
                children: [
                  //SizedBox(height: 64),
                  //StatusTexts(phase: FamilyPhase.fresh),
                  //StatusTexts(phase: FamilyPhase.lockedActive),
                  //StatusTexts(phase: FamilyPhase.noPerms),
                  //CtaButtons(),
                ],
              )
            : Container(),
        Column(
          children: [
            SizedBox(height: 48),
            SmartHeader(phase: phase),
          ],
        ),
      ],
    );
  }
}
