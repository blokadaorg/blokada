import 'package:common/common/widget.dart';
import 'package:common/mock/widget/nav_close_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../common/widget/family/home/top_bar.dart';
import 'common_clickable.dart';
import 'common_text_button.dart';
import 'profile_button.dart';

class AddProfileSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AddProfileSheetState();
}

class AddProfileSheetState extends State<AddProfileSheet> {
  final _topBarController = TopBarController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _topBarController.manualPush("Add a profile");
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
                  Text("What profile you want to add?",
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall!
                          .copyWith(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text("Choose a template to get started.",
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  SizedBox(height: 56),
                  ProfileButton(
                    onTap: () => showRenameDialog(context, "profile", null),
                    icon: CupertinoIcons.plus_circle_fill,
                    iconColor: Colors.black54,
                    name: "Custom",
                  ),
                  SizedBox(height: 12),
                  ProfileButton(
                    onTap: () => _next(context),
                    icon: CupertinoIcons.person_2_alt,
                    iconColor: Colors.blue,
                    name: "Parent",
                    trailing: null,
                  ),
                  SizedBox(height: 12),
                  ProfileButton(
                    onTap: () => _next(context),
                    icon: CupertinoIcons.person_solid,
                    iconColor: Colors.green,
                    name: "Child",
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
                  title: "Add a profile",
                  animateBg: true,
                  trailing: CommonClickable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text("Cancel",
                        style: TextStyle(color: context.theme.accent)),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  _next(BuildContext context) {
    // TODO: add a profile
    Navigator.of(context).pop();
  }
}

void showRenameDialog(BuildContext context, String what, String? name) {
  showDefaultDialog(
    context,
    title: Text(name == null
        ? "New ${what.firstLetterUppercase()}"
        : "Rename ${what.firstLetterUppercase()}"),
    content: (context) => Column(
      children: [
        Text("Enter a name for this $what."),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Material(
            child: TextField(
              controller: TextEditingController(text: name),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.theme.bgColor,
                focusColor: context.theme.bgColor,
                hoverColor: context.theme.bgColor,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: context.theme.bgColor, width: 0.0),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text("Cancel"),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text("Save"),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
      ),
    ],
  );
}
