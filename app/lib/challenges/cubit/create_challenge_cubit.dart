import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// Why Create is disabled, shown under the form
/// (`CreateChallengePresenter.validationMessage`).
enum ChallengeValidation {
  /// "Give the challenge a name."
  noName,

  /// "Keep the name under 60 characters."
  nameTooLong,

  /// "Pick a target between 1 and 100 sessions."
  targetOutOfRange,

  /// "Pick a duration."
  noDuration,

  /// "Invite at least one person."
  noMembers,
}

/// Where creating is.
enum CreateChallengeStatus { editing, saving, created, failed }

final class const CreateChallengeState({
  /// Mutuals the viewer has not blocked, in the order they follow them.
  required final List<UserModel> candidates,
  final String title = '',
  final int targetSessions = 8,
  final int durationDays = 14,
  final Set<String> selectedIds = const {},

  /// The member ticked for the user when there was only one to pick; null
  /// until the screen first appears.
  final Set<String>? preselectedIds,
  final CreateChallengeStatus status = CreateChallengeStatus.editing,

  /// The challenge made, once [status] is created.
  final ChallengeModel? created,

  /// Bumped with each failure, so two in a row are both shown.
  final int failureId = 0,
}) extends Equatable {
  String get _trimmedTitle => title.trim();

  /// Selected ids still offered, in the candidates' order.
  List<String> get selectedMemberIds => [
    for (final user in candidates)
      if (selectedIds.contains(user.userId)) user.userId,
  ];

  /// Why Create is disabled; null when it is ready.
  ChallengeValidation? get validation {
    if (_trimmedTitle.isEmpty) return ChallengeValidation.noName;
    if (_trimmedTitle.runes.length > challengeTitleMaxLength) {
      return ChallengeValidation.nameTooLong;
    }
    if (targetSessions < challengeTargetMin ||
        targetSessions > challengeTargetMax) {
      return ChallengeValidation.targetOutOfRange;
    }
    if (!challengeDurations.contains(durationDays)) {
      return ChallengeValidation.noDuration;
    }
    if (selectedMemberIds.isEmpty) return ChallengeValidation.noMembers;
    return null;
  }

  bool get canCreate =>
      validation == null && status != CreateChallengeStatus.saving;

  /// Anything entered that closing would throw away; the member ticked for
  /// the user is not.
  bool get hasUnsavedChanges =>
      _trimmedTitle.isNotEmpty ||
      selectedIds.difference(preselectedIds ?? const {}).isNotEmpty;

  CreateChallengeState copyWith({
    String? title,
    int? targetSessions,
    int? durationDays,
    Set<String>? selectedIds,
    Set<String>? preselectedIds,
    CreateChallengeStatus? status,
    ChallengeModel? created,
    int? failureId,
  }) => CreateChallengeState(
    candidates: candidates,
    title: title ?? this.title,
    targetSessions: targetSessions ?? this.targetSessions,
    durationDays: durationDays ?? this.durationDays,
    selectedIds: selectedIds ?? this.selectedIds,
    preselectedIds: preselectedIds ?? this.preselectedIds,
    status: status ?? this.status,
    created: created ?? this.created,
    failureId: failureId ?? this.failureId,
  );

  @override
  List<Object?> get props => [
    candidates,
    title,
    targetSessions,
    durationDays,
    selectedIds,
    preselectedIds,
    status,
    created,
    failureId,
  ];
}

/// New Challenge (`CreateChallengePresenter`): a name, a target, a length
/// and the mutuals to invite. The owner is always a member.
class CreateChallengeCubit extends Cubit<CreateChallengeState> {
  new({
    required this._social,
    required this._analytics,
    required this._viewer,
    required List<UserModel> following,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? newDocumentId,
       super(CreateChallengeState(candidates: mutualsOf(_viewer, following)));

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final UserModel _viewer;
  final DateTime Function() _now;
  final String Function() _newId;

  /// With exactly one person to invite there is no choice to make, so it is
  /// made, once, so a later appear cannot re-tick someone unticked.
  void appeared() {
    _analytics.trackScreenView(
      const AnalyticsEvent('CreateChallengeView_Appear'),
    );
    if (state.preselectedIds != null) return;
    final ids = [for (final user in state.candidates) user.userId];
    final preselected = ids.length == 1 && state.selectedIds.isEmpty
        ? ids.toSet()
        : <String>{};
    emit(
      state.copyWith(
        preselectedIds: preselected,
        selectedIds: {...state.selectedIds, ...preselected},
      ),
    );
  }

  void disappeared() => _analytics.trackEvent(
    const AnalyticsEvent('CreateChallengeView_Disappear'),
  );

  void titleChanged(String title) => emit(state.copyWith(title: title));

  void targetChanged(int target) =>
      emit(state.copyWith(targetSessions: target));

  void durationChanged(int days) => emit(state.copyWith(durationDays: days));

  /// Ticks or unticks [userId].
  void candidatePressed(String userId) {
    final selected = {...state.selectedIds};
    if (!selected.remove(userId)) selected.add(userId);
    emit(state.copyWith(selectedIds: selected));
  }

  /// Starts now and runs [CreateChallengeState.durationDays] whole days.
  Future<void> createPressed() async {
    if (!state.canCreate) return;
    final memberIds = state.selectedMemberIds;
    emit(state.copyWith(status: CreateChallengeStatus.saving));
    _analytics.trackEvent(
      AnalyticsEvent(
        'CreateChallengeView_Create_Start',
        parameters: {
          'target_sessions': state.targetSessions,
          'duration_days': state.durationDays,
          'member_count': memberIds.length,
        },
      ),
    );
    final start = _now();
    final challenge = ChallengeModel(
      id: _newId(),
      ownerId: _viewer.userId,
      title: state.title.trim(),
      targetSessions: state.targetSessions,
      startsAt: start,
      endsAt: DateTime(
        start.year,
        start.month,
        start.day + state.durationDays,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
      ),
      memberIds: [
        _viewer.userId,
        for (final id in memberIds)
          if (id != _viewer.userId) id,
      ],
      dateCreated: start,
    );
    try {
      await _social.createChallenge(challenge);
      _analytics.trackEvent(
        const AnalyticsEvent('CreateChallengeView_Create_Success'),
      );
      emit(
        state.copyWith(
          status: CreateChallengeStatus.created,
          created: challenge,
        ),
      );
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'CreateChallengeView_Create_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          status: CreateChallengeStatus.failed,
          failureId: state.failureId + 1,
        ),
      );
    }
  }
}
