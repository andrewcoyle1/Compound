import 'package:compound/social/comments/comment_thread.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSessionComment comment(
  String id, {
  required int minute,
  String author = 'a',
  String? name,
  String? parent,
  String text = 'Nice',
  bool? hidden,
  List<String> mentioned = const [],
}) => WorkoutSessionComment(
  id: id,
  sessionId: 's',
  sessionAuthorId: 'owner',
  authorId: author,
  authorName: name,
  text: text,
  dateCreated: DateTime(2026, 10, 15, 9, minute),
  parentId: parent,
  hidden: hidden,
  mentionedUserIds: mentioned,
);

void main() {
  group(CommentThread, () {
    test('threads replies under their roots, oldest first', () {
      final thread = CommentThread.threaded([
        comment('r1', minute: 5, parent: 'c1'),
        comment('c2', minute: 3),
        comment('c1', minute: 1),
        comment('orphan', minute: 4, parent: 'gone'),
      ]);
      expect(thread.map((c) => c.id), ['c1', 'r1', 'c2', 'orphan']);
    });

    test('hides blocked authors and moderated comments with replies', () {
      const viewer = UserModel(userId: 'me', blockedUserIds: ['bad']);
      final visible = CommentThread.visible([
        comment('1', minute: 1, author: 'bad'),
        comment('2', minute: 2, parent: '1'),
        comment('3', minute: 3, hidden: true),
        comment('4', minute: 4, author: 'me', hidden: true),
        comment('5', minute: 5),
      ], viewer);
      expect(visible.map((c) => c.id), ['4', '5']);
    });

    group('mentions', () {
      const viewer = UserModel(
        userId: 'me',
        firstName: 'Alice',
        lastName: 'Cooper',
      );
      final known = CommentThread.knownPeople(
        viewer: viewer,
        following: const [
          UserModel(
            userId: 'm',
            firstName: 'Maya',
            lastName: 'Chen',
            username: 'maya.chen',
          ),
          UserModel(userId: 'nameless'),
        ],
        sessionAuthor: const UserModel(
          userId: 'owner',
          firstName: 'Owen',
          lastName: 'Ng',
        ),
        comments: [
          comment('1', minute: 1, author: 'm', name: 'Old Maya'),
          comment('2', minute: 2, author: 'c', name: 'Charlie Nguyen'),
        ],
      );

      test('know each person once, profiles first', () {
        expect(known.map((p) => p.id), ['me', 'm', 'owner', 'c']);
        expect(known[1].label, '@maya.chen');
        expect(known[3].label, 'Charlie Nguyen');
        expect(known[3].mentionText, 'Charlie');
      });

      test('are suggested after a trailing @, never the reader', () {
        expect(CommentThread.mentionQuery('Hi @ma'), 'ma');
        expect(CommentThread.mentionQuery('Hi @ma '), isNull);
        expect(CommentThread.mentionQuery('a@ma'), isNull);
        expect(
          CommentThread.suggestions('Hi @', known, readerId: 'me'),
          isEmpty,
        );
        expect(
          CommentThread.suggestions(
            'Hi @a',
            known,
            readerId: 'me',
          ).map((p) => p.id),
          isEmpty,
        );
        expect(
          CommentThread.suggestions(
            'Hi @charlien',
            known,
            readerId: 'me',
          ).map((p) => p.id),
          ['c'],
        );
        expect(
          CommentThread.suggestions(
            '@maya.',
            known,
            readerId: 'me',
          ).map((p) => p.id),
          ['m'],
        );
        expect(CommentThread.suggestions('no', known, readerId: 'me'), isEmpty);
      });

      test('are inserted and recorded while still in the text', () {
        final draft = CommentThread.insertMention('Hi @ma', known[1]);
        expect(draft, 'Hi @maya.chen ');
        expect(CommentThread.insertMention('Hi', known[1]), 'Hi');
        expect(CommentThread.mentionedIds(draft, [known[1], known[3]]), ['m']);
      });

      test('are highlighted by either spelling', () {
        final mentioned = comment(
          'x',
          minute: 1,
          text: '@Maya and @maya.chen and @Owen',
          mentioned: ['m'],
        );
        expect(CommentThread.mentionRanges(mentioned, known), [
          (0, 5),
          (10, 20),
        ]);
      });
    });
  });
}
