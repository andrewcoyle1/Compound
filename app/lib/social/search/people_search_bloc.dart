import 'package:bloc/bloc.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/logic/restartable.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

final class const PeopleSearchState({
  final String query = '',

  /// Who the server found, less the reader.
  final List<UserModel> remoteUsers = const [],

  /// Only the server half waits; the people followed show at once.
  final bool isLoading = false,

  /// The last server search failed, which is not "no results".
  final bool failed = false,
}) extends Equatable {
  /// Whether anything is typed.
  bool get isSearching => SearchMatch.isSearching(query);

  /// People followed first, then anyone the server found who is not listed
  /// already, each matching the query by first name or handle.
  List<UserModel> results(List<UserModel> following) {
    final followedIds = {for (final user in following) user.userId};
    return [
          ...following,
          for (final user in remoteUsers)
            if (!followedIds.contains(user.userId)) user,
        ]
        .where(
          (user) =>
              SearchMatch.matches(query, [firstNameOf(user), user.username]),
        )
        .toList();
  }

  @override
  List<Object> get props => [query, remoteUsers, isLoading, failed];
}

final class const PeopleSearchQueryChanged(
  final String query,
  final UserModel viewer,
) extends Equatable {
  @override
  List<Object> get props => [query, viewer];
}

/// Social's search field (`PeopleSearch`): a search waits for typing to
/// pause, and a newer query cancels the one before.
class PeopleSearchBloc
    extends Bloc<PeopleSearchQueryChanged, PeopleSearchState> {
  new({
    required this._social,
    this._debounce = const Duration(milliseconds: 350),
  }) : super(const PeopleSearchState()) {
    on<PeopleSearchQueryChanged>(_onQueryChanged, transformer: restartable());
  }

  final SocialRepository _social;
  final Duration _debounce;

  Future<void> _onQueryChanged(
    PeopleSearchQueryChanged event,
    Emitter<PeopleSearchState> emit,
  ) async {
    final query = event.query;
    if (!SearchMatch.isSearching(query)) {
      return emit(PeopleSearchState(query: query));
    }
    // Raised at once, so the spinner shows with the first keystroke.
    emit(
      PeopleSearchState(
        query: query,
        remoteUsers: state.remoteUsers,
        isLoading: true,
      ),
    );
    await Future<void>.delayed(_debounce);
    if (emit.isDone) return;
    try {
      // Not normalised: a leading `@` searches handles only.
      final users = await _social.searchUsers(
        query.trim(),
        viewer: event.viewer,
      );
      emit(
        PeopleSearchState(
          query: query,
          remoteUsers: [
            for (final user in users)
              if (user.userId != event.viewer.userId) user,
          ],
        ),
      );
    } on Object {
      emit(PeopleSearchState(query: query, failed: true));
    }
  }
}
