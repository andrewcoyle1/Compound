/// The documents a user's circle shares: challenges and their progress,
/// invites, and shared templates and mesocycles.
library;

import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/mesocycle.dart';
import 'package:compound_models/src/workout_template_model.dart';

/// Field names of a [ChallengeModel], exactly as the Swift `CodingKeys`
/// spell them.
abstract final class ChallengeModelKeys {
  /// `id`.
  static const id = 'id';

  /// `owner_id`.
  static const ownerId = 'owner_id';

  /// `title`.
  static const title = 'title';

  /// `target_sessions`.
  static const targetSessions = 'target_sessions';

  /// `starts_at`.
  static const startsAt = 'starts_at';

  /// `ends_at`.
  static const endsAt = 'ends_at';

  /// `member_ids`.
  static const memberIds = 'member_ids';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    ownerId,
    title,
    targetSessions,
    startsAt,
    endsAt,
    memberIds,
    dateCreated,
  ];
}

/// "Train N times between these dates", at `challenges/{id}` (Swift
/// `ChallengeModel`). The owner creates it as a member and may change the
/// title and members; a member may take only themselves out.
class const ChallengeModel({
  /// The challenge's id; also the document id.
  required final String id,

  /// Who made it.
  required final String ownerId,

  /// Its title, 1 to 60 characters.
  required final String title,

  /// Sessions to reach, 1 to 100; an int, as the rules require.
  required final int targetSessions,

  /// When it starts.
  required final DateTime startsAt,

  /// When it ends, after [startsAt].
  required final DateTime endsAt,

  /// Everyone in it, the owner included; at most 50.
  required final List<String> memberIds,

  /// When it was made.
  required final DateTime dateCreated,
}) {
  /// Creates a [ChallengeModel].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does.
  factory fromFirestore(Map<String, Object?> data) => ChallengeModel(
    id: data[ChallengeModelKeys.id]! as String,
    ownerId: data[ChallengeModelKeys.ownerId]! as String,
    title: data[ChallengeModelKeys.title]! as String,
    targetSessions: readInt(data[ChallengeModelKeys.targetSessions]),
    startsAt: data[ChallengeModelKeys.startsAt]! as DateTime,
    endsAt: data[ChallengeModelKeys.endsAt]! as DateTime,
    memberIds: readStringList(data[ChallengeModelKeys.memberIds]),
    dateCreated: data[ChallengeModelKeys.dateCreated]! as DateTime,
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    ChallengeModelKeys.id: id,
    ChallengeModelKeys.ownerId: ownerId,
    ChallengeModelKeys.title: title,
    ChallengeModelKeys.targetSessions: targetSessions,
    ChallengeModelKeys.startsAt: startsAt,
    ChallengeModelKeys.endsAt: endsAt,
    ChallengeModelKeys.memberIds: memberIds,
    ChallengeModelKeys.dateCreated: dateCreated,
  };
}

/// Field names of a [ChallengeProgressModel], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class ChallengeProgressModelKeys {
  /// `sessions`.
  static const sessions = 'sessions';

  /// `updated_at`.
  static const updatedAt = 'updated_at';

  /// Every field, in declaration order.
  static const List<String> all = [sessions, updatedAt];
}

/// One member's count, at `challenges/{id}/progress/{member_id}` (Swift
/// `ChallengeProgressModel`). Only the `onWorkoutSessionEndedForChallenges`
/// function writes it, with the counted `session_ids` too, which the app
/// does not read. A member with no document has not trained yet.
class const ChallengeProgressModel({
  /// Sessions counted.
  required final int sessions,

  /// When the last one was counted.
  final DateTime? updatedAt,
}) {
  /// Creates a [ChallengeProgressModel].
  this;

  /// Decodes as Swift's synthesized decoder does; other keys are ignored.
  factory fromFirestore(Map<String, Object?> data) => ChallengeProgressModel(
    sessions: readInt(data[ChallengeProgressModelKeys.sessions]),
    updatedAt: data[ChallengeProgressModelKeys.updatedAt] as DateTime?,
  );

  /// The Firestore-shaped map Swift would write, a null date left out.
  Map<String, Object?> toFirestore() => {
    ChallengeProgressModelKeys.sessions: sessions,
    ChallengeProgressModelKeys.updatedAt: ?updatedAt,
  };
}

/// Field names of an [InviteModel], exactly as the Swift `CodingKeys` and
/// the `invites` rule's allowed-keys list spell them.
abstract final class InviteModelKeys {
  /// `code`.
  static const code = 'code';

  /// `inviter_id`.
  static const inviterId = 'inviter_id';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `uses`.
  static const uses = 'uses';

  /// `max_uses`.
  static const maxUses = 'max_uses';

  /// Every field, in declaration order. The rules refuse any other key.
  static const List<String> all = [code, inviterId, dateCreated, uses, maxUses];
}

