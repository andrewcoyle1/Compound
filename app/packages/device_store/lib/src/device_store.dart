import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Small values kept on this device, as the Swift app keeps them in
/// `UserDefaults`. Reads are synchronous; a write is visible to the next
/// read at once and reaches the disk in the background.
///
/// A value of another type than the one asked for reads as null, so a key
/// whose type changes between builds only resets it.
abstract interface class DeviceStore {
  /// The string kept under [key].
  String? getString(String key);

  /// The flag kept under [key].
  bool? getBool(String key);

  /// The integer kept under [key].
  int? getInt(String key);

  /// The number kept under [key]; an integer reads as a double.
  double? getDouble(String key);

  /// Every key kept.
  Set<String> get keys;

  /// Keeps [value] under [key].
  void setString(String key, String value);

  /// Keeps [value] under [key].
  void setBool(String key, {required bool value});

  /// Keeps [value] under [key].
  void setInt(String key, int value);

  /// Keeps [value] under [key].
  void setDouble(String key, double value);

  /// Forgets [key].
  void remove(String key);
}

/// A [DeviceStore] in memory, for the staging flavor and tests: nothing
/// survives the app being killed.
class InMemoryDeviceStore implements DeviceStore {
  /// Starts with [values], if any.
  new([Map<String, Object> values = const {}]) : _values = {...values};

  final Map<String, Object> _values;

  T? _get<T>(String key) => switch (_values[key]) {
    final T value => value,
    _ => null,
  };

  @override
  String? getString(String key) => _get<String>(key);

  @override
  bool? getBool(String key) => _get<bool>(key);

  @override
  int? getInt(String key) => _get<int>(key);

  @override
  double? getDouble(String key) => _get<num>(key)?.toDouble();

  @override
  Set<String> get keys => {..._values.keys};

  @override
  void setString(String key, String value) => _values[key] = value;

  @override
  void setBool(String key, {required bool value}) => _values[key] = value;

  @override
  void setInt(String key, int value) => _values[key] = value;

  @override
  void setDouble(String key, double value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}

/// A [DeviceStore] in the platform's store (`UserDefaults` on iOS,
/// DataStore on Android), read once at launch and cached.
class SharedPreferencesDeviceStore implements DeviceStore {
  /// Wraps a cache already read; see [create].
  new(this._preferences);

  /// Reads every key once, so later reads are synchronous.
  static Future<SharedPreferencesDeviceStore> create() async =>
      SharedPreferencesDeviceStore(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        ),
      );

  final SharedPreferencesWithCache _preferences;

  T? _get<T>(String key) => switch (_preferences.get(key)) {
    final T value => value,
    _ => null,
  };

  @override
  String? getString(String key) => _get<String>(key);

  @override
  bool? getBool(String key) => _get<bool>(key);

  @override
  int? getInt(String key) => _get<int>(key);

  @override
  double? getDouble(String key) => _get<num>(key)?.toDouble();

  @override
  Set<String> get keys => {..._preferences.keys};

  @override
  void setString(String key, String value) =>
      _write(_preferences.setString(key, value));

  @override
  void setBool(String key, {required bool value}) =>
      _write(_preferences.setBool(key, value));

  @override
  void setInt(String key, int value) => _write(_preferences.setInt(key, value));

  @override
  void setDouble(String key, double value) =>
      _write(_preferences.setDouble(key, value));

  @override
  void remove(String key) => _write(_preferences.remove(key));

  // The cache has the value already; a platform write that fails only
  // loses it at the next launch, which is what a dismissed card risks.
  static void _write(Future<void> write) =>
      unawaited(write.then((_) {}, onError: (Object _) {}));
}
