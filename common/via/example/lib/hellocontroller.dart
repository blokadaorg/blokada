import 'package:via/dep/dep.dart';

import 'helloprinter.dart';

part 'hellocontroller.g.dart';

@inject
class HelloController {
  late final HelloPrinter _helloPrinter;

  void printHello() {
    _helloPrinter.printHello();
  }
}
