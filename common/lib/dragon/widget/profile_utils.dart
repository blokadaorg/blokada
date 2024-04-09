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

Color getProfileColor(String template) {
  switch (template) {
    case "parent":
      return Colors.blue;
    case "child":
      return Colors.green;
    default:
      return Colors.black54;
  }
}
