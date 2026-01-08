import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/home/qr_scan_sheet_macos.dart';

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