import 'dart:async';

import 'package:compound/undo/pending_deletes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(PendingDeletes, () {
    late PendingDeletes pending;
    late List<String> written;

    setUp(() {
      pending = PendingDeletes();
      written = [];
    });

    tearDown(() => pending.close());

    Future<void> Function() write(String key) =>
        () async => written.add(key);

    test('hides a scheduled key until it is undone, writing nothing', () {
      pending.schedule('gyms/a', write('gyms/a'));
      expect(pending.keys, {'gyms/a'});
      expect(pending.contains('gyms/a'), isTrue);

      expect(pending.undo('gyms/a'), isTrue);
      expect(pending.keys, isEmpty);
      expect(pending.undo('gyms/a'), isFalse);
      expect(written, isEmpty);
    });

    test(
      'commit writes it, and keeps it hidden until the write is done',
      () async {
        final write = Completer<void>();
        pending.schedule('gyms/a', () => write.future);
        final commit = pending.commit('gyms/a');
        await Future<void>.delayed(Duration.zero);
        expect(pending.contains('gyms/a'), isTrue);
        write.complete();
        await commit;
        expect(pending.keys, isEmpty);
      },
    );

    test('a commit that throws shows the item again and rethrows', () async {
      pending.schedule('gyms/a', () async => throw StateError('offline'));
      await expectLater(pending.commit('gyms/a'), throwsStateError);
      expect(pending.keys, isEmpty);
    });

    test('committing a key that is not waiting does nothing', () async {
      await pending.commit('gyms/a');
      expect(written, isEmpty);
    });

    test(
      'a key scheduled again while committing keeps its new commit',
      () async {
        final first = Completer<void>();
        pending.schedule('gyms/a', () => first.future);
        final commit = pending.commit('gyms/a');
        pending.schedule('gyms/a', write('again'));
        first.complete();
        await commit;
        expect(pending.contains('gyms/a'), isTrue);
        await pending.commit('gyms/a');
        expect(written, ['again']);
      },
    );

    test(
      'flushAll writes every key, and a failure does not stop the rest',
      () async {
        pending
          ..schedule('gyms/a', write('gyms/a'))
          ..schedule('gyms/b', () async => throw StateError('offline'))
          ..schedule('gyms/c', write('gyms/c'));
        await pending.flushAll();
        expect(written, unorderedEquals(['gyms/a', 'gyms/c']));
        expect(pending.keys, isEmpty);
      },
    );

    test('watch gives the keys now, then each change', () async {
      pending.schedule('gyms/a', write('gyms/a'));
      final seen = <Set<String>>[];
      final subscription = pending.watch().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      pending
        ..schedule('gyms/b', write('gyms/b'))
        ..undo('gyms/a');
      await Future<void>.delayed(Duration.zero);
      expect(seen, [
        {'gyms/a'},
        {'gyms/a', 'gyms/b'},
        {'gyms/b'},
      ]);
      await subscription.cancel();
    });

    test('says nothing once closed', () async {
      await pending.close();
      pending.schedule('gyms/a', write('gyms/a'));
      expect(pending.keys, {'gyms/a'});
    });
  });

  group('HidePending', () {
    test('drops the items whose key is waiting', () {
      expect(['a', 'b', 'c'].hide({'gyms/b'}, (id) => 'gyms/$id'), ['a', 'c']);
    });
  });
}
