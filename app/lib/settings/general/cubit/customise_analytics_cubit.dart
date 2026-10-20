import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/progress/logic/progress_overview.dart';
import 'package:equatable/equatable.dart';

/// The Customize Analytics screen: the stored settings, and whether the
/// last save failed to start.
class const CustomiseAnalyticsState({
  required final AnalyticsSettings settings,
  final bool saveFailed = false,
}) extends Equatable {
  /// Whether [section] shows on the Progress tab.
  bool isVisible(ProgressSection section) => section.isVisible(settings);

  /// Every section but the last visible one can be switched; a hidden one
  /// always can, since that is how it comes back.
  bool canHide(ProgressSection section) =>
      !isVisible(section) || ProgressSection.values.where(isVisible).length > 1;

  /// How many sections are hidden.
  int get hiddenCount =>
      ProgressSection.values.where((section) => !isVisible(section)).length;

  @override
  List<Object> get props => [settings.toFirestore(), saveFailed];
}

/// Which Progress sections show (Swift `CustomiseAnalyticsPresenter`).
/// Stored as the hidden set, so a section added later shows for everyone.
/// Each change writes only the hidden sections, so a step goal set on
/// another device is never rewritten from the copy last read (Swift saves
/// the whole document).
class CustomiseAnalyticsCubit extends Cubit<CustomiseAnalyticsState> {
  new({required this._body, required this._analytics, required String uid})
    : super(
        CustomiseAnalyticsState(settings: AnalyticsSettings(authorId: uid)),
      ) {
    _subscription = _body
        .watchAnalyticsSettings(uid)
        .listen(
          (settings) => emit(CustomiseAnalyticsState(settings: settings)),
        );
  }

  final BodyRepository _body;
  final AnalyticsRepository _analytics;
  late final StreamSubscription<AnalyticsSettings> _subscription;

  /// `CustomiseAnalyticsView_Appear`.
  void appeared() => _analytics.appear('CustomiseAnalyticsView');

  /// `CustomiseAnalyticsView_Disappear`.
  void disappeared() => _analytics.disappear('CustomiseAnalyticsView');

  /// Shows or hides [section]; hiding it twice records it once.
  Future<void> visibilityChanged(
    ProgressSection section, {
    required bool isVisible,
  }) {
    _analytics.analytic('CustomiseAnalyticsView_SectionVisibility_Changed', {
      'section': section.id,
      'is_visible': isVisible,
    });
    final hidden = [...state.settings.hiddenSectionIds];
    if (isVisible) {
      hidden.removeWhere((id) => id == section.id);
    } else if (!hidden.contains(section.id)) {
      hidden.add(section.id);
    }
    return _save(hidden);
  }

  /// Brings every section back in one save.
  Future<void> showAllPressed() {
    _analytics.analytic('CustomiseAnalyticsView_ShowAll_Press');
    final known = {for (final section in ProgressSection.values) section.id};
    // A hidden id this build doesn't know is left as it is.
    return _save([
      for (final id in state.settings.hiddenSectionIds)
        if (!known.contains(id)) id,
    ]);
  }

  Future<void> _save(List<String> hidden) async {
    final current = state.settings;
    final settings = AnalyticsSettings(
      authorId: current.authorId,
      id: current.id,
      hiddenSectionIds: hidden,
      dailyStepGoal: current.dailyStepGoal,
    );
    emit(CustomiseAnalyticsState(settings: settings));
    _analytics.analytic('CustomiseAnalyticsView_Save_Start');
    try {
      await _body.saveHiddenSections(current.authorId, hidden);
      _analytics.analytic('CustomiseAnalyticsView_Save_Success');
    } on Object catch (error) {
      _analytics.severe('CustomiseAnalyticsView_Save_Fail', error);
      if (!isClosed) {
        emit(
          CustomiseAnalyticsState(settings: state.settings, saveFailed: true),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
