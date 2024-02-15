import 'package:common/family/family.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';
import 'package:vistraced/via.dart';
import 'package:unique_names_generator/unique_names_generator.dart' as names;

import '../../../../journal/journal.dart';
import '../../../../mock/widget/add_profile_sheet.dart';
import '../../../../mock/widget/nav_close_button.dart';
import '../../../../stage/channel.pg.dart';
import '../../../../util/di.dart';
import '../../../../util/trace.dart';
import '../../../widget.dart';

class ProfilesSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ProfilesSheetState();
}

class ProfilesSheetState extends State<ProfilesSheet> with TraceOrigin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      body: SuperScaffold(
        appBar: SuperAppBar(
          searchBar: SuperSearchBar(enabled: false),
          backgroundColor: context.theme.panelBackground.withOpacity(0.5),
          automaticallyImplyLeading: false,
          largeTitle: SuperLargeTitle(largeTitle: "Profiles"),
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
                        leading: Icon(CupertinoIcons.person_crop_circle,
                            color: Colors.yellow),
                        title: Text('My custom profile'),
                      ),
                      SettingsTile.navigation(
                        onPressed: (context) => _next(context, "Parent"),
                        leading: Icon(CupertinoIcons.person_crop_circle,
                            color: Colors.pink),
                        title: Text('My second profile'),
                      ),
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

  _next(BuildContext context, String profile) {
    Navigator.of(context).pop();
  }
}
