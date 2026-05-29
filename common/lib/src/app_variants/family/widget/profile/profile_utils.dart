import 'package:common/src/app_variants/family/widget/profile/profile_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

IconData getProfileIcon(String template) {
  switch (template) {
    case "parent":
      return CupertinoIcons.person_2_alt;
    case "child":
      return Icons.child_care;
    default:
      return CupertinoIcons.person_crop_circle;
  }
}

Color getProfileColorFor(String template, String alias) {
  switch (template) {
    case 'parent':
      return Colors.blue;
    case 'child':
      return Colors.green;
    default:
      return ProfileAvatar.paletteColor(alias);
  }
}
