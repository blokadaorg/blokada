import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/device/open_perms.dart';
import 'package:common/dragon/widget/home/private_dns_setting_guide.dart';
import 'package:common/util/di.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivateDnsSheet extends StatefulWidget {
  const PrivateDnsSheet({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PrivateDnsSheetState();
}

class PrivateDnsSheetState extends State<PrivateDnsSheet> {
  late final _openPerms = dep<OpenPerms>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: context.theme.bgColorCard,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            // Row(
            //   children: [
            //     Expanded(child: Container()),
            //     Text("Cancel", style: TextStyle(color: context.theme.family)),
            //   ],
            // ),
            const SizedBox(height: 24),
            Text("One more thing",
                style: Theme.of(context)
                    .textTheme
                    .displaySmall!
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                  "Activate \"Blokada Family\" in Settings by navigating as shown below.",
                  softWrap: true,
                  textAlign: TextAlign.justify,
                  style: TextStyle(color: context.theme.textSecondary)),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Text("In the main section of Settings, tap:",
                    Text("1.",
                        style: TextStyle(color: context.theme.textSecondary)),
                    const PrivateDnsSettingGuideWidget(
                        title: "General", icon: CupertinoIcons.settings),
                    const SizedBox(height: 16),
                    //Text("... then swipe down, and tap:",
                    Text("2.",
                        style: TextStyle(color: context.theme.textSecondary)),
                    const PrivateDnsSettingGuideWidget(
                        title: "VPN & Device Management"),
                    const SizedBox(height: 16),
                    // Text("... next, tap:",
                    Text("3.",
                        style: TextStyle(color: context.theme.textSecondary)),
                    const PrivateDnsSettingGuideWidget(
                        title: "DNS",
                        icon: CupertinoIcons.ellipsis,
                        edgeText: "Automatic"),
                    const SizedBox(height: 16),
                    //Text("... and finally, select:",
                    Text("4.",
                        style: TextStyle(color: context.theme.textSecondary)),
                    const PrivateDnsSettingGuideWidget(
                      title: "Blokada Family",
                      subtitle: "Blokada Family",
                      iconReplacement: Image(
                          image: AssetImage('assets/images/appicon.png'),
                          width: 24),
                      chevron: false,
                    ),
                  ]),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MiniCard(
                      onTap: () {
                        Navigator.of(context).pop();
                        _openPerms.open();
                      },
                      color: context.theme.accent,
                      child: const SizedBox(
                        height: 32,
                        child: Center(
                          child: Text(
                            "Open Settings",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
