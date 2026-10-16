import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';

/// The analytics of a screen that holds nothing else (Methods & Sources,
/// Legal, About, Licences), under its Swift name: `<screen>_Appear`,
/// `<screen>_Disappear` and its presses.
class ScreenTrackingCubit extends Cubit<void> {
  new({required this._analytics, required this._screen}) : super(null);

  final AnalyticsRepository _analytics;
  final String _screen;

  /// `<screen>_Appear`, as a screen view.
  void appeared() => _analytics.appear(_screen);

  /// `<screen>_Disappear`.
  void disappeared() => _analytics.disappear(_screen);

  /// `<screen>_<action>`, an analytic event.
  void pressed(String action, [Map<String, Object?>? parameters]) =>
      _analytics.analytic('${_screen}_$action', parameters);
}
