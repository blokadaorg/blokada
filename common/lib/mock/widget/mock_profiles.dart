import 'package:common/common/widget.dart';
import 'package:common/common/widget/family/home/bg.dart';
import 'package:common/mock/widget/add_profile_sheet.dart';
import 'package:common/mock/widget/edit_profile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';

import '../../common/widget/family/home/animated_bg.dart';
import '../../common/widget/family/home/big_icon.dart';
import 'profile_button.dart';

class MockProfilesScreen extends StatelessWidget {
  const MockProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      body: SuperScaffold(
        appBar: SuperAppBar(
          searchBar: SuperSearchBar(enabled: false),
          backgroundColor: context.theme.panelBackground.withOpacity(0.5),
          largeTitle: SuperLargeTitle(largeTitle: "Profiles"),
          previousPageTitle: "Settings",
          actions: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  showCupertinoModalBottomSheet(
                    context: context,
                    duration: const Duration(milliseconds: 300),
                    backgroundColor: context.theme.bgColorCard,
                    builder: (context) => AddProfileSheet(),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Icon(
                    CupertinoIcons.add,
                    color: CupertinoTheme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Container(
          color: context.theme.panelBackground,
          child: Stack(
            children: [
              SettingsList(
                applicationType: ApplicationType.cupertino,
                platform: DevicePlatform.iOS,
                sections: [
                  SettingsSection(
                    tiles: [
                      SettingsTile.navigation(
                        onPressed: (context) => _next(context, "Parent"),
                        leading: Icon(CupertinoIcons.person_2_alt,
                            color: Colors.blue),
                        title: Text('Parent'),
                      ),
                      SettingsTile.navigation(
                        onPressed: (context) => _next(context, "Child"),
                        leading: Icon(CupertinoIcons.person_solid,
                            color: Colors.green),
                        title: Text('Child'),
                        description: Text(
                            "Profiles let you quickly switch between blocking configurations. Choose one of the predefined ones, or create your own."),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _next(BuildContext context, String name) {
    // Navigator.of(context).push(StandardRoute(
    //     builder: (context) => EditProfileSheet(
    //           profile: name,
    //         )));
  }
}
