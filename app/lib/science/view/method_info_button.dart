import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';

/// The info button beside a calculated figure (Swift `MethodInfoButton`).
/// Tapping it opens [MethodInfoSheet]. The sheet is view state, not
/// navigation, so any screen can place one without a route.
class MethodInfoButton extends StatelessWidget {
  const new(this.info, {super.key});

  /// The method to explain.
  final MethodInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      hint: l10n.methodInfoButtonHint,
      child: AppToolbarButton(
        icon: AppSymbols.info,
        semanticLabel: l10n.methodInfoButtonLabel(info.title),
        // The sheet's list takes its primary scroll controller, so
        // dragging the list drags the sheet.
        onPressed: () => showAppSheet<void>(
          context: context,
          builder: (_) => MethodInfoSheet(info: info),
        ),
      ),
    );
  }
}

/// What a figure is, how it is worked out, its limits, Compound's own
/// choices and the sources (Swift `MethodInfoSheet`). A source's DOI is
/// shown as selectable text rather than a link until the app opens URLs.
class MethodInfoSheet extends StatelessWidget {
  const new({required this.info, this.controller, super.key});

  /// The method shown.
  final MethodInfo info;

  /// The sheet's scroll controller, so dragging the list drags the sheet.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formula = info.formula;
    final limitations = info.limitations;
    final ownChoices = info.ownChoices;
    Widget text(String value) => Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Text(value, style: AppTextStyles.rowDetail),
    );
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.xl,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(
            info.title,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        AppSection(children: [text(info.summary)]),
        if (formula != null) ...[
          const SizedBox(height: AppSpacing.l),
          AppSection(
            header: l10n.methodInfoFormula,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: SelectableText(formula, style: AppTextStyles.formula),
              ),
            ],
          ),
        ],
        if (limitations != null) ...[
          const SizedBox(height: AppSpacing.l),
          AppSection(
            header: l10n.methodInfoLimitations,
            children: [text(limitations)],
          ),
        ],
        if (ownChoices != null) ...[
          const SizedBox(height: AppSpacing.l),
          AppSection(
            header: l10n.methodInfoOwnChoices,
            children: [text(ownChoices)],
          ),
        ],
        const SizedBox(height: AppSpacing.l),
        AppSection(
          header: l10n.methodInfoSources,
          children: [
            for (final citation in info.citations)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(citation.reference, style: AppTextStyles.rowDetail),
                    if (!citation.isPeerReviewed)
                      Text(
                        l10n.methodInfoNotPeerReviewed,
                        style: AppTextStyles.label.secondary(context),
                      ),
                    if (citation.linkText case final link?)
                      SelectableText(
                        link,
                        style: AppTextStyles.label.accent(context),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A section header with the method's info button at its trailing edge
/// (Swift `MethodInfoHeader`), above an [AppSection] without a header.
class MethodInfoHeader extends StatelessWidget {
  const new({required this.title, required this.info, super.key});

  /// The section's title.
  final String title;

  /// The method the section's figures come from.
  final MethodInfo info;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.sectionTitle.secondary(context),
            ),
          ),
        ),
        MethodInfoButton(info),
      ],
    ),
  );
}
