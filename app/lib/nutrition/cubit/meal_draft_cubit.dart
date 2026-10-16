import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart'
    show firestoreToTaggedJson, taggedJsonToFirestore;
import 'package:device_store/device_store.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The meal being built but not yet logged (Swift `MealLogManager
/// .draftMeal`), so closing the logger keeps the plate and Nutrition can
/// offer it again (`MealAccessoryPresenter`). Null when there is none.
///
/// Kept on the device per account (Swift keeps one on disk for the
/// device, so it outlives a sign-out), as the meal's Firestore fields with
/// dates tagged.
class MealDraftCubit extends Cubit<MealLogModel?> {
  /// Keeps the draft in [store]; in memory when left out.
  new({DeviceStore? store})
    : _store = store ?? InMemoryDeviceStore(),
      super(null);

  final DeviceStore _store;
  String? _uid;

  /// The key [uid]'s draft is kept under.
  static String key(String uid) => 'draft_meal_log_$uid';

  /// Shows [uid]'s draft, if one was kept; none when signed out.
  void userChanged(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    emit(uid == null ? null : _read(uid));
  }

  /// Keeps [meal] as the draft; an empty plate is no draft, so it clears.
  void keep(MealLogModel meal) {
    if (meal.items.isEmpty) return clear();
    final uid = _uid;
    if (uid != null) {
      _store.setString(
        key(uid),
        jsonEncode(firestoreToTaggedJson(meal.toFirestore())),
      );
    }
    emit(meal);
  }

  /// Forgets the draft: it was logged or discarded.
  void clear() {
    final uid = _uid;
    if (uid != null) _store.remove(key(uid));
    emit(null);
  }

  MealLogModel? _read(String uid) {
    final json = _store.getString(key(uid));
    if (json == null) return null;
    try {
      return MealLogModel.fromFirestore(
        taggedJsonToFirestore(jsonDecode(json) as Map<String, Object?>),
      );
    } on Object {
      // A draft this build cannot read is only a plate to fill again.
      return null;
    }
  }
}
