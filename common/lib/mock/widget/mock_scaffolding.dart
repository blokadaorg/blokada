import 'dart:io';

import 'package:common/common/widget/family/home/devices.dart';
import 'package:common/common/widget/family/home/private_dns_setting_guide.dart';
import 'package:common/common/widget/family/home/smart_onboard.dart';
import 'package:common/common/widget/family/smart_header/smart_header.dart';
import 'package:common/journal/channel.pg.dart';
import 'package:common/mock/widget/mock_settings.dart';
import 'package:common/util/config.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../common/defaults/filter_decor_defaults.dart';
import '../../common/model.dart';
import '../../common/widget.dart';
import '../../common/widget/family/home/animated_bg.dart';
import '../../common/widget/family/home/big_logo.dart';
import '../../common/widget/family/home/cta_buttons.dart';
import '../../common/widget/family/home/home_screen.dart';
import '../../common/widget/family/home/totalcounter.dart';
import '../../common/widget/family/stats/activity_item.dart';

class MockScaffoldingWidget extends StatelessWidget {
  MockScaffoldingWidget({Key? key}) : super(key: key);

  late final _pages = <Map<String, Widget Function(BuildContext)>>[
    {"Filter components": _buildFilterComponents},
    {"Family components": _buildFamilyComponents},
    {"Home preview": _buildFamilyHome},
    {"": _buildHome},
    {"Screens": (c) => _buildScreens(c)},
    {"Filters": _buildFilters},
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
        _buildFilterOption(context),
      ],
    );
  }

  Widget _buildFilters(BuildContext context) {
    return ListView(
      children: [
        _buildBackEditHeader(context),
        _buildProfileHeader(context),
        _buildFilter(context, 0, color: const Color(0xFFA9CCFE)),
        _buildFilter(context, 1),
        _buildFilter(context, 2, color: const Color(0xFFF4B1C6)),
        _buildFilter(context, 3, color: const Color(0XFFFDB39C)),
        _buildFilter(context, 4),
        _buildFilter(context, 5),
        _buildFilter(context, 6),
      ],
    );
  }

  Widget _buildFilter(BuildContext context, int index, {Color? color}) {
    final filter = getKnownFilters(cfg.act)[index];
    final texts = filterDecorDefaults
        .firstWhere((it) => it.filterName == filter.filterName);
    return FilterWidget(filter: filter, texts: texts, bgColor: color);
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

  Widget _buildFilterOption(BuildContext context) {
    final filter = getKnownFilters(cfg.act)[0];
    return FilterOptionWidget(option: filter.options.first, selections: []);
  }

  Widget _buildFamilyComponents(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        BigLogo(),
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
                FamilyTotalCounter(autoRefresh: true),
                CtaButtons(),
                SizedBox(height: 48),
              ],
            ),
            ActivityItem(
                entry: JournalEntry(
              domainName: "time.apple.com.sandbox.cdn.various.nice.domains.com",
              deviceName: "Alva",
              time: "3 minutes ago",
              requests: 37,
              type: JournalEntryType.blocked,
            )),
            ActivityItem(
                entry: JournalEntry(
              domainName: "tim.cooks.com",
              deviceName: "Alva",
              time: "4 minutes ago",
              requests: 2,
              type: JournalEntryType.passedAllowed,
            )),
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
                  Devices(),
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
