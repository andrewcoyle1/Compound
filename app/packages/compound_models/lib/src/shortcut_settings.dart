/// Field names of `users/{uid}/shortcut_settings/shortcut_settings`, exactly
/// as the Swift `CodingKeys` spell them.
abstract final class ShortcutSettingsKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `quick_action_ids`.
  static const quickActionIds = 'quick_action_ids';

  /// Every field, in declaration order.
  static const List<String> all = [id, authorId, quickActionIds];
}

/// The Search tab's quick actions, in order (Swift `ShortcutSettings`), one
/// document per user.
class const ShortcutSettings({
  /// The owner.
  required final String authorId,

  /// The document id, always `shortcut_settings`.
  final String id = 'shortcut_settings',

  /// Swift `QuickAction` raw values in the user's order, or null for the
  /// default set. Kept as strings: Swift drops an id it does not know when it
  /// reads the list, never when it stores it.
  final List<String>? quickActionIds,
}) {
  /// Creates a [ShortcutSettings].
  this;

  /// Decodes as Swift's synthesized decoder does: `id` and `author_id` are
  /// required; a null list reads as absent.
  factory fromFirestore(Map<String, Object?> data) => ShortcutSettings(
    id: data[ShortcutSettingsKeys.id]! as String,
    authorId: data[ShortcutSettingsKeys.authorId]! as String,
    quickActionIds: data[ShortcutSettingsKeys.quickActionIds] == null
        ? null
        : List<String>.from(
            data[ShortcutSettingsKeys.quickActionIds]! as List<Object?>,
          ),
  );

  /// The Firestore-shaped map Swift writes: a null list is left out.
  Map<String, Object?> toFirestore() => {
    ShortcutSettingsKeys.id: id,
    ShortcutSettingsKeys.authorId: authorId,
    ShortcutSettingsKeys.quickActionIds: ?quickActionIds,
  };
}