/// One inviter's code, at `invites/{code}` (Swift `InviteModel`). Created
/// unused; only the `acceptInvite` function counts uses.
class const InviteModel({
  /// Eight characters, no 0/O or 1/I/L; also the document id.
  required final String code,

  /// Who it invites to.
  required final String inviterId,

  /// When it was made.
  required final DateTime dateCreated,

  /// Acceptances so far; 0 on create.
  final int uses = 0,

  /// The cap; [defaultMaxUses] on create.
  final int maxUses = defaultMaxUses,
}) {
  /// Creates an [InviteModel].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does.
  factory fromFirestore(Map<String, Object?> data) => InviteModel(
    code: data[InviteModelKeys.code]! as String,
    inviterId: data[InviteModelKeys.inviterId]! as String,
    dateCreated: data[InviteModelKeys.dateCreated]! as DateTime,
    uses: readInt(data[InviteModelKeys.uses]),
    maxUses: readInt(data[InviteModelKeys.maxUses]),
  );

  /// The cap the rules require on create (Swift `InviteModel.maxUses`).
  static const defaultMaxUses = 50;

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    InviteModelKeys.code: code,
    InviteModelKeys.inviterId: inviterId,
    InviteModelKeys.dateCreated: dateCreated,
    InviteModelKeys.uses: uses,
    InviteModelKeys.maxUses: maxUses,
  };
}

/// How a share has been answered (Swift `ShareModel.Status`).
enum ShareStatus implements FirestoreEnum {
  /// `pending`: as the sender creates it.
  pending('pending'),

  /// `accepted`: the recipient copied it into their library.
  accepted('accepted'),

  /// `dismissed`.
  dismissed('dismissed');

  new(this.value);

  @override
  final String value;
}

/// What a share carries (Swift `ShareModel.Payload`).
sealed class SharePayload {
  const new();

  /// `kind`: `template` or `mesocycle`.
  String get kind;

  /// The payload as Firestore stores it.
  Map<String, Object?> toFirestore();
}

/// A shared workout template.
final class TemplateSharePayload extends SharePayload {
  /// Shares [template].
  const new(this.template);

  /// The template, whole.
  final WorkoutTemplateModel template;

  @override
  String get kind => 'template';

  @override
  Map<String, Object?> toFirestore() => template.toFirestore();
}

/// A shared mesocycle.
final class MesocycleSharePayload extends SharePayload {
  /// Shares [mesocycle].
  const new(this.mesocycle);

  /// The mesocycle, templates and all.
  final Mesocycle mesocycle;

  @override
  String get kind => 'mesocycle';

  @override
  Map<String, Object?> toFirestore() => mesocycle.toFirestore();
}

/// Field names of a [ShareModel], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class ShareModelKeys {
  /// `id`.
  static const id = 'id';

  /// `from_user_id`.
  static const fromUserId = 'from_user_id';

  /// `to_user_id`.
  static const toUserId = 'to_user_id';

  /// `kind`.
  static const kind = 'kind';

  /// `payload`.
  static const payload = 'payload';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `status`.
  static const status = 'status';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    fromUserId,
    toUserId,
    kind,
    payload,
    dateCreated,
    status,
  ];
}

/// A template or mesocycle one user sent another, at `shares/{id}` (Swift
/// `ShareModel`), carried whole so the recipient can read it. The sender
/// creates it pending; the recipient answers by writing `status` alone.
class const ShareModel({
  /// The share's id; also the document id.
  required final String id,

  /// The sender.
  required final String fromUserId,

  /// The recipient.
  required final String toUserId,

  /// What it carries.
  required final SharePayload payload,

  /// When it was sent.
  required final DateTime dateCreated,

  /// How it has been answered.
  final ShareStatus status = ShareStatus.pending,
}) {
  /// Creates a [ShareModel].
  this;

  /// Decodes as Swift's `init(from:)` does: `mesocycle`, or `program` from
  /// before the rename, carries a mesocycle; any other kind a template.
  factory fromFirestore(Map<String, Object?> data) {
    final payload = readMap(data[ShareModelKeys.payload]);
    return ShareModel(
      id: data[ShareModelKeys.id]! as String,
      fromUserId: data[ShareModelKeys.fromUserId]! as String,
      toUserId: data[ShareModelKeys.toUserId]! as String,
      dateCreated: data[ShareModelKeys.dateCreated]! as DateTime,
      status: enumFromValue(
        ShareStatus.values,
        data[ShareModelKeys.status]! as String,
      ),
      payload: switch (data[ShareModelKeys.kind]! as String) {
        'mesocycle' ||
        'program' => MesocycleSharePayload(Mesocycle.fromFirestore(payload)),
        _ => TemplateSharePayload(WorkoutTemplateModel.fromFirestore(payload)),
      },
    );
  }

  /// The Firestore-shaped map Swift writes; `kind` follows the payload.
  Map<String, Object?> toFirestore() => {
    ShareModelKeys.id: id,
    ShareModelKeys.fromUserId: fromUserId,
    ShareModelKeys.toUserId: toUserId,
    ShareModelKeys.kind: payload.kind,
    ShareModelKeys.payload: payload.toFirestore(),
    ShareModelKeys.dateCreated: dateCreated,
    ShareModelKeys.status: status.value,
  };
}
