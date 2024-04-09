part 'injector.dart';

// Annotations start here

class Bootstrap {
  final ViaAct act;

  const Bootstrap(this.act);
}

class Module {
  final ViaActSpec act;

  final List<Matcher> matchers;

  const Module(this.matchers, {this.act = const ViaActSpec()});
}

class Injected {
  final bool log;
  final bool onlyVia;
  final bool immediate;

  const Injected(
      {this.log = false, this.onlyVia = false, this.immediate = false});
}

class Matcher {
  final Type forType;
  final Type useType;
  final String of;

  const Matcher(this.forType, this.useType, {this.of = Via.ofDefault});
}

class SimpleMatcher<T> extends Matcher {
  final Type type;

  const SimpleMatcher(this.type) : super(type, type);
}

class ViaMatcher<T> extends Matcher {
  final Type type;

  const ViaMatcher(this.type, {of = Via.ofDefault})
      : super(HandleVia<T>, type, of: of);
}

class MatcherSpec {
  final String of;
  final Object? ctx;

  const MatcherSpec({this.of = Via.ofDefault, this.ctx});
}

enum ViaPlatform { ios, android, web }

class ViaActSpec {
  final String? scenario;
  final ViaPlatform? platform;
  final String? flavor;

  const ViaActSpec({
    this.scenario,
    this.platform,
    this.flavor,
  });
}

class ViaAct {
  final String scenario;
  final ViaPlatform platform;
  final String flavor;

  const ViaAct({
    required this.scenario,
    required this.platform,
    required this.flavor,
  });

  bool isProduction() => scenario == "production";
}

// Implementations start here

abstract class HandleVia<T> {
  final listeners = <dynamic Function()>[];
  late Object context;

  T defaults() =>
      throw Exception("This via handler does not support defaults()");
  Future<void> set(T value) async {}
  Future<T> get() => throw Exception("This via handler does not support get()");
  Future<T> add(T value) async => value;

  dirty() {
    for (final fn in listeners) {
      fn();
    }
  }
}

class ViaCall {
  late final MatcherSpec spec;
  late final HandleVia<void> via;
  bool _injected = false;

  call() async {
    _ensureViaInjected();
    via.context = spec.ctx!;
    await via.set(null);
  }

  inject(Injector injector, MatcherSpec spec) {
    if (_injected) return;
    _injected = true;
    this.spec = spec;

    via = injector.get(key: spec.of);
  }

  _ensureViaInjected() {
    if (!_injected) {
      throw Exception("ViaCall not injected");
    }
  }
}

class ViaBase<T> {
  bool empty = true;
  bool dirty = true;
  bool _injected = false;
  late T _value;

  late final HandleVia<T> via;
  late final MatcherSpec spec;

  final onSet = <dynamic Function()>[];

  ViaBase();

  T get now {
    if (empty) _value = _resolveDefault();
    if (empty || dirty) fetch(notify: true);
    empty = false;
    return _value;
  }

  T _resolveDefault() {
    _ensureViaInjected();
    try {
      return via.defaults();
    } catch (_) {
      if (null is T) {
        return null as T;
      } else {
        rethrow;
      }
    }
  }

  Future<T> fetch({bool notify = false}) async {
    if (!dirty) return _value;
    _ensureViaInjected();
    via.context = spec.ctx!;
    _value = await via.get();
    dirty = false;
    empty = false;
    if (notify) _notify();
    return _value;
  }

  Future<void> set(T value, {bool notify = true}) async {
    _ensureViaInjected();
    via.context = spec.ctx!;
    await via.set(value);
    this._value = value;
    dirty = false;
    empty = false;
    if (notify) _notify();
  }

  _notify() async {
    for (final fn in onSet) {
      fn();
    }
  }

  also(dynamic Function() fn) {
    onSet.add(fn);
  }

  inject(Injector injector, MatcherSpec spec) {
    if (_injected) return;
    _injected = true;
    this.spec = spec;
    _inject(injector);
  }

  _inject(Injector injector) {
    via = injector.get(key: spec.of);
    via.listeners.add(() async {
      dirty = true;
      fetch(notify: true);
    });
  }

  _ensureViaInjected() {
    if (!_injected) {
      throw Exception("Via not injected: $T");
    }
  }
}

class ViaList<T> extends ViaBase<List<T>> {
  late final HandleVia<T> itemVia;

  @override
  List<T> _resolveDefault() {
    try {
      return super._resolveDefault();
    } catch (_) {
      return [];
    }
  }

  Future<T> add(T value) async {
    _ensureViaInjected();
    itemVia.context = spec.ctx!;
    final newValue = await itemVia.add(value);
    // check dirty?
    _value.add(newValue);
    _notify();
    return newValue;
  }

  T? find(bool Function(T) predicate) {
    if (dirty) return null; // or exception?
    return _value.firstWhere(predicate, orElse: () => null as T);
  }

  @override
  inject(Injector injector, MatcherSpec spec) {
    if (_injected) return;
    _injected = true;
    this.spec = spec;
    super._inject(injector);

    itemVia = injector.get(key: spec.of);
    itemVia.listeners.add(() async {
      dirty = true;
      fetch(notify: true);
    });
  }
}

class Via {
  static const ofDefault = "ofDefault";

  static ViaBase<T> as<T>() {
    return ViaBase<T>();
  }

  static ViaCall call() {
    return ViaCall();
  }

  static ViaList<T> list<T>() {
    return ViaList<T>();
  }
}

mixin Injectable {
  void inject();
}

mixin Injects {
  Map<Type, dynamic> register();
}
