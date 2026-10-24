/// The AI coach's conversations, at `users/{uid}/coach_chats/{id}` (Swift
/// `CoachModels.swift`). Only the `coachChat` Cloud Function writes them;
/// the apps read and delete them.
library;

import 'package:compound_models/src/firestore_enum.dart';

/// Field names of a [CoachChat], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class CoachChatKeys {
  /// `id`.
  static const id = 'id';

  /// `title`.
  static const title = 'title';

  /// `created_at`.
  static const createdAt = 'created_at';

  /// `updated_at`.
  static const updatedAt = 'updated_at';

  /// `context_kind`.
  static const contextKind = 'context_kind';

  /// `messages`.
  static const messages = 'messages';

  /// `day`: a day chat's day, `YYYY-MM-DD`.
  static const day = 'day';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    title,
    createdAt,
    updatedAt,
    contextKind,
    messages,
    day,
  ];
}

/// Field names of a [CoachMessage], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class CoachMessageKeys {
  /// `id`.
  static const id = 'id';

  /// `role`.
  static const role = 'role';

  /// `text`.
  static const text = 'text';

  /// `created_at`.
  static const createdAt = 'created_at';

  /// `blocks`: an assistant message's generative UI blocks, if any.
  static const blocks = 'blocks';
}

/// Field names of a [CoachBlock], as the `coachChat` function writes them.
abstract final class CoachBlockKeys {
  /// `surfaceId`.
  static const surfaceId = 'surfaceId';

  /// `kind`.
  static const kind = 'kind';

  /// `as_of`.
  static const asOf = 'as_of';

  /// `fallback`.
  static const fallback = 'fallback';

  /// `messages`.
  static const messages = 'messages';
}

/// One generative UI block under a coach reply, as saved: an A2UI v0.9
/// surface on the `compound.coach.v1` catalog, and the plain text to show
/// instead when it cannot be rendered (docs/specs/ai-coach.md, "Generative
/// UI (v1)"). Only Flutter renders blocks; Swift ignores the field.
class const CoachBlock({
  /// The A2UI surface id, `<messageId>-<n>`.
  required final String surfaceId,

  /// The block kind, such as `trend_chart`, kept as the stored string so
  /// a kind this build does not know still decodes and shows [fallback].
  required final String kind,

  /// The day its figures were read, `YYYY-MM-DD`: a saved chat replays
  /// this snapshot.
  required final String asOf,

  /// What it shows, as plain text.
  required final String fallback,

  /// The A2UI messages, in order, exactly as streamed.
  required final List<Map<String, Object?>> messages,
}) {
  /// Creates a [CoachBlock].
  this;

  /// Decodes strictly.
  factory fromFirestore(Map<String, Object?> data) => CoachBlock(
    surfaceId: data[CoachBlockKeys.surfaceId]! as String,
    kind: data[CoachBlockKeys.kind]! as String,
    asOf: data[CoachBlockKeys.asOf]! as String,
    fallback: data[CoachBlockKeys.fallback]! as String,
    messages: [
      for (final message in data[CoachBlockKeys.messages]! as List<Object?>)
        message! as Map<String, Object?>,
    ],
  );

  /// The Firestore-shaped map the function writes.
  Map<String, Object?> toFirestore() => {
    CoachBlockKeys.surfaceId: surfaceId,
    CoachBlockKeys.kind: kind,
    CoachBlockKeys.asOf: asOf,
    CoachBlockKeys.fallback: fallback,
    CoachBlockKeys.messages: messages,
  };
}

/// Who wrote a [CoachMessage] (Swift `CoachMessage.Role`).
enum CoachMessageRole implements FirestoreEnum {
  /// `user`.
  user('user'),

  /// `assistant`: the coach.
  assistant('assistant');

  new(this.value);

  @override
  final String value;
}

/// One turn of a [CoachChat] (Swift `CoachMessage`).
class const CoachMessage({
  /// The message's id.
  required final String id,

  /// Who wrote it.
  required final CoachMessageRole role,

  /// What it says.
  required final String text,

  /// When it was written.
  required final DateTime createdAt,

  /// The blocks shown under an assistant reply, in order; absent when
  /// there were none.
  final List<CoachBlock>? blocks,
}) {
  /// Creates a [CoachMessage].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does.
  factory fromFirestore(Map<String, Object?> data) => CoachMessage(
    id: data[CoachMessageKeys.id]! as String,
    role: enumFromValue(
      CoachMessageRole.values,
      data[CoachMessageKeys.role]! as String,
    ),
    text: data[CoachMessageKeys.text]! as String,
    createdAt: data[CoachMessageKeys.createdAt]! as DateTime,
    blocks: (data[CoachMessageKeys.blocks] as List<Object?>?)
        ?.map(
          (block) => CoachBlock.fromFirestore(block! as Map<String, Object?>),
        )
        .toList(),
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    CoachMessageKeys.id: id,
    CoachMessageKeys.role: role.value,
    CoachMessageKeys.text: text,
    CoachMessageKeys.createdAt: createdAt,
    CoachMessageKeys.blocks: ?blocks
        ?.map((block) => block.toFirestore())
        .toList(),
  };
}

/// One conversation with the coach (Swift `CoachChat`).
class const CoachChat({
  /// The chat's id; also the document id.
  required final String id,

  /// Its first message, shortened.
  required final String title,

  /// When it began.
  required final DateTime createdAt,

  /// When the last answer arrived.
  required final DateTime updatedAt,

  /// Both sides of the conversation, oldest first.
  required final List<CoachMessage> messages,

  /// Where it was opened from: a `CoachContext` kind such as
  /// `weight_trend`, kept as the stored string.
  final String? contextKind,

  /// For a day chat (its id is the day too), the user's day it belongs to,
  /// `YYYY-MM-DD`; absent for a chat from before day chats. Swift ignores
  /// it.
  final String? day,
}) {
  /// Creates a [CoachChat].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does: a null
  /// `context_kind`, which the function writes for a chat opened with no
  /// context, reads as absent.
  factory fromFirestore(Map<String, Object?> data) => CoachChat(
    id: data[CoachChatKeys.id]! as String,
    title: data[CoachChatKeys.title]! as String,
    createdAt: data[CoachChatKeys.createdAt]! as DateTime,
    updatedAt: data[CoachChatKeys.updatedAt]! as DateTime,
    contextKind: data[CoachChatKeys.contextKind] as String?,
    day: data[CoachChatKeys.day] as String?,
    messages: [
      for (final message in data[CoachChatKeys.messages]! as List<Object?>)
        CoachMessage.fromFirestore(message! as Map<String, Object?>),
    ],
  );

  /// The Firestore-shaped map Swift writes: a null `context_kind` is left
  /// out.
  Map<String, Object?> toFirestore() => {
    CoachChatKeys.id: id,
    CoachChatKeys.title: title,
    CoachChatKeys.createdAt: createdAt,
    CoachChatKeys.updatedAt: updatedAt,
    CoachChatKeys.contextKind: ?contextKind,
    CoachChatKeys.messages: [
      for (final message in messages) message.toFirestore(),
    ],
    CoachChatKeys.day: ?day,
  };
}
