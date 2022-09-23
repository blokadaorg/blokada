// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppRepo.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AppRepo on _AppRepo, Store {
  late final _$appStateAtom = Atom(name: '_AppRepo.appState', context: context);

  @override
  AppModel get appState {
    _$appStateAtom.reportRead();
    return super.appState;
  }

  @override
  set appState(AppModel value) {
    _$appStateAtom.reportWrite(value, super.appState, () {
      super.appState = value;
    });
  }

  @override
  String toString() {
    return '''
appState: ${appState}
    ''';
  }
}
