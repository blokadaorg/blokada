import 'package:via/dep/dep.dart';

import 'hellocontroller.dart';
import 'helloprinter.dart';

part 'example3.g.dart';

@into
class Module with _$Module {
  late final HelloController _hello;

  Module() {
    injector.register<HelloPrinter>(HelloPrinter("hi"));
    registerControllers();
  }
}

void main() async {
  Module();
  final ctrl = injector.get<HelloController>();
  ctrl.printHello();
}
