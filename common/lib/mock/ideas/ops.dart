part of '../via/via.dart';

class Operation {
  const Operation();
}

mixin Op<C> {
  late final Type inputType;
  late final Type outputType;
  late C context;
}

mixin CallOp<P, C, O> on Op<C> {
  Future<O> call(P payload);
}

mixin ReadOp<P, C> on Op<C> {
  Future<P> read();
}

mixin WriteOp<P, C> on Op<C> {
  Future<void> write(P payload);
}

mixin CreateOp<P, C> on Op<C> {
  Future<P> create(P payload);
}

abstract class ListOp<P, C>
    with Op<C>, ReadOp<List<P>, C>, WriteOp<List<P>, C>, CreateOp<P, C> {}

abstract class SimpleCallOp<P, O> with Op, CallOp<P, void, O> {}

abstract class SimpleReadOp<P> with Op, ReadOp<P, void> {}
