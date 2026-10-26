import 'package:app_ui/app_ui.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';

/// A card asking for a decision (`decisionCard`): the summary card's
/// header, a line, and two buttons. The Nutrition Overview's target
/// proposal; it has buttons, so it is not an `AppSummaryCard`.
class DecisionCard extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    this.info,
    super.key,
  });

  final String title;
  final String message;
  final String primary;
  final VoidCallback onPrimary;
  final String secondary;
  final VoidCallback onSecondary;

  /// The method behind the card's figure, for its info button.
  final MethodInfo? info;

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.s,
          children: [
            // The summary card's header: a glyph and an overline.
            Row(
              spacing: AppSpacing.s,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    AppSymbols.goal,
                    size: MediaQuery.textScalerOf(context).scale(
                      AppTextStyles.overline.fontSize! *
                          AppTextStyles.overline.height!,
                    ),
                    color: context.appColors.calories,
                  ),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title.toUpperCase(),
                      semanticsLabel: title,
                      style: AppTextStyles.overline.secondary(context),
                    ),
                  ),
                ),
                if (info != null) MethodInfoButton(info),
              ],
            ),
            Text(message, style: AppTextStyles.rowDetail.secondary(context)),
            Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.s,
              children: [
                AppCtaButton(
                  label: primary,
                  size: AppCtaSize.compact,
                  onPressed: onPrimary,
                ),
                AppCtaButton(
                  label: secondary,
                  size: AppCtaSize.compact,
                  variant: AppCtaVariant.secondary,
                  onPressed: onSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
