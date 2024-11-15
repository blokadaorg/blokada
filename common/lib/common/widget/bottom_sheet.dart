import 'dart:io';

import 'package:common/common/widget/theme.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

const maxSheetWidth = 600.0;

showSheet(BuildContext context, {required WidgetBuilder builder}) async {
  final screenWidth = MediaQuery.of(context).size.width;

  if (screenWidth > maxSheetWidth) {
    return showCustomModalBottomSheet(
      context: context,
      duration: const Duration(milliseconds: 300),
      backgroundColor: context.theme.bgColorCard,
      builder: builder,
      containerWidget: (_, animation, child) => FloatingModal(child: child),
      expand: false,
    );
  }

  return showCupertinoModalBottomSheet(
    context: context,
    duration: const Duration(milliseconds: 300),
    backgroundColor:
        Platform.isAndroid ? Colors.transparent : context.theme.bgColorCard,
    builder: (c) => Padding(
        padding: EdgeInsets.only(top: Platform.isAndroid ? 24 : 0),
        child: builder(c)),
  );
}

class FloatingModal extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const FloatingModal({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final factor = maxSheetWidth / screenWidth;

    return Center(
      child: FractionallySizedBox(
        widthFactor: factor,
        heightFactor: 0.9,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              color: backgroundColor,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
