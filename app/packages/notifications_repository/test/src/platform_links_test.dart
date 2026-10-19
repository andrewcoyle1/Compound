import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';

class _MockAppLinks extends Mock implements AppLinks;

void main() {
  group(AppLinksPlatformLinks, () {
    test("is app_links' link stream", () {
      final appLinks = _MockAppLinks();
      final stream = Stream<Uri>.value(Uri.parse('compound://workout'));
      when(() => appLinks.uriLinkStream).thenAnswer((_) => stream);
      expect(AppLinksPlatformLinks(appLinks).links, stream);
    });

    test('defaults to the shared AppLinks', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(AppLinksPlatformLinks().links, isA<Stream<Uri>>());
    });
  });

  group(FakePlatformLinks, () {
    test('plays opened links', () async {
      final links = FakePlatformLinks();
      final opened = <Uri>[];
      final subscription = links.links.listen(opened.add);
      links.open(Uri.parse('compound://tab/social'));
      expect(opened, [Uri.parse('compound://tab/social')]);
      await subscription.cancel();
    });
  });
}
