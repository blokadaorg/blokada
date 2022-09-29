// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AccountRepo.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$AccountRepo on _AccountRepo, Store {
  late final _$accountIdAtom =
      Atom(name: '_AccountRepo.accountId', context: context);

  @override
  String get accountId {
    _$accountIdAtom.reportRead();
    return super.accountId;
  }

  @override
  set accountId(String value) {
    _$accountIdAtom.reportWrite(value, super.accountId, () {
      super.accountId = value;
    });
  }

  @override
  String toString() {
    return '''
accountId: ${accountId}
    ''';
  }
}
