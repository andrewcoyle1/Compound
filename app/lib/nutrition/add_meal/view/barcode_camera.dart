import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The camera, reading product barcodes (`mobile_scanner`), with the
/// torch button Swift's scanner has wherever the camera has a torch. When
/// there is no camera, or it may not be used, it says so; typing the
/// barcode is still offered below it.
// coverage:ignore-start
// The camera is a platform view, which a widget test cannot drive.
class BarcodeCamera extends StatefulWidget {
  const new({required this.onDetect, super.key});

  /// Called with each code read.
  final ValueChanged<String> onDetect;

  @override
  State<BarcodeCamera> createState() => _BarcodeCameraState();
}

class _BarcodeCameraState extends State<BarcodeCamera> {
  final _controller = MobileScannerController();

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null) widget.onDetect(code);
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
      ),
      // Simulators, and cameras without a torch, report it unavailable.
      ValueListenableBuilder(
        valueListenable: _controller,
        builder: (context, state, _) {
          if (!state.isRunning || state.torchState == TorchState.unavailable) {
            return const SizedBox.shrink();
          }
          final on = state.torchState == TorchState.on;
          return Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: IconButton.filledTonal(
                tooltip: on
                    ? context.l10n.torchTurnOff
                    : context.l10n.torchTurnOn,
                isSelected: on,
                icon: const Icon(AppSymbols.torchOff),
                selectedIcon: const Icon(AppSymbols.torchOn),
                onPressed: () => unawaited(_controller.toggleTorch()),
              ),
            ),
          );
        },
      ),
    ],
  );
}
// coverage:ignore-end
