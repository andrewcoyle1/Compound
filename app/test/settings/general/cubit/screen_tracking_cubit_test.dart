import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/settings/general/cubit/screen_tracking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../recorded_analytics.dart';

void main() {
  test('tracks the screen under its Swift name', () {
    final analytics = RecordedAnalytics();
    ScreenTrackingCubit(analytics: analytics, screen: 'LegalView')
      ..appeared()
      ..pressed('Document_Press', {'document': 'privacyPolicy'})
      ..disappeared();
    expect(analytics.screenViews, ['LegalView_Appear']);
    expect(analytics.events, [
      [
        'LegalView_Document_Press',
        {'document': 'privacyPolicy'},
        LogType.analytic,
      ],
      ['LegalView_Disappear', null, LogType.analytic],
    ]);
  });
}
