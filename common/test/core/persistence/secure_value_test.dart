import 'package:common/src/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

void main() {
  group("SecureStringPersistedValue", () {
    test("keeps a new value out of plain storage", () async {
      await withTrace((m) async {
        final store = _setUp();

        await _Secret().change(m, "pin");

        expect(store.secure["key"], "pin");
        expect(store.plain.containsKey("key"), isFalse);
        expect(await _Secret().fetch(m), "pin");
      });
    });

    test("moves a plain value from an older version", () async {
      await withTrace((m) async {
        final store = _setUp(plain: {"key": "token"});

        expect(await _Secret().fetch(m), "token");
        expect(store.secure["key"], "token");
        expect(store.plain.containsKey("key"), isFalse);
        expect(await _Secret().fetch(m), "token");
      });
    });

    test("keeps the plain value when secure storage fails", () async {
      await withTrace((m) async {
        final store = _setUp(plain: {"key": "token"}, failSecure: true);

        expect(await _Secret().fetch(m), "token");
        expect(store.plain["key"], "token");
      });
    });

    test("drops a secret left by an earlier install", () async {
      await withTrace((m) async {
        // The iOS Keychain survives a reinstall, the plain marker does not.
        final store = _setUp(secure: {"key": "token"});

        expect(await _Secret().fetch(m), isNull);
        expect(store.secure.containsKey("key"), isFalse);
      });
    });

    test("a failed read does not delete the secret", () async {
      await withTrace((m) async {
        final store = _setUp();
        await _Secret().change(m, "token");
        store.failSecure = true;

        expect(await _Secret().fetch(m), isNull);

        store.failSecure = false;
        expect(store.secure["key"], "token");
        expect(await _Secret().fetch(m), "token");
      });
    });

    test("clearing removes the secret and its marker", () async {
      await withTrace((m) async {
        final store = _setUp();
        await _Secret().change(m, "token");

        await _Secret().change(m, null);

        expect(store.secure, isEmpty);
        expect(store.plain, isEmpty);
        expect(await _Secret().fetch(m), isNull);
      });
    });
  });
}

class _Secret extends SecureStringPersistedValue {
  _Secret() : super("key");
}

_Store _setUp({
  Map<String, String> plain = const {},
  Map<String, String> secure = const {},
  bool failSecure = false,
}) {
  final store = _Store(Map.of(plain), Map.of(secure), failSecure);
  Core.di.unregister<PersistenceChannel>(instanceName: "default");
  Core.register<PersistenceChannel>(store);
  Core.register<Persistence>(Persistence(isSecure: false));
  Core.register<Persistence>(Persistence(isSecure: true),
      tag: Persistence.secure);
  return store;
}

/// Keeps secure and plain values apart, as the platforms do.
class _Store with PersistenceChannel {
  final Map<String, String> plain;
  final Map<String, String> secure;
  bool failSecure;

  _Store(this.plain, this.secure, this.failSecure);

  Map<String, String> _map(bool isSecure) {
    if (isSecure && failSecure) throw Exception("secure storage unavailable");
    return isSecure ? secure : plain;
  }

  @override
  Future<String> doLoad(String key, bool isSecure, bool isBackup) async {
    final value = _map(isSecure)[key];
    if (value == null) throw Exception("No value for $key");
    return value;
  }

  @override
  Future<void> doSave(
      String key, String value, bool isSecure, bool isBackup) async {
    _map(isSecure)[key] = value;
  }

  @override
  Future<void> doDelete(String key, bool isSecure, bool isBackup) async {
    _map(isSecure).remove(key);
  }
}
