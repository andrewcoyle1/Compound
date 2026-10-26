import 'package:app_ui/app_ui.dart';

/// {@template app_feature_row}
/// One thing a subscription or feature includes, for a list of benefits:
/// its glyph in a circle, a [title] and a [detail] line. Put it in an
/// [AppSection], which starts the divider under it past the circle.
///
/// The circle is `raised`, a step above the card, and plain information:
/// never the accent. At the accessibility text sizes it sits above the text
/// instead of beside it, so the title keeps the row's width. The row reads
/// as one element.
/// {@endtemplate}
class AppFeatureRow extends StatelessWidget {
  /// {@macro app_feature_row}
  const new({required this.icon, required this.title, this.detail, super.key});

  /// The glyph, from [AppSymbols].
  final IconData icon;

  /// What is included.
  final String title;

  /// A line on what it does.
  final String? detail;

  /// Where the divider under the row starts, from its leading edge: under
  /// the text, or the row's margin once the circle sits above the text.
  static double textInset(TextScaler scaler) => _stacks(scaler)
      ? AppSpacing.l
      : AppSpacing.l + scaler.scale(AppControlSize.thumbnail) + AppSpacing.m;

  static bool _stacks(TextScaler scaler) =>
      scaler.scale(AppTextStyles.rowTitle.fontSize!) >=
      AppTextStyles.rowTitle.fontSize! * AppListRow.accessibilityTextScale;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final detail = this.detail;
    final circle = ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: context.appColors.raised,
        ),
        child: SizedBox.square(
          dimension: scaler.scale(AppControlSize.thumbnail),
          child: Icon(
            icon,
            size: scaler.scale(AppControlSize.icon),
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xxs,
      children: [
        Text(title, style: AppTextStyles.rowTitle),
        if (detail != null)
          Text(detail, style: AppTextStyles.rowDetail.secondary(context)),
      ],
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: _stacks(scaler)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.s,
                children: [circle, text],
              )
            : Row(
                spacing: AppSpacing.m,
                children: [
                  circle,
                  Expanded(child: text),
                ],
              ),
      ),
    );
  }
}
