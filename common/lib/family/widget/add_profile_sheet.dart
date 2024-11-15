import 'package:common/common/i18n.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/dragon/dialog.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/family/widget/profile/profile_button.dart';
import 'package:common/family/widget/profile/profile_utils.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddProfileSheet extends StatefulWidget {
  const AddProfileSheet({super.key});

  @override
  State<StatefulWidget> createState() => AddProfileSheetState();
}

class AddProfileSheetState extends State<AddProfileSheet> {
  late final _profile = dep<ProfileController>();

  final _topBarController = TopBarController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _topBarController.manualPush("family profile action add".i18n);
    _scrollController.addListener(_updateTopBar);
  }

  _updateTopBar() {
    _topBarController.updateScrollPos(_scrollController.offset);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topBarController.backgroundColor = context.theme.bgColorCard;
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
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: PrimaryScrollController(
                controller: _scrollController,
                child: ListView(children: [
                  SizedBox(height: 60),
                  Text("family profile add".i18n,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall!
                          .copyWith(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text("family profile template".i18n,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  SizedBox(height: 56),
                  ProfileButton(
                    onTap: () => showRenameDialog(context, "profile", null,
                        onConfirm: (name) {
                      Navigator.of(context).pop();
                      _profile.addProfile("family", name, Markers.userTap);
                    }),
                    icon: CupertinoIcons.plus_circle_fill,
                    iconColor: getProfileColor(""),
                    name: "family profile name custom".i18n,
                  ),
                  SizedBox(height: 12),
                  ProfileButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      _profile.addProfile("parent", "Parent", Markers.userTap);
                    },
                    icon: getProfileIcon("parent"),
                    iconColor: getProfileColor("parent"),
                    name: "family profile name parent".i18n,
                    trailing: null,
                  ),
                  SizedBox(height: 12),
                  ProfileButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      _profile.addProfile("child", "Child", Markers.userTap);
                    },
                    icon: getProfileIcon("child"),
                    iconColor: getProfileColor("child"),
                    name: "family profile name child".i18n,
                    trailing: null,
                  ),
                ]),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopBar(
                  height: 58,
                  bottomPadding: 16,
                  title: "family profile action add".i18n,
                  animateBg: true,
                  trailing: CommonClickable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text("universal action cancel".i18n,
                        style: TextStyle(color: context.theme.accent)),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
