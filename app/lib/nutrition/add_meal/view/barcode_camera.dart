import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The camera, reading product barcodes (`mobile_scanner`). When there is
/// no camera, or it may not be used, it says so; typing the barcode is
/// still offered below it.
// coverage:ignore-start
// The camera is a platform view, which a widget test cannot drive.
class BarcodeCamera extends StatelessWidget {
  const new({required this.onDetect, super.key});

  /// Called with each code read.
  final ValueChanged<String> onDetect;

  @override
  Widget build(BuildContext context) => MobileScanner(
    onDetect: (capture) {
      final code = capture.barcodes.firstOrNull?.rawValue;
      if (code != null) onDetect(code);
    },
    errorBuilder: (context, error) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Text(
            error.errorCode == MobileScannerErrorCode.permissionDenied
                ? context.l10n.addMealCameraDenied
                : context.l10n.addMealCameraUnavailable,
            textAlign: TextAlign.center,
            style: AppTextStyles.rowDetail,
          ),
        ),
      ),
    ),
  );
}
// coverage:ignore-end
