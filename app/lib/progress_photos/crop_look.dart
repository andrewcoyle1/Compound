import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:image_repository/image_repository.dart';

/// The crop screen's look, read when it opens: the app's theme for the
/// device's light or dark setting, and its words in the device's language.
/// The app has no in-app override of either, so no `BuildContext` is
/// needed (as `AppNotificationCopy` reads its strings).
CropLook deviceCropLook() {
  final device = WidgetsBinding.instance.platformDispatcher;
  final dark = device.platformBrightness == Brightness.dark;
  final scheme = (dark ? AppTheme.dark : AppTheme.light).colorScheme;
  final colors = dark ? AppColors.dark : AppColors.light;
  final l10n = lookupAppLocalizations(
    basicLocaleListResolution(
      device.locales,
      AppLocalizations.supportedLocales,
    ),
  );
  return CropLook(
    title: l10n.photoCropTitle,
    done: l10n.photoCropDone,
    cancel: l10n.photoCropCancel,
    toolbar: scheme.surface,
    onToolbar: scheme.onSurface,
    accent: colors.accentInk,
    background: colors.canvas,
    brightness: scheme.brightness,
  );
}
