import 'package:device_store/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// A platform store whose writes all fail.
final class _FailingPreferences extends InMemorySharedPreferencesAsync {
  new() : super.empty();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => throw StateError('disk full');
}

void main() {
  void behavesAsAStore(Future<DeviceStore> Function(Map<String, Object>) make) {
    test('reads what was written, by type', () async {
      final store = await make({});
      store
        ..setString('s', 'week')
        ..setBool('b', value: true)
        ..setInt('i', 3)
        ..setDouble('d', 2.5);
      expect(store.getString('s'), 'week');
      expect(store.getBool('b'), isTrue);
      expect(store.getInt('i'), 3);
      expect(store.getDouble('d'), 2.5);
      expect(store.keys, {'s', 'b', 'i', 'd'});
    });

    test('reads a missing key or another type as null', () async {
      final store = await make({'s': 'text', 'i': 4});
      expect(store.getString('missing'), isNull);
      expect(store.getBool('s'), isNull);
      expect(store.getInt('s'), isNull);
      expect(store.getString('i'), isNull);
      expect(store.getDouble('s'), isNull);
    });

    test('reads an integer as a double', () async {
      final store = await make({'i': 4});
      expect(store.getDouble('i'), 4.0);
    });

    test('forgets a removed key', () async {
      final store = await make({'s': 'text'})
        ..remove('s');
      expect(store.getString('s'), isNull);
      expect(store.keys, isEmpty);
    });
  }

  group(InMemoryDeviceStore, () {
    behavesAsAStore((values) async => InMemoryDeviceStore(values));

    test('starts empty', () {
      expect(InMemoryDeviceStore().keys, isEmpty);
    });
  });

  group(SharedPreferencesDeviceStore, () {
    behavesAsAStore((values) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(values);
      return SharedPreferencesDeviceStore.create();
    });

    test('keeps writes in the platform store', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      (await SharedPreferencesDeviceStore.create())
        ..setString('s', 'week')
        ..setBool('b', value: false)
        ..setInt('i', 1)
        ..setDouble('d', 0.5)
        ..setString('gone', 'x')
        ..remove('gone');
      await pumpEventQueue();
      final reread = await SharedPreferencesDeviceStore.create();
      expect(reread.getString('s'), 'week');
      expect(reread.getBool('b'), isFalse);
      expect(reread.getInt('i'), 1);
      expect(reread.getDouble('d'), 0.5);
      expect(reread.getString('gone'), isNull);
    });

    test('keeps a value in the cache when the platform write fails', () async {
      SharedPreferencesAsyncPlatform.instance = _FailingPreferences();
      final store = await SharedPreferencesDeviceStore.create()
        ..setString('s', 'week');
      await pumpEventQueue();
      expect(store.getString('s'), 'week');
    });
  });
}
