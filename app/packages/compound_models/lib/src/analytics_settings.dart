import 'package:compound_models/src/firestore_values.dart';

/// Field names of `users/{uid}/analytics_settings/analytics_settings`,
/// exactly as the Swift `CodingKeys` spell them.
abstract final class AnalyticsSettingsKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `hidden_section_ids`.
  static const hiddenSectionIds = 'hidden_section_ids';

  /// `daily_step_goal`.
  static const dailyStepGoal = 'daily_step_goal';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    hiddenSectionIds,
    dailyStepGoal,
  ];
}

/// Which Progress sections are hidden, and the daily step goal (Swift
/// `AnalyticsSettings`), one document per user. The defaults are Swift's,
/// which the app uses when the user has no document.
class const AnalyticsSettings({
  /// The owner.
  required final String authorId,

  /// The document id, always `analytics_settings`.
  final String id = 'analytics_settings',

  /// Hidden sections, by Swift `AnalyticsSection` raw value. The hidden set
  /// rather than the visible one, so a new section shows by default.
  final List<String> hiddenSectionIds = const [],

  /// The daily step goal; null reads as [defaultStepGoal].
  final int? dailyStepGoal,
}) {
  /// Creates an [AnalyticsSettings].
  this;

  /// Decodes as Swift's synthesized decoder does: `id` and
  /// `hidden_section_ids` are **required**, their defaults notwithstanding,
  /// so a document missing either throws, as it fails to decode on iOS. A
  /// null `daily_step_goal` reads as absent.
  factory fromFirestore(Map<String, Object?> data) => AnalyticsSettings(
    id: data[AnalyticsSettingsKeys.id]! as String,
    authorId: data[AnalyticsSettingsKeys.authorId]! as String,
    hiddenSectionIds: readStringList(
      data[AnalyticsSettingsKeys.hiddenSectionIds],
    ),
    dailyStepGoal: readOptionalInt(data[AnalyticsSettingsKeys.dailyStepGoal]),
  );

  /// Swift's `TodayChecklist.defaultStepGoal`.
  static const defaultStepGoal = 8000;

  /// The step goal in force: [dailyStepGoal], else [defaultStepGoal].
  int get stepGoal => dailyStepGoal ?? defaultStepGoal;

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    AnalyticsSettingsKeys.id: id,
    AnalyticsSettingsKeys.authorId: authorId,
    AnalyticsSettingsKeys.hiddenSectionIds: hiddenSectionIds,
    AnalyticsSettingsKeys.dailyStepGoal: ?dailyStepGoal,
  };
}
