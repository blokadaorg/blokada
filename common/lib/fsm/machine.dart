import 'dart:async';

import 'package:collection/collection.dart';

import '../util/di.dart';
import '../util/trace.dart';

// use for any field in your class that you want vistraced
// also version for lists and collections
// what it does:
// - encapsulate piece of state with safe transaction rollback
// - logging, tracing, visualisation of changes (json tostring)
// - forward action to actual handler (DI / testing)
// - error handling
// - notifying / forwarding changes (no rx functions)
// - common actions (like api crud, persistence, etc)
// - maybe can be used for common testing scenarios (codegen)

class AsyncField<T> {
  late T _current;
  late T _previous;

  AsyncField();

  AsyncField.from(T initial) {
    _current = initial;
  }

  set(T value) {
    try {
      _previous = _current;
    } catch (e) {
      //_previous = value;
      // _previous = compute();
      // also on change of other (composed) asyncfields
      // sounds like react/widgets in flutter
      // ddziedziczenie a nadpisanie method do loggingu, czy
      // bedzie to wywolywac w odpowiedniej implementacji (np parse
      // wola reconfigure)?
    }
    _current = value;
  }

  get() async {
    return _current;
  }
}

enum FilterState { reload, parse, ready, fail }

class FilterAsyncField extends AsyncField<FilterState> {
  FilterAsyncField() : super();

  // child async fields ...

  FilterState compute() {
    // returns state, hits methods if needed
    // getter makes cache
    // field cannot change without external triggers (notify from children or else)
    throw "a";
  }

  // state methods (reload, parse, ...)
  // Isn't Machine just an implementation of AsyncField?

// any field can be wait() ed on asynchronously (on first value, maybe on next value)
// kinda lightweight observables.. but maybe that's good
// easy no-crash way to specify dependencies in a late manner (what not how)
// drawback - requires to rewrite code a lot? (but maybe not, if it's just a field)
// easy plug anything in testing (even private fields?)
// who specifies actual implementations and when?
// - something like FilterProd? must be hierarchical (who sets up ApiField)
// - back to Act idea provided to every field (like context)?
// providing events to field? Any method on type, like add() on ListAsyncField
// or enableFilter() on FilterStatesAsyncField
// also waitForValue() async or other futures? subscriber
// behavior(AsyncField<List<JsonListItem>) vs implementation (ApiField(Endpoint))
// code consists of tiny encapsulated modules with fewest dependencies
}

// ApiIt - for api calls, but returns like It and can be replaced
// easily. + async, logging
// It - for anything that has a state, that is read and/or written
// == AsyncField. Is FilterStates also AsyncField? composition?
// AsyncField<StateEnum> - for *States

typedef Action<I, O> = Future<O> Function(I);

const machine = Machine();

class Machine {
  const Machine();
}

mixin Context<C> {
  Context<C> copy();

  late final Function(String) log;
  late final Function(List<StateFn<C>>) guard;
  late final Future<C> Function(StateFn<C>) wait;
  late final Function(StateFn<C>, {bool saveContext}) whenFail;
  late final Function(List<Object?>) ensureNotNull;

  Action<I, O> noopAction<I, O>(String name) => (I _) async {
        log("Action $name is not defined");
        return null as O;
      };
}

typedef State = String;
typedef StateFn<C> = Function(C);

class FailBehavior {
  final String state;
  final bool saveContext;

  FailBehavior(this.state, {this.saveContext = false});
}

class StateMachine<C extends Context<C>> {
  final _queue = <Future Function()>[];

  final Map<State, Map<String, Function(State, C)>> _stateListeners = {};
  final Map<State, List<Completer<C>>> _waitingForState = {};

  late final Map<StateFn<C>, State> states;

  State _state;
  bool _transitioning = false;

  FailBehavior failBehavior;
  late FailBehavior _commonFailBehavior;

  late C _context;
  late C _draft;

  late List<Trace> traces;
  late final _tracer = dep<TraceFactory>();

  StateMachine(this._state, this._context, this.failBehavior) {
    _commonFailBehavior = failBehavior;

    _context.whenFail = (state, {saveContext = false}) =>
        failBehavior = FailBehavior(states[state]!, saveContext: saveContext);
    _context.guard = (state) => guardState(state);
    _context.wait = (state) => waitForState(state);
    _context.log = (msg) => handleLog(msg);
  }

  enter(StateFn<C> state) async {
    final s = states[state]!;
    _transitioning = true;
    queue(() async {
      traces = [_tracer.newTrace(runtimeType.toString(), s)];
      await _enter(s);
      await traces.last.end();
      traces.removeLast();
    });
  }

  _enter(State state) async {
    final trace = traces.last.start(state, state);
    handleLog("enter: $state");

    // Execute entering action
    final action =
        states.entries.firstWhereOrNull((it) => it.value == state)?.key;

    if (action != null) {
      try {
        handleLog("action: $state");
        failBehavior = _commonFailBehavior;
        _draft = _context.copy() as C;
        _draft.whenFail = _context.whenFail;
        _draft.guard = _context.guard;
        _draft.wait = _context.wait;
        _draft.log = _context.log;

        final next = await action(_draft);

        handleLog("done action: $state");
        _context = _draft;

        _state = state;

        final nextState = states[next];
        if (nextState != null) {
          traces.add(trace);
          await _enter(nextState);
          traces.removeLast();
        }
        await trace.end();
      } catch (e, s) {
        if (e is Exception) {
          await trace.endWithFailure(e, s);
        } else {
          await trace.endWithFatal(e as Error, s);
        }
        await failEntering(e, s);
      }
    } else {
      _state = state;
    }
    _transitioning = false;
    onStateChangedExternal(state);
  }

  failEntering(Object e, StackTrace s) async {
    print("fail entering [$runtimeType] error($_state): $e");
    print(s);

    _state = failBehavior.state;
    if (failBehavior.saveContext) {
      _context = _draft;
    }
    await _enter(_state);
    _transitioning = false;

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

  guardState(List<StateFn<C>> states) {
    final s = states.map((it) => this.states[it]!).toList();
    if (!s.contains(_state)) throw Exception("invalid state: $_state, exp: $s");
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

  addOnState(StateFn<C> state, String tag, Function(State, C) fn) {
    final s = states[state]!;
    _stateListeners[s] ??= {};
    _stateListeners[s]![tag] = fn;
  }

  Future<C> waitForState(StateFn<C> state) async {
    final s = states[state]!;
    if (_state == s && !_transitioning) return _context;
    final c = Completer<C>();
    _waitingForState[s] ??= [];
    _waitingForState[s]!.add(c);
    return c.future;
  }

  whenState(StateFn<C> s, Function(C) fn) {
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
