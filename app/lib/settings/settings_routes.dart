import 'package:compound/gym_profiles/view/gym_profiles_page.dart';
import 'package:compound/integrations/view/integrations_page.dart';
import 'package:compound/settings/account/view/delete_account_page.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound/settings/account/view/save_account_page.dart';
import 'package:compound/settings/dev/dev_settings_page.dart';
import 'package:compound/settings/general/view/about_page.dart';
import 'package:compound/settings/general/view/customise_analytics_page.dart';
import 'package:compound/settings/general/view/legal_page.dart';
import 'package:compound/settings/general/view/licences_page.dart';
import 'package:compound/settings/general/view/methods_and_sources_page.dart';
import 'package:compound/settings/general/view/notification_settings_page.dart';
import 'package:compound/settings/general/view/units_page.dart';
import 'package:compound/settings/nutrition/view/expenditure_settings_page.dart';
import 'package:compound/settings/nutrition/view/favourite_measurements_page.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/logger_banner_page.dart';
import 'package:compound/settings/nutrition/view/logger_food_tiles_page.dart';
import 'package:compound/settings/nutrition/view/strategy_settings_page.dart';
import 'package:compound/settings/nutrition/view/timeline_food_tiles_page.dart';
import 'package:compound/settings/training/view/rest_timer_settings_page.dart';
import 'package:compound/settings/training/view/smart_progression_settings_page.dart';
import 'package:compound/settings/training/view/timer_duration_page.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:compound/settings/view/settings_page.dart';
import 'package:go_router/go_router.dart';

GoRoute _route(
  String path,
  String name,
  GoRouterWidgetBuilder builder, [
  List<RouteBase> routes = const [],
]) => GoRoute(path: path, name: name, builder: builder, routes: routes);

/// The routes under the profile (`/profile/…`): Edit Profile, and Settings
/// with every screen it opens, pushed as the Swift app pushes them inside
/// the profile's cover. Navigate by name (`context.pushNamed(…Page.name)`).
final profileRoutes = <RouteBase>[
  _route(EditProfilePage.path, EditProfilePage.name, (_, _) {
    return const EditProfilePage();
  }),
  _route(SettingsPage.path, SettingsPage.name, (_, _) => const SettingsPage(), [
    _route(UnitsPage.path, UnitsPage.name, (_, _) => const UnitsPage()),
    _route(IntegrationsPage.path, IntegrationsPage.name, (_, _) {
      return const IntegrationsPage();
    }),
    _route(
      CustomiseAnalyticsPage.path,
      CustomiseAnalyticsPage.name,
      (_, _) => const CustomiseAnalyticsPage(),
    ),
    _route(
      NotificationSettingsPage.path,
      NotificationSettingsPage.name,
      (_, _) => const NotificationSettingsPage(),
    ),
    _route(
      MethodsAndSourcesPage.path,
      MethodsAndSourcesPage.name,
      (_, _) => const MethodsAndSourcesPage(),
    ),
    _route(LegalPage.path, LegalPage.name, (_, _) => const LegalPage()),
    _route(AboutPage.path, AboutPage.name, (_, _) => const AboutPage(), [
      _route(LicencesPage.path, LicencesPage.name, (_, _) {
        return const LicencesPage();
      }),
    ]),
    _route(GymProfilesPage.path, GymProfilesPage.name, (_, _) {
      return const GymProfilesPage();
    }),
    _route(
      WorkoutSettingsPage.path,
      WorkoutSettingsPage.name,
      (_, _) => const WorkoutSettingsPage(),
      [
        _route(
          RestTimerSettingsPage.path,
          RestTimerSettingsPage.name,
          (_, _) => const RestTimerSettingsPage(),
          [
            _route(TimerDurationPage.path, TimerDurationPage.name, (_, _) {
              return const TimerDurationPage();
            }),
          ],
        ),
        _route(
          SmartProgressionSettingsPage.path,
          SmartProgressionSettingsPage.name,
          (_, _) => const SmartProgressionSettingsPage(),
        ),
      ],
    ),
    _route(
      FoodLogSettingsPage.path,
      FoodLogSettingsPage.name,
      (_, _) => const FoodLogSettingsPage(),
      [
        _route(LoggerBannerPage.path, LoggerBannerPage.name, (_, _) {
          return const LoggerBannerPage();
        }),
        _route(LoggerFoodTilesPage.path, LoggerFoodTilesPage.name, (_, _) {
          return const LoggerFoodTilesPage();
        }),
        _route(TimelineFoodTilesPage.path, TimelineFoodTilesPage.name, (_, _) {
          return const TimelineFoodTilesPage();
        }),
        _route(
          FavouriteMeasurementsPage.path,
          FavouriteMeasurementsPage.name,
          (_, _) => const FavouriteMeasurementsPage(),
        ),
      ],
    ),
    _route(
      StrategySettingsPage.path,
      StrategySettingsPage.name,
      (_, _) => const StrategySettingsPage(),
    ),
    _route(
      ExpenditureSettingsPage.path,
      ExpenditureSettingsPage.name,
      (_, _) => const ExpenditureSettingsPage(),
    ),
    _route(DeleteAccountPage.path, DeleteAccountPage.name, (_, _) {
      return const DeleteAccountPage();
    }),
    _route(SaveAccountPage.path, SaveAccountPage.name, (_, _) {
      return const SaveAccountPage();
    }),
    // Only reachable where Settings shows its row: never in production.
    if (DevSettingsPage.isAvailable)
      _route(DevSettingsPage.path, DevSettingsPage.name, (_, _) {
        return const DevSettingsPage();
      }),
  ]),
];
