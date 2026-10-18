import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/social/logic/restartable.dart';
import 'package:compound_models/compound_models.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// What the field says about the handle typed (`EditUsernamePresenter`).
enum UsernameStatus {
  /// Nothing typed.
  idle,

  /// The handle the user already has.
  current,

  /// Not a valid handle: [EditUsernameState.validation] says why.
  invalid,

  /// Asking whether it is free.
  checking,
  available,
  taken,

  /// The availability read failed, so nothing is known either way.
  failed,
}

final class const EditUsernameState({
  final String text = '',
  final UsernameStatus status = UsernameStatus.idle,
  final UsernameValidation validation = UsernameValidation.valid,
  final bool isSaving = false,
  final bool saved = false,
  final int failureId = 0,
}) extends Equatable {
  bool get canSave => status == UsernameStatus.available && !isSaving;

  EditUsernameState copyWith({
    String? text,
    UsernameStatus? status,
    UsernameValidation? validation,
    bool? isSaving,
    bool? saved,
    int? failureId,
  }) => EditUsernameState(
    text: text ?? this.text,
    status: status ?? this.status,
    validation: validation ?? this.validation,
    isSaving: isSaving ?? this.isSaving,
    saved: saved ?? this.saved,
    failureId: failureId ?? this.failureId,
  );

  @override
  List<Object> get props => [
    text,
    status,
    validation,
    isSaving,
    saved,
    failureId,
  ];
}

sealed class EditUsernameEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The field changed to [text]; [viewer] is who is typing.
final class const EditUsernameTextChanged(
  final String text,
  final UserModel viewer,
) extends EditUsernameEvent {
  @override
  List<Object?> get props => [text, viewer];
}

/// Save, as [viewer].
final class const EditUsernameSavePressed(final UserModel viewer)
    extends EditUsernameEvent {
  @override
  List<Object?> get props => [viewer];
}

/// Choosing a handle (`EditUsernamePresenter`): validated as typed, checked
/// for availability once typing pauses, and claimed on Save.
class EditUsernameBloc extends Bloc<EditUsernameEvent, EditUsernameState> {
  new({
    required this._social,
    required this._analytics,
    required this._connectivity,
    required String? current,
    this._debounce = const Duration(milliseconds: 300),
  }) : super(
         EditUsernameState(
           text: current ?? '',
           status: current == null
               ? UsernameStatus.idle
               : UsernameStatus.current,
         ),
       ) {
    on<EditUsernameTextChanged>(_onTextChanged, transformer: restartable());
    on<EditUsernameSavePressed>(_onSavePressed);
  }

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final Duration _debounce;

  /// Claiming waits for the server, so Save does not start offline.
  final ConnectivityRepository _connectivity;

  void appeared() => _analytics.trackScreenView(
    const AnalyticsEvent('EditUsernameView_Appear'),
  );

  void disappeared() =>
      _analytics.trackEvent(const AnalyticsEvent('EditUsernameView_Disappear'));

  Future<void> _onTextChanged(
    EditUsernameTextChanged event,
    Emitter<EditUsernameState> emit,
  ) async {
    // Stored lower case, so the field shows what will be stored.
    final handle = Username.normalised(event.text);
    final base = state.copyWith(text: handle);
    if (handle.isEmpty) {
      return emit(base.copyWith(status: UsernameStatus.idle));
    }
    if (handle == event.viewer.username) {
      return emit(base.copyWith(status: UsernameStatus.current));
    }
    final validation = Username.validate(handle);
    if (validation != UsernameValidation.valid) {
      return emit(
        base.copyWith(status: UsernameStatus.invalid, validation: validation),
      );
    }
    emit(base.copyWith(status: UsernameStatus.checking));
    await Future<void>.delayed(_debounce);
    if (emit.isDone) return;
    try {
      final available = await _social.isUsernameAvailable(
        handle,
        viewer: event.viewer,
      );
      emit(
        state.copyWith(
          status: available ? UsernameStatus.available : UsernameStatus.taken,
        ),
      );
    } on Object catch (error) {
      // A check cancelled by more typing is not a failure.
      if (emit.isDone) return;
      _analytics.trackEvent(
        AnalyticsEvent(
          'EditUsernameView_CheckAvailability_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.warning,
        ),
      );
      emit(state.copyWith(status: UsernameStatus.failed));
    }
  }

  Future<void> _onSavePressed(
    EditUsernameSavePressed event,
    Emitter<EditUsernameState> emit,
  ) async {
    if (!state.canSave || !_connectivity.ensureOnline()) return;
    emit(state.copyWith(isSaving: true));
    _analytics.trackEvent(const AnalyticsEvent('EditUsernameView_Save_Start'));
    void failed(Object error) => _analytics.trackEvent(
      AnalyticsEvent(
        'EditUsernameView_Save_Fail',
        parameters: {'error_description': '$error'},
        type: LogType.severe,
      ),
    );
    try {
      await _social.claimUsername(state.text, viewer: event.viewer);
      _analytics.trackEvent(
        const AnalyticsEvent('EditUsernameView_Save_Success'),
      );
      emit(state.copyWith(isSaving: false, saved: true));
    } on UsernameException catch (error) {
      // Someone reserved it between the check and the save.
      failed(error);
      emit(state.copyWith(isSaving: false, status: UsernameStatus.taken));
    } on Object catch (error) {
      failed(error);
      emit(state.copyWith(isSaving: false, failureId: state.failureId + 1));
    }
  }
}
