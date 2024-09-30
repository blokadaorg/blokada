import 'package:flutter/material.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

class StatsSheet {
  late SnappingSheetController _snappingSheetController;

  getOpenPosition(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return SnappingPosition.pixels(
      positionPixels: (height > 820) ? 820 : height,
      snappingCurve: Curves.easeOutExpo,
      snappingDuration: const Duration(seconds: 1),
      grabbingContentOffset: GrabbingContentOffset.bottom,
    );
  }

  setSnappingSheetController(SnappingSheetController controller) {
    _snappingSheetController = controller;
  }

  openSheet(BuildContext context) {
    _snappingSheetController.snapToPosition(getOpenPosition(context));
  }
}
