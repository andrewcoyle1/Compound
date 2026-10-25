import 'package:app_ui/app_ui.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';

/// A card asking for a decision: a title, a line, and two buttons
/// (`decisionCard`). Used by the check-in and target proposal cards here
/// and by Today's check-in card.
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
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
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
