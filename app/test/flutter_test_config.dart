import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether this run draws the human-readable goldens: real fonts, on macOS
/// only, into `goldens/macos/`. Off, it draws the CI goldens, which every
/// machine renders alike (ui-contract.md, rule 6).
const humanGoldens = bool.fromEnvironment('HUMAN_GOLDENS');

/// The share of pixels a CI golden may differ by and still pass. Text is
/// drawn as blocks there, but shapes and blurs are anti-aliased by the CPU
/// they run on: an arm64 Mac and the x86 Linux runner differ in a few edge
/// pixels.
const ciDiffThreshold = 0.005;

/// Widget tests time out after 30 seconds instead of Flutter's 10 minutes.
///
/// `testWidgets` passes the binding's default timeout explicitly, so
/// `--timeout` on the command line does not shorten it. A test that awaits
/// something only a pump can complete sits idle until the timeout; with 10
/// minutes per test, a few such tests stalled a whole run for half an hour.
/// The full suite takes about 25 seconds, so 30 per test is generous.
///
/// Golden tests (`helpers/golden.dart`) run as compound_charts' do.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(Duration(seconds: 30));
  }
  if (humanGoldens) await _loadFonts();
  final local = goldenFileComparator;
  if (local is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(local.basedir);
  }
  return await AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      goldenTestTheme: GoldenTestTheme(
        backgroundColor: const Color(0xFF8E8E93),
        borderColor: const Color(0xFF636366),
        nameTextStyle: const TextStyle(fontSize: 14, color: Color(0xFFFFFFFF)),
        padding: const EdgeInsets.all(8),
      ),
      platformGoldensConfig: PlatformGoldensConfig(
        enabled: humanGoldens,
        platforms: {HostPlatform.macOS},
      ),
      // Always on, unless the define asks for the human goldens instead.
      // ignore: avoid_redundant_argument_values, prefer_const_constructors
      ciGoldensConfig: CiGoldensConfig(enabled: !humanGoldens),
    ),
    run: testMain,
  );
}

/// Passes an image that differs from its golden in at most
/// [ciDiffThreshold] of its pixels.
///
/// Alchemist's own `diffThreshold` refuses to run under very_good's test
/// optimiser, which wraps the comparator; this one is the comparator it
/// wraps.
class _TolerantComparator extends LocalFileComparator {
  new(Uri basedir) : super(basedir.resolve('_'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= ciDiffThreshold) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

/// Loads the faces the app draws with, so text and icons are real: Nunito
/// from app_ui, and Material Icons and Roboto from the Flutter SDK.
/// Roboto also stands in for San Francisco, which may not be redistributed.
Future<void> _loadFonts() async {
  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent
          .path;
  final material = '$sdk/bin/cache/artifacts/material_fonts';
  Future<ByteData> file(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final roboto = [
    for (final weight in ['Regular', 'Medium', 'Bold'])
      await file('$material/Roboto-$weight.ttf'),
  ];
  final families = <String, List<Future<ByteData>>>{
    'packages/app_ui/Nunito': [
      rootBundle.load('packages/app_ui/assets/fonts/Nunito-Bold.ttf'),
      rootBundle.load('packages/app_ui/assets/fonts/Nunito-ExtraBold.ttf'),
    ],
    'MaterialIcons': [file('$material/MaterialIcons-Regular.otf')],
    // FlutterTest is what a style with no family falls back to in a test.
    for (final family in const [
      'FlutterTest',
      'Roboto',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF Pro Text',
      '.SF Pro Display',
      '.SF UI Text',
      '.SF UI Display',
    ])
      family: [for (final face in roboto) Future.value(face)],
  };
  for (final MapEntry(key: family, value: faces) in families.entries) {
    final loader = FontLoader(family);
    faces.forEach(loader.addFont);
    await loader.load();
  }
}
