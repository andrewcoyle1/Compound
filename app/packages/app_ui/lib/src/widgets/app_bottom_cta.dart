import 'package:app_ui/app_ui.dart';

/// {@template app_bottom_cta}
/// Pins a screen's calls to action to the bottom safe area, with the
/// standard spacing. Use it as `Scaffold.bottomNavigationBar`.
///
/// Pass one or two [AppCtaButton]s, or one plus an [AppCtaVariant.plain]
/// one. With no children it takes no room, so a conditional button never
/// leaves a gap.
/// {@endtemplate}
class AppBottomCta extends StatelessWidget {
  /// {@macro app_bottom_cta}
  const new({required this.children, super.key});

  /// The buttons, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.l,
          right: AppSpacing.l,
          top: AppSpacing.s,
          bottom: AppSpacing.s,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: children,
        ),
      ),
    );
  }
}
