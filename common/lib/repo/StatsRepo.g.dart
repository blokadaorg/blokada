// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'StatsRepo.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$StatsRepo on _StatsRepo, Store {
  late final _$statsAtom = Atom(name: '_StatsRepo.stats', context: context);

  @override
  UiStats get stats {
    _$statsAtom.reportRead();
    return super.stats;
  }

  @override
  set stats(UiStats value) {
    _$statsAtom.reportWrite(value, super.stats, () {
      super.stats = value;
    });
  }

  @override
  String toString() {
    return '''
stats: ${stats}
    ''';
  }
}
