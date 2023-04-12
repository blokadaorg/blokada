import 'package:common/service/LogService.dart';
import 'package:common/service/SheetService.dart';

class Services {
  // Singleton
  Services._();
  static final instance = Services._();

  late LogService log = LogService();
  late SheetService sheet = SheetService();
}
