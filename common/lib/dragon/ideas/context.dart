part of '../via/via.dart';

class ReadWith<C> {
  final Type value;
  final C? context;

  const ReadWith(this.value, {this.context});
}

class WriteWith<C> {
  final Type value;
  final C? context;

  const WriteWith(this.value, {this.context});
}

class CreateWith<C> {
  final Type value;
  final C? context;

  const CreateWith(this.value, {this.context});
}

class CallWith<C> {
  final Type value;
  final C? context;

  const CallWith(this.value, {this.context});
}
