import 'package:common/service/SheetService.dart';

import 'HttpService.dart';

class Services {

  // Singleton
  Services._();
  static final instance = Services._();

  late HttpService http = HttpService();
  late SheetService sheet = SheetService();

}
