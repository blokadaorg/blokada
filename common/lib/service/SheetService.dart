import 'package:flutter/animation.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

class SheetService {

  late SnappingSheetController _snappingSheetController;

  SnappingPosition openPosition = SnappingPosition.pixels(
    positionPixels: 820,
    snappingCurve: Curves.easeOutExpo,
    snappingDuration: Duration(seconds: 1),
    grabbingContentOffset: GrabbingContentOffset.bottom,
  );

  setSnappingSheetController(SnappingSheetController controller) {
    _snappingSheetController = controller;
  }

  openSheet() {
    _snappingSheetController.snapToPosition(openPosition);
  }

}