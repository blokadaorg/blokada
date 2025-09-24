import 'package:common/common/module/modal/modal.dart';
import 'package:common/core/core.dart';
import 'package:common/family/widget/home/qr_scan_sheet_macos.dart';

class QrScanModule with Module {
  @override
  onCreateModule() async {
    await register(QrScanActor());
  }
}

class QrScanActor with Actor {
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  Future<void> onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.familyQrScanMacos) {
        _modalWidget.change(it.m, (context) => const QrScanSheetMacos());
      }
    });
  }
}