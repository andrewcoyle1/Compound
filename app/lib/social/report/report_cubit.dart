import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// What a report names: the kind of thing, which one, and who made it
/// (Swift `ReportedContent`).
final class const ReportedContent({
  required final ReportContentType type,
  required final String id,
  final String? authorId,
}) extends Equatable {
  @override
  List<Object?> get props => [type, id, authorId];
}

/// Why a report cannot be sent yet.
enum ReportProblem { noReason, noNote, noteTooLong }

final class const ReportState({
  final ReportReason? reason,
  final String note = '',
  final ReportProblem? problem,
}) extends Equatable {
  @override
  List<Object?> get props => [reason, note, problem];
}

/// The one report flow, shared by comments, feed cards and profiles
/// (Swift `ReportFlow` over `ReportManager`): pick a reason, add a note
/// ("Other" needs one), send.
class ReportCubit extends Cubit<ReportState> {
  new({
    required this._social,
    required this._analytics,
    required this._content,
    required this._reporterId,
  }) : super(const ReportState());

  /// The longest note the rules accept. `firestore.rules` counts UTF-16
  /// code units, as [String.length] does, not characters as Swift does.
  static const noteLimit = 500;

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final ReportedContent _content;
  final String? _reporterId;

  /// Why [note] with [reason] cannot be sent, or null when it can
  /// (`ReportFlow.validationMessage`).
  static ReportProblem? problem(ReportReason? reason, String note) {
    if (reason == null) return ReportProblem.noReason;
    final trimmed = note.trim();
    if (reason == ReportReason.other && trimmed.isEmpty) {
      return ReportProblem.noNote;
    }
    if (trimmed.length > noteLimit) return ReportProblem.noteTooLong;
    return null;
  }

  void reasonSelected(ReportReason reason) =>
      emit(ReportState(reason: reason, note: state.note));

  void noteChanged(String note) => emit(
    ReportState(reason: state.reason, note: note, problem: state.problem),
  );

  /// Sends the report, or says in the sheet why it cannot (null). The
  /// future completes with whether it went, so the sheet can close at once.
  Future<bool>? sendPressed() {
    final reason = state.reason;
    final problem = ReportCubit.problem(reason, state.note);
    if (problem != null || reason == null) {
      emit(ReportState(reason: reason, note: state.note, problem: problem));
      return null;
    }
    final note = state.note.trim();
    return _send(reason, note.isEmpty ? null : note);
  }

  Future<bool> _send(ReportReason reason, String? note) async {
    final type = _content.type.value;
    final flow = {'content_type': type, 'reason': reason.value};
    _event('ReportFlow_Report_Start', flow);
    try {
      final reporterId = _reporterId;
      if (reporterId == null) throw StateError('No signed-in user');
      _event('Report_Submit_Start', {
        'content_type': type,
        'content_id': _content.id,
        'reason': reason.value,
      });
      await _social.report(
        reporterId: reporterId,
        targetType: _content.type,
        targetId: _content.id,
        targetAuthorId: _content.authorId,
        reason: reason,
        note: note,
      );
      _event('Report_Submit_Success', {
        'content_type': type,
        'content_id': _content.id,
      });
      _event('ReportFlow_Report_Success', flow);
      return true;
    } on Object catch (error) {
      _event('ReportFlow_Report_Fail', {
        'error_description': '$error',
      }, LogType.severe);
      return false;
    }
  }

  void _event(
    String name,
    Map<String, Object?> parameters, [
    LogType type = LogType.analytic,
  ]) => _analytics.trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: type),
  );
}
