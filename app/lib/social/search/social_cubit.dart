import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:social_repository/social_repository.dart';

/// The Social tab's own state: people to suggest under an empty feed, and
/// its analytics (`SocialPresenter`).
class SocialCubit extends Cubit<List<UserModel>> {
  new({required this._social, required this._analytics}) : super(const []);

  final SocialRepository _social;
  final AnalyticsRepository _analytics;

  void appeared() =>
      _analytics.trackScreenView(const AnalyticsEvent('SocialView_Appear'));

  void disappeared() =>
      _analytics.trackEvent(const AnalyticsEvent('SocialView_Disappear'));

  /// Tracks a tap: `SocialView_<name>`.
  void pressed(String name) =>
      _analytics.trackEvent(AnalyticsEvent('SocialView_$name'));

  /// People to follow, read once when the feed is empty. Silent: none is
  /// the right fallback.
  Future<void> loadSuggestions(UserModel viewer) async {
    try {
      emit(await _social.suggestedUsers(viewer: viewer));
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'SocialView_LoadSuggestedUsers_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.warning,
        ),
      );
    }
  }
}
