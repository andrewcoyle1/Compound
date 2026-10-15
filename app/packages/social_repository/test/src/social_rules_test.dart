import 'dart:math';

import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_repository/social_repository.dart';

void main() {
  group(Username, () {
    test('normalises as Swift does: trimmed, no @, lower case', () {
      expect(Username.normalised('  @Ada.Lovelace \n'), 'ada.lovelace');
      expect(Username.normalised('grace'), 'grace');
    });

    test('validates in Swift order', () {
      expect(Username.validate('ada_99'), UsernameValidation.valid);
      expect(Username.validate('ab'), UsernameValidation.tooShort);
      expect(Username.validate(''), UsernameValidation.tooShort);
      expect(Username.validate('a' * 21), UsernameValidation.tooLong);
      expect(Username.validate('.ada'), UsernameValidation.edgeDot);
      expect(Username.validate('ada.'), UsernameValidation.edgeDot);
      // The character check comes first, as in Swift.
      expect(Username.validate('A'), UsernameValidation.invalidCharacters);
      expect(Username.validate('ad a'), UsernameValidation.invalidCharacters);
      expect(Username.isValid('ada'), isTrue);
      expect(Username.isValid('ad'), isFalse);
    });

    test('routes a search as Swift does', () {
      expect(Username.searchRoute('@Ada'), (name: null, handlePrefix: 'ada'));
      expect(Username.searchRoute('@a b'), (name: null, handlePrefix: null));
      expect(Username.searchRoute(' Ada '), (name: 'Ada', handlePrefix: 'ada'));
      expect(Username.searchRoute('Ada Lovelace'), (
        name: 'Ada Lovelace',
        handlePrefix: null,
      ));
      expect(Username.searchRoute('a' * 21), (
        name: 'a' * 21,
        handlePrefix: null,
      ));
      expect(Username.searchRoute('  '), (name: null, handlePrefix: null));
    });
  });

  group(InviteCode, () {
    test('draws eight characters from the alphabet', () {
      final code = InviteCode.random(Random(1));
      expect(code, hasLength(InviteCode.length));
      expect(InviteCode.normalised(code), code);
      expect(InviteCode.random(), hasLength(8));
    });

    test('normalises a typed code, or refuses it', () {
      expect(InviteCode.normalised('push 2345'), 'PUSH2345');
      expect(InviteCode.normalised('push-2345'), 'PUSH2345');
      expect(InviteCode.normalised('PUSH234'), isNull);
      expect(InviteCode.normalised('PUSH2340'), isNull);
      expect(InviteCode.normalised('IOLO2345'), isNull);
    });
  });

  test('FollowingQueries caps ids at 30, unique, in order', () {
    final ids = [for (var i = 0; i < 45; i++) 'user-$i'];
    expect(FollowingQueries.cappedIds(ids), ids.take(30));
    expect(FollowingQueries.cappedIds(['a', 'b', 'a', 'c', 'b']), [
      'a',
      'b',
      'c',
    ]);
  });

  group('names', () {
    test('prefer what the user typed, skipping empty names', () {
      const user = UserModel(
        userId: 'u',
        firstName: 'Augusta',
        lastName: 'Byron',
        submittedFirstName: 'Ada',
        submittedLastName: '',
        photoUrl: 'auth.jpg',
      );
      expect(firstNameOf(user), 'Ada');
      expect(fullNameOf(user), 'Ada Byron');
      expect(profileImageOf(user), 'auth.jpg');
      expect(
        profileImageOf(
          const UserModel(userId: 'u', submittedProfileImage: 'mine.jpg'),
        ),
        'mine.jpg',
      );
    });

    test('use whichever name there is', () {
      expect(
        fullNameOf(const UserModel(userId: 'u', lastName: 'Byron')),
        'Byron',
      );
      expect(fullNameOf(const UserModel(userId: 'u', firstName: 'Ada')), 'Ada');
      expect(fullNameOf(const UserModel(userId: 'u', firstName: '')), isNull);
    });
  });

  group('commentNotifications', () {
    WorkoutSessionComment comment({
      String authorId = 'writer',
      String? parentId,
      List<String> mentions = const [],
      String? name = 'Writer',
    }) => WorkoutSessionComment(
      id: 'c1',
      sessionId: 's1',
      sessionAuthorId: 'owner',
      authorId: authorId,
      authorName: name,
      authorImageUrl: 'w.jpg',
      text: 'Nice',
      dateCreated: DateTime.utc(2026, 10, 14),
      parentId: parentId,
      mentionedUserIds: mentions,
    );

    test('tells the session author, as a comment, with the comment', () {
      final [(recipient, notification)] = commentNotifications(comment());
      expect(recipient, 'owner');
      expect(
        notification.toFirestore(),
        ActivityNotificationModel(
          id: 'comment_c1',
          type: ActivityType.comment,
          actorId: 'writer',
          actorName: 'Writer',
          actorImageUrl: 'w.jpg',
          sessionId: 's1',
          sessionAuthorId: 'owner',
          commentText: 'Nice',
          dateCreated: DateTime.utc(2026, 10, 14),
        ).toFirestore(),
      );
    });

    test('tells the parent author of a reply, and mentions, once each', () {
      final sent = commentNotifications(
        comment(parentId: 'p', mentions: ['zed', 'parent', 'writer', 'amy']),
        parentAuthorId: 'parent',
      );
      expect(
        [for (final (id, n) in sent) (id, n.type, n.isReply, n.id)],
        [
          ('owner', ActivityType.comment, false, 'comment_c1'),
          ('parent', ActivityType.comment, true, 'comment_c1'),
          ('amy', ActivityType.mention, false, 'mention_c1'),
          ('zed', ActivityType.mention, false, 'mention_c1'),
        ],
      );
    });

    test('tells the writer nothing; a session author replied to hears a '
        'comment', () {
      expect(commentNotifications(comment(authorId: 'owner')), isEmpty);
      final [(_, notification)] = commentNotifications(
        comment(parentId: 'p', name: null),
        parentAuthorId: 'owner',
      );
      expect(notification.isReply, isFalse);
      expect(notification.actorName, 'Someone');
    });
  });
}
