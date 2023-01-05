import 'package:common/service/EnvService.dart';
import 'package:common/service/LogService.dart';
import 'package:common/service/SheetService.dart';

import 'HttpService.dart';

class Services {

  // Singleton
  Services._();
  static final instance = Services._();

  late LogService log = LogService();
  late EnvService env = EnvService();
  late HttpService http = HttpService();
  late SheetService sheet = SheetService();

}
