import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

class SheetService {

  late SnappingSheetController _snappingSheetController;

 getOpenPosition(BuildContext context)  {
   final height = MediaQuery.of(context).size.height;
   return SnappingPosition.pixels(
     positionPixels: (height > 820) ? 820 : height,
     snappingCurve: Curves.easeOutExpo,
     snappingDuration: Duration(seconds: 1),
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