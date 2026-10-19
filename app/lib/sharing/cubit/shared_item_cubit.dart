import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// What failed, for the message that says so.
enum SharedItemNotice {
  /// `Unable to Add to Library`.
  addFailed,

  /// `Unable to Decline`.
  declineFailed,
}

final class const SharedItemState({
  /// The share, once read.
  final ShareModel? share,

  /// It could not be read.
  final bool notFound = false,

  /// How the recipient has answered, as far as this screen knows.
  final ShareStatus status = ShareStatus.pending,

  /// An answer is being saved.
  final bool isWorking = false,

  /// An answer was just saved here, so the screen closes.
  final bool answered = false,
  final SharedItemNotice? notice,

  /// Bumped with each [notice].
  final int noticeId = 0,
}) extends Equatable {
  bool get isAnswered => status != ShareStatus.pending;

  /// A template shows as itself; a mesocycle as its days.
  List<WorkoutTemplateModel> get templates => switch (share?.payload) {
    TemplateSharePayload(:final template) => [template],
    MesocycleSharePayload(:final mesocycle) => mesocycle.workoutTemplates,
    null => const [],
  };

  SharedItemState copyWith({
    ShareModel? share,
    bool? notFound,
    ShareStatus? status,
    bool? isWorking,
    bool? answered,
    SharedItemNotice? notice,
  }) => SharedItemState(
    share: share ?? this.share,
    notFound: notFound ?? this.notFound,
    status: status ?? this.status,
    isWorking: isWorking ?? this.isWorking,
    answered: answered ?? this.answered,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
  );

  @override
  List<Object?> get props => [
    share?.id,
    notFound,
    status,
    isWorking,
    answered,
    notice,
    noticeId,
  ];
}

/// A shared template or mesocycle, read-only, with Add to Library and
/// Decline (`SharedItemPresenter`).
class SharedItemCubit extends Cubit<SharedItemState> {
  new({
    required this._social,
    required this._library,
    required this._programs,
    required this._analytics,
    required this._uid,
    required this._shareId,
    ShareModel? share,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? newDocumentId,
       super(
         SharedItemState(
           share: share,
           status: share?.status ?? ShareStatus.pending,
         ),
       );

  final SocialRepository _social;
  final TrainingLibraryRepository _library;
  final ProgramRepository _programs;
  final AnalyticsRepository _analytics;
  final String _uid;
  final String _shareId;
  final DateTime Function() _now;
  final String Function() _newId;

  Map<String, Object?> get _kind => {'kind': state.share?.payload.kind};

  /// Reads the share when it was opened by id, then tracks the screen.
  Future<void> load() async {
    if (state.share == null) {
      ShareModel? share;
      try {
        share = await _social.share(_shareId);
      } on Object catch (_) {
        share = null;
      }
      if (share == null) {
        emit(state.copyWith(notFound: true));
        return;
      }
      emit(state.copyWith(share: share, status: share.status));
    }
    _analytics.trackScreenView(
      AnalyticsEvent('SharedItemView_Appear', parameters: _kind),
    );
  }

  void disappeared() => _analytics.trackEvent(
    AnalyticsEvent('SharedItemView_Disappear', parameters: _kind),
  );

  /// Custom exercises first, so the copy never points at an exercise the
  /// recipient does not have; the share is marked accepted last, so a
  /// failure part-way leaves it pending to try again.
  Future<void> addToLibraryPressed() async {
    final share = state.share;
    if (share == null || state.isWorking) return;
    emit(state.copyWith(isWorking: true));
    _analytics.trackEvent(
      AnalyticsEvent('SharedItemView_Accept_Start', parameters: _kind),
    );
    try {
      final library = await _library.watchUserExercises(_uid).first;
      final copy = copySharedItem(
        share.payload,
        recipientId: _uid,
        libraryExerciseIds: [for (final exercise in library) exercise.id],
        now: _now(),
        newId: _newId,
      );
      for (final exercise in copy.newExercises) {
        await _library.saveUserExercise(exercise);
      }
      switch (copy.payload) {
        case TemplateSharePayload(:final template):
          await _library.saveWorkoutTemplate(template);
        case MesocycleSharePayload(:final mesocycle):
          await _programs.saveMesocycle(mesocycle);
      }
      await _social.answerShare(share.id, ShareStatus.accepted);
      _analytics.trackEvent(
        AnalyticsEvent('SharedItemView_Accept_Success', parameters: _kind),
      );
      emit(
        state.copyWith(
          status: ShareStatus.accepted,
          isWorking: false,
          answered: true,
        ),
      );
    } on Object catch (error) {
      _fail(error, SharedItemNotice.addFailed);
    }
  }

  /// Declines: marks the share dismissed and saves nothing.
  Future<void> declinePressed() async {
    final share = state.share;
    if (share == null || state.isWorking) return;
    emit(state.copyWith(isWorking: true));
    _analytics.trackEvent(const AnalyticsEvent('SharedItemView_Dismiss_Start'));
    try {
      await _social.answerShare(share.id, ShareStatus.dismissed);
      _analytics.trackEvent(
        const AnalyticsEvent('SharedItemView_Dismiss_Success'),
      );
      emit(
        state.copyWith(
          status: ShareStatus.dismissed,
          isWorking: false,
          answered: true,
        ),
      );
    } on Object catch (error) {
      _fail(error, SharedItemNotice.declineFailed);
    }
  }

  void _fail(Object error, SharedItemNotice notice) {
    _analytics.trackEvent(
      AnalyticsEvent(
        'SharedItemView_Answer_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.severe,
      ),
    );
    emit(state.copyWith(isWorking: false, notice: notice));
  }
}
