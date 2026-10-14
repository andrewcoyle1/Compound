import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  final scheme = AppTheme.light.colorScheme;
  const colors = AppColors.light;

  for (final (kind, icon, color) in [
    (AppInlineMessageKind.error, AppSymbols.error, colors.danger),
    (AppInlineMessageKind.warning, AppSymbols.warning, colors.warning),
    (AppInlineMessageKind.info, AppSymbols.info, scheme.onSurfaceVariant),
  ]) {
    testWidgets('${kind.name} draws its icon in its colour', (tester) async {
      await tester.pumpApp(
        AppInlineMessage(
          kind: kind,
          text: 'Values are per 100 g.',
          kindLabel: 'Note',
        ),
      );
      final drawn = tester.widget<Icon>(find.byType(Icon));
      expect(drawn.icon, icon);
      expect(drawn.color, color);
      expect(
        tester.getSemantics(find.byType(AppInlineMessage)),
        matchesSemantics(label: 'Note\nValues are per 100 g.'),
      );
    });
  }

  testWidgets('error text stays readable', (tester) async {
    await tester.pumpApp(
      const AppInlineMessage(
        kind: AppInlineMessageKind.error,
        text: 'No barcode found.',
        kindLabel: 'Error',
      ),
    );
    expect(
      tester.widget<Text>(find.text('No barcode found.')).style?.color,
      scheme.onSurface,
    );
  });
}
