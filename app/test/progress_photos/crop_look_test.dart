import 'package:app_ui/app_ui.dart';
import 'package:compound/progress_photos/crop_look.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;

  tearDown(() {
    dispatcher
      ..clearPlatformBrightnessTestValue()
      ..clearLocalesTestValue();
  });

  test("follows the device's light setting and language", () {
    dispatcher
      ..platformBrightnessTestValue = Brightness.light
      ..localesTestValue = const [Locale('en', 'GB')];

    final look = deviceCropLook();

    expect(look.title, 'Crop Photo');
    expect(look.done, 'Done');
    expect(look.cancel, 'Cancel');
    expect(look.toolbar, AppTheme.light.colorScheme.surface);
    expect(look.onToolbar, AppTheme.light.colorScheme.onSurface);
    expect(look.accent, AppTheme.light.colorScheme.primary);
    expect(look.background, AppColors.light.canvas);
    expect(look.brightness, Brightness.light);
  });

  test('is dark, in Spanish, on a dark Spanish device', () {
    dispatcher
      ..platformBrightnessTestValue = Brightness.dark
      ..localesTestValue = const [Locale('es', 'ES')];

    final look = deviceCropLook();

    expect(look.title, 'Recortar foto');
    expect(look.toolbar, AppTheme.dark.colorScheme.surface);
    expect(look.background, AppColors.dark.canvas);
    expect(look.brightness, Brightness.dark);
  });
}
