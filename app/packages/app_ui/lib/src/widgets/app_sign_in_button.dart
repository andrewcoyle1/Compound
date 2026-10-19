import 'package:app_ui/app_ui.dart';

/// {@template app_sign_in_button}
/// The frame Apple's and Google's sign-in buttons share, so the two always
/// match: [height] tall with capsule ends, and the title [titleSize] in a
/// medium weight that, like Apple's system button, keeps its proportion to
/// the button rather than following the text size setting.
///
/// [leading] and [trailing] sit either side of the title (the logo and each
/// brand's padding). While [isLoading] a spinner takes their place.
/// {@endtemplate}
class AppSignInButton extends StatelessWidget {
  /// {@macro app_sign_in_button}
  const new({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.background,
    required this.foreground,
    required this.leading,
    required this.trailing,
    this.border = BorderSide.none,
    super.key,
  });

  /// The title, localized.
  final String label;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether sign-in is under way.
  final bool isLoading;

  /// The fill.
  final Color background;

  /// The title's and spinner's colour.
  final Color foreground;

  /// The capsule's outline.
  final BorderSide border;

  /// Before the title.
  final List<Widget> leading;

  /// After the title.
  final List<Widget> trailing;

  /// The Swift app's height, and the HIG's for a Sign in with Apple button.
  static const double height = 56;

  /// 43% of the height, as Apple's system button sizes its title.
  static const double titleSize = height * 0.43;

  @override
  Widget build(BuildContext context) {
    final onTap = isLoading ? null : onPressed;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: StadiumBorder(side: border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: foreground.withValues(alpha: 0.2),
          highlightColor: foreground.withValues(alpha: 0.1),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: isLoading
                ? Center(
                    child: AppSpinner(
                      size: AppSpinnerSize.small,
                      color: foreground,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...leading,
                        Text(
                          label,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: AppTextStyles.rowTitle.fontFamily,
                            color: foreground,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                        ...trailing,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
