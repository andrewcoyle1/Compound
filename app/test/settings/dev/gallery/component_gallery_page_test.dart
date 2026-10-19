import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:compound/settings/dev/dev_settings_page.dart';
import 'package:compound/settings/dev/gallery/component_gallery_page.dart';
import 'package:compound/settings/dev/gallery/gallery_tokens.dart';
import 'package:compound/settings/settings_routes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/helpers.dart';

/// Every route name in [routes], however deep.
Iterable<String> _names(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute && route.name != null) yield route.name!;
    yield* _names(route.routes);
  }
}

/// The names [pattern]'s first group matches in [file].
Set<String> _declared(String file, String pattern) => {
  for (final match in RegExp(
    pattern,
    multiLine: true,
  ).allMatches(File(file).readAsStringSync()))
    match.group(1)!,
};

const _appUi = 'packages/app_ui/lib';

void main() {
  group('ComponentGalleryPage', () {
    Future<GoRouter> pumpGallery(
      WidgetTester tester, {
      String location = '/gallery',
    }) async {
      tester.useSize(phoneSize);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SizedBox.shrink(),
            routes: [componentGalleryRoute],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpApp(const SizedBox.shrink(), router: router);
      // Spinners never settle, so pump past the first frames instead.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return router;
    }

    BuildContext inGallery(WidgetTester tester) =>
        tester.element(find.text('AppCtaButton'));

    testWidgets('has an entry for every exported app_ui widget', (
      tester,
    ) async {
      final barrel = File('$_appUi/app_ui.dart').readAsStringSync();
      final files = RegExp(r"export 'src/widgets/(\w+)\.dart'")
          .allMatches(barrel)
          .map((m) => '$_appUi/src/widgets/${m[1]}.dart');
      final public = {
        for (final file in files)
          ..._declared(
            file,
            r'^(?:class|final class) (App\w+)(?:<\w+>)? extends',
          ),
        for (final file in files)
          ..._declared(file, r'^Future<\w+\?> (show\w+)<'),
      };
      final gallery = [
        'lib/settings/dev/gallery/gallery_components.dart',
        'lib/settings/dev/gallery/gallery_tokens.dart',
      ].map((f) => File(f).readAsStringSync()).join();
      final missing = public.where(
        (name) => !RegExp('\\b$name\\b').hasMatch(gallery),
      );
      expect(public, contains('AppCtaButton'));
      expect(missing, isEmpty, reason: 'add these to gallery_components.dart');
    });

    test('lists every AppSymbols icon and AppColors colour', () {
      expect(
        gallerySymbols.map((s) => s.$1).toSet(),
        _declared(
          '$_appUi/src/tokens/app_symbols.dart',
          r'static (?:const IconData|IconData get) (\w+)',
        ),
      );
      expect(
        galleryColors.map((c) => c.$1).toSet(),
        _declared('$_appUi/src/theme/app_colors.dart', r'final Color (\w+);'),
      );
    });

    testWidgets('renders every part in both themes at 100% and 200% text', (
      tester,
    ) async {
      await pumpGallery(tester);
      for (final theme in ['Light', 'Dark']) {
        for (final scale in ['100%', '200%']) {
          await tester.tap(find.text(theme));
          await tester.tap(find.text(scale));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: '$theme, $scale');
          final context = inGallery(tester);
          expect(
            Theme.of(context).brightness,
            theme == 'Dark' ? Brightness.dark : Brightness.light,
          );
          expect(
            MediaQuery.textScalerOf(context).scale(1),
            scale == '200%' ? 2 : 1,
          );
        }
      }
    });

    testWidgets('jumps to a part from the index and from the route', (
      tester,
    ) async {
      await pumpGallery(tester, location: '/gallery?section=overlays');
      expect(find.text('showAppDialog').hitTestable(), findsOneWidget);

      final chip = find.widgetWithText(AppChip, 'Content');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('AppCard: card').hitTestable(), findsOneWidget);
    });

    testWidgets('opens the sample screens, dialogs and sheets', (tester) async {
      final router = await pumpGallery(
        tester,
        location: '/gallery?section=navigation',
      );
      Future<void> open(String row) async {
        await tester.ensureVisible(find.text(row).first);
        await tester.tap(find.text(row).first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      Future<void> back() async {
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      await open('largeTitle, AppDashboard, AppBottomCta');
      expect(find.byType(AppDashboard), findsOneWidget);
      await back();

      await open('AppOnboardingStepScaffold');
      expect(find.byType(AppOnboardingStepScaffold), findsOneWidget);
      await tester.tap(find.text('Start Workout'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AppOnboardingStepScaffold), findsNothing);

      for (final row in [
        'cancel, destructive',
        'standard, preferred',
        'three actions, stacked',
        'content',
        'AppDialog.confirmDestructive',
      ]) {
        await open(row);
        expect(find.byWidgetPredicate((w) => w is AppDialog), findsOneWidget);
        await back();
      }

      for (final size in AppSheetSize.values) {
        await open(size.name);
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        await back();
      }
      final page = find.text('half').last;
      await tester.ensureVisible(page);
      await tester.tap(page);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('plays the motion curves and keeps sample state', (
      tester,
    ) async {
      await pumpGallery(tester, location: '/gallery?section=tokens');
      final play = find.text('Play');
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pump(const Duration(seconds: 2));

      await tester.ensureVisible(find.text('not selected'));
      await tester.tap(find.text('not selected'));
      await tester.pump();
      expect(
        tester
            .widget<AppSelectableRow>(
              find.widgetWithText(AppSelectableRow, 'not selected'),
            )
            .selected,
        isTrue,
      );
    });
  });

  group('developerRoutes', () {
    test('register Developer Settings and the gallery outside production', () {
      for (final flavor in ['development', 'staging']) {
        expect(
          _names(developerRoutes(flavor)),
          containsAll([DevSettingsPage.name, ComponentGalleryPage.name]),
          reason: flavor,
        );
      }
    });

    test('register nothing in production', () {
      expect(developerRoutes('production'), isEmpty);
      expect(DevSettingsPage.availableIn('production'), isFalse);
    });

    test('are where the profile routes get the gallery', () {
      expect(
        _names(profileRoutes).where((n) => n == ComponentGalleryPage.name),
        hasLength(1),
      );
      expect(
        _names(developerRoutes(appFlavor)),
        contains(ComponentGalleryPage.name),
      );
    });
  });
}
