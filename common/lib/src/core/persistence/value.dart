part of '../core.dart';

abstract class BoolPersistedValue extends AsyncValue<bool> {
  late final _persistence = Core.get<Persistence>();

  // Always assumes that default value is false!
  BoolPersistedValue(String key) {
    load = (Marker m) async {
      return await _persistence.load(m, key) == "1";
    };
    save = (Marker m, bool value) async {
      await _persistence.save(m, key, value ? "1" : "");
    };
  }
}

abstract class StringPersistedValue extends NullableAsyncValue<String?> {
  late final _persistence = Core.get<Persistence>();

  StringPersistedValue(String key, {super.sensitive = true}) : super() {
    load = (Marker m) async {
      return await _persistence.load(m, key);
    };
    save = (Marker m, String? value) async {
      if (value == null) {
        await _persistence.delete(m, key);
        return;
      }
      await _persistence.save(m, key, value);
    };
  }
}

/// A string kept in the platform's secure storage (Keystore on Android,
/// Keychain on iOS) instead of the plain preferences.
///
/// It exists for secrets that grant access, such as the Family link token and
/// the lock PIN, which used to be plain values. It keeps the lifetime they had
/// as plain values: the iOS Keychain outlives a reinstall, while the plain
/// storage and the rest of the app state do not. A plain marker records that
/// this install wrote the secret, and a secret without one is left over from
/// an earlier install and is dropped. The secret is not backed up, so a
/// restored install starts without it, as a reinstall does.
///
/// A value an older version stored in plain storage moves to secure storage
/// on its first read.
abstract class SecureStringPersistedValue extends NullableAsyncValue<String?>
    with Logging {
  late final _plain = Core.get<Persistence>();
  late final _secure = Core.get<Persistence>(tag: Persistence.secure);

  SecureStringPersistedValue(String key) : super(sensitive: true) {
    final marker = "$key:secure";
    load = (Marker m) async {
      final legacy = await _plain.load(m, key);
      if (legacy != null) return await _migrate(m, key, marker, legacy);

      if (await _plain.load(m, marker) == null) {
        // Written by an earlier install, or never written.
        await _secure.delete(m, key);
        return null;
      }
      return await _secure.load(m, key);
    };
    save = (Marker m, String? value) async {
      if (value == null) {
        await _secure.delete(m, key);
        await _plain.delete(m, marker);
        await _plain.delete(m, key);
        return;
      }
      try {
        await _secure.save(m, key, value);
      } catch (e) {
        // A fetch saves back what it loaded. If the move failed, the value is
        // still in plain storage and the move is retried on the next read.
        if (await _plain.load(m, key) == value) return;
        rethrow;
      }
      await _plain.save(m, marker, "1");
    };
  }

  /// Moves a plain value to secure storage. When secure storage fails the
  /// plain value stays and is still returned, so the app keeps working and
  /// the move is tried again on the next read.
  Future<String> _migrate(
      Marker m, String key, String marker, String legacy) async {
    try {
      await _secure.save(m, key, legacy);
      await _plain.save(m, marker, "1");
      await _plain.delete(m, key);
    } catch (e) {
      log(m).w("could not move $key to secure storage: $e");
    }
    return legacy;
  }
}

abstract class JsonPersistedValue<T> extends NullableAsyncValue<T?> {
  final bool secure;

  late final _persistence =
      Core.get<Persistence>(tag: secure ? Persistence.secure : null);

  JsonPersistedValue(String key, {this.secure = false})
      : super(sensitive: true) {
    load = (Marker m) async {
      final json = await _persistence.load(m, key);
      if (json == null) return null;
      return fromJson(jsonDecode(json));
    };
    save = (Marker m, T? value) async {
      if (value == null) {
        await _persistence.delete(m, key);
        return;
      }
      await _persistence.save(m, key, jsonEncode(toJson(value)));
    };
  }

  Map<String, dynamic> toJson(T value);
  T fromJson(Map<String, dynamic> json);
}

// Persists any object by "stringifying" it using overridden methods.
abstract class StringifiedPersistedValue<T> extends NullableAsyncValue<T?>
    with Logging {
  late final _persistence = Core.get<Persistence>();

  StringifiedPersistedValue(String key, {super.sensitive = false}) : super() {
    load = (Marker m) async {
      final value = await _persistence.load(m, key);
      if (value == null) return null;
      return fromStringified(value);
    };
    save = (Marker m, T? value) async {
      if (value == null) {
        await _persistence.delete(m, key);
        return;
      }
      await _persistence.save(m, key, toStringified(value));
    };
  }

  String toStringified(T value);
  T fromStringified(String value);
}
