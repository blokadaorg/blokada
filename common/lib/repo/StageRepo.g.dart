// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'StageRepo.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StageRepo on _StageRepo, Store {
  late final _$isForegroundAtom =
      Atom(name: '_StageRepo.isForeground', context: context);

  @override
  bool get isForeground {
    _$isForegroundAtom.reportRead();
    return super.isForeground;
  }

  @override
  set isForeground(bool value) {
    _$isForegroundAtom.reportWrite(value, super.isForeground, () {
      super.isForeground = value;
    });
  }

  @override
  String toString() {
    return '''
isForeground: ${isForeground}
    ''';
  }
}
