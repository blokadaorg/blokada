import 'package:via/dep/dep.dart';
import 'package:get_it/get_it.dart';

part 'helloprinter.g.dart';

@injectant
class HelloPrinter {
  late final dependency = GetIt.instance.get<String>();

  HelloPrinter(String b) {}

  String a = "Hello";

  @override
  void printHello() {
    print("Hello");
  }

  void _another(String hi) {}
}
