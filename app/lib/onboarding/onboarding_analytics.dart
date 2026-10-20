import 'package:analytics_repository/analytics_repository.dart';

/// The analytics calls every onboarding screen makes, with the Swift
/// presenters' event names.
extension OnboardingAnalytics on AnalyticsRepository {
  /// `<screen>_Appear`, as a screen view.
  void appear(String screen, [Map<String, Object?>? parameters]) =>
      trackScreenView(
        AnalyticsEvent('${screen}_Appear', parameters: parameters),
      );

  /// `<screen>_Disappear`.
  void disappear(String screen, [Map<String, Object?>? parameters]) =>
      trackEvent(AnalyticsEvent('${screen}_Disappear', parameters: parameters));

  /// An info event, as Swift's `navigate` cases log.
  void info(String name, [Map<String, Object?>? parameters]) => trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: LogType.info),
  );

  /// An analytic event.
  void analytic(String name, [Map<String, Object?>? parameters]) =>
      trackEvent(AnalyticsEvent(name, parameters: parameters));

  /// A severe failure, with the error described as the other blocs do.
  void severe(String name, Object error, [Map<String, Object?>? parameters]) =>
      trackEvent(
        AnalyticsEvent(
          name,
          parameters: {...?parameters, 'error_description': '$error'},
          type: LogType.severe,
        ),
      );
}

/// `["is_onboarding": true]`, which the goal and diet screens log on appear
/// and disappear: they're also opened from Settings in the Swift app.
const onboardingParameters = {'is_onboarding': true};
