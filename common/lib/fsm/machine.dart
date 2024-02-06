import 'dart:async';

import 'package:collection/collection.dart';

import '../tracer/collectors.dart';
import '../tracer/tracer.dart';
import '../util/di.dart';
import '../util/trace.dart';

typedef Action<I> = Future<void> Function(I);

const machine = Machine();

class Machine {
  const Machine();
}

mixin Context<C> {
  Context<C> copy();
}

typedef State = String;
typedef StateFn<C> = Function(C);

class FailBehavior {
  final String state;
  final bool saveContext;

  FailBehavior(this.state, {this.saveContext = false});
}

mixin StateMachineActions<T> {
  late final Act Function() act;
  late final Function(String) log;
  late final Function(Function(T)) guard;
  late final Future<T> Function(Function(T)) wait;
  late final Function(Function(T), {bool saveContext}) whenFail;
}

abstract class StateMachine<C extends Context<C>> {
  final _queue = <Future Function()>[];

  final Map<State, Map<String, Function(State, C)>> _stateListeners = {};
  final Map<State, List<Completer<C>>> _waitingForState = {};

  late final Map<Function(C), State> states;

  State _state;

  FailBehavior failBehavior;
  late FailBehavior _commonFailBehavior;

  C _context;
  late C _draft;

  late List<Trace> traces;
  late final _tracer = dep<TraceFactory>();

  StateMachine(this._state, this._context, this.failBehavior) {
    _commonFailBehavior = failBehavior;
  }

  enter(State state) async {
    queue(() async {
      traces = [_tracer.newTrace(runtimeType.toString(), state)];
      await _enter(state);
      await traces.last.end();
      traces.removeLast();
    });
  }

  _enter(State state) async {
    final trace = traces.last.start(state, state);
    handleLog("enter: $state");
    _state = state;

    // Execute entering action
    final action =
        states.entries.firstWhereOrNull((it) => it.value == state)?.key;

    if (action != null) {
      try {
        handleLog("action: $state");
        failBehavior = _commonFailBehavior;
        _draft = _context.copy() as C;

        final next = await action(_draft);

        handleLog("done action: $state");
        _context = _draft;

        final nextState = states[next];
        if (nextState != null) {
          traces.add(trace);
          await _enter(nextState);
          traces.removeLast();
        }
        await trace.end();
      } catch (e, s) {
        failEntering(e, s);
        await trace.endWithFailure(e as Exception, s);
      }
    }
    onStateChangedExternal(state);
  }

  event(String name, Function(C) fn) async {
    queue(() async {
      traces = [_tracer.newTrace(runtimeType.toString(), name)];
      await _event(name, fn);
      await traces.last.end();
      traces.removeLast();
    });
  }

  _event(String name, Function(C) fn) async {
    final trace = traces.last.start(name, name);
    try {
      handleLog("start event: $name");
      failBehavior = _commonFailBehavior;
      _draft = _context.copy() as C;

      final next = await fn(_draft);

      handleLog("done event: $name");
      _context = _draft;

      final nextState = states[next];
      if (nextState != null) {
        traces.add(trace);
        await _enter(nextState);
        traces.removeLast();
      }
      await trace.end();
    } catch (e, s) {
      failEntering(e, s);
      await trace.endWithFailure(e as Exception, s);
    }
  }

  failEntering(Object e, StackTrace s) {
    print("fail entering [$runtimeType] error($_state): $e");
    print(s);

    _state = failBehavior.state;
    if (failBehavior.saveContext) {
      _context = _draft;
    }
    _enter(_state);

    // Also fail the waiting completers
    for (final completers in _waitingForState.values) {
      for (final c in completers) {
        queue(() async {
          c.completeError(e, s);
        });
      }
    }
    _waitingForState.clear();
  }

  guardState(StateFn<C> state) {
    final s = states[state]!;
    if (_state != s) throw Exception("invalid state: $_state, exp: $s");
  }

  Future<void> handleLog(String msg) async {
    traces.last.addEvent(msg);
    //print("[$runtimeType] [$_state] $msg");
    //trace.addEvent(msg);
    //trace.addAttribute("state", _state);
  }

  C getContext() {
    // TODO: do we want to expose it
    return _context;
  }

  onStateChangedExternal(State state) {
    final completers = _waitingForState[state];
    if (completers != null) {
      for (final c in completers) {
        queue(() async {
          c.complete(_context);
        });
      }
      _waitingForState[state] = [];
    }

    final listeners = _stateListeners[state]?.entries;
    if (listeners != null) {
      for (final e in listeners) {
        final tag = e.key;
        final fn = e.value;

        queue(() async {
          fn(state, _context);
        });
      }
    }
  }

  addOnState(State state, String tag, Function(State, C) fn) {
    _stateListeners[state] ??= {};
    _stateListeners[state]![tag] = fn;
  }

  Future<C> waitForState(State state) async {
    if (_state == state) return _context;
    final c = Completer<C>();
    _waitingForState[state] ??= [];
    _waitingForState[state]!.add(c);
    return c.future;
  }

  whenState(State s, Function(C) fn) {
    //final s = states[state]!;
    return waitForState(s).then(fn);
  }

  queue(Future Function() fn) {
    _queue.add(fn);
    _process();
  }

  _process() async {
    await Future(() async {
      while (_queue.isNotEmpty) {
        await _queue.removeAt(0)();
      }
    });
  }
}
