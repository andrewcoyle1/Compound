import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// A settings document as a screen sees it.
class const SettingsDocumentState<T>({
  /// The document, or null until the first read.
  final T? settings,

  /// How many saves have failed on this screen; each one says so.
  final int saveFailures = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [settings, saveFailures];
}

/// A settings document edited in place, with no Save button: every change
/// writes the whole document, as the Swift presenters do.
///
/// The document is followed live, and each change is made to the latest
/// copy, so a change made on another screen, or the favourites the
/// nutrition tab writes, is carried rather than undone (Swift re-reads on
/// every appear for the same reason). Analytics use `screen`, the Swift
/// view's name: `<screen>_Appear`, `_Disappear`, `_Save_Start`,
/// `_Save_Success` and `_Save_Fail`.
class SettingsDocumentCubit<T> extends Cubit<SettingsDocumentState<T>> {
  new({
    required Stream<T> document,
    required this._save,
    required this._decode,
    required this._encode,
    required this._analytics,
    required this._screen,
  }) : super(SettingsDocumentState<T>()) {
    _analytics.appear(_screen);
    _subscription = document.listen(
      (settings) => emit(
        SettingsDocumentState(
          settings: settings,
          saveFailures: state.saveFailures,
        ),
      ),
      // Left as it was: the repositories fall back to defaults themselves.
      onError: (Object _) {},
    );
  }

  final Future<void> Function(T settings) _save;
  final T Function(Map<String, Object?> data) _decode;
  final Map<String, Object?> Function(T settings) _encode;
  final AnalyticsRepository _analytics;
  final String _screen;
  late final StreamSubscription<T> _subscription;

  /// Sets the field stored as [key] to [value] and saves the document. An
  /// enum is stored as its raw value; null removes an optional field.
  /// Does nothing before the first read.
  Future<void> set(String key, Object? value) => update((data) {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value is FirestoreEnum ? value.value : value;
    }
  });

  /// Changes the latest document's fields with [change] and saves it.
  Future<void> update(void Function(Map<String, Object?> data) change) async {
    final current = state.settings;
    if (current == null) return;
    final data = {..._encode(current)};
    change(data);
    final next = _decode(data);
    emit(
      SettingsDocumentState(settings: next, saveFailures: state.saveFailures),
    );
    _analytics.analytic('${_screen}_Save_Start');
    try {
      await _save(next);
      _analytics.analytic('${_screen}_Save_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_Save_Fail', error);
      emit(
        SettingsDocumentState(
          settings: state.settings,
          saveFailures: state.saveFailures + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _analytics.disappear(_screen);
    await _subscription.cancel();
    await super.close();
  }
}
