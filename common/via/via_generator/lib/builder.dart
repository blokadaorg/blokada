import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:via_generator/bootstrap.dart';
import 'package:via_generator/context.dart';
import 'package:via_generator/traced.dart';
import 'package:via_generator/inject.dart';
import 'package:via_generator/into.dart';
import 'package:via_generator/states.dart';
import 'oldinject.dart';
import 'module.dart';

Builder inject(BuilderOptions options) => SharedPartBuilder(
    [InjectGenerator(), ModuleGenerator(), BootstrapGenerator()], 'inject');

Builder context(BuilderOptions options) =>
    SharedPartBuilder([ContextGenerator(), StatesGenerator()], 'context');

Builder dep(BuilderOptions options) => SharedPartBuilder(
    [DepGenerator(), ResolveDepGenerator(), IntoGenerator()], 'dep');
