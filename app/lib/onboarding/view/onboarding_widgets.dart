import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:flutter/services.dart';

/// An onboarding question: [AppOnboardingStepScaffold] with the step's
/// progress, the shared labels, and a back button inside a step.
class OnboardingQuestion extends StatelessWidget {
  const new({
    required this.step,
    required this.title,
    required this.onContinue,
    this.subtitle,
    this.continueLabel,
    this.isLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.onBack,
    this.children = const [],
    super.key,
  });

  final OnboardingStep step;
  final String title;
  final String? subtitle;

  /// Called by the primary button; null disables it.
  final VoidCallback? onContinue;

  /// The primary button's label; Continue when null.
  final String? continueLabel;
  final bool isLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppOnboardingStepScaffold(
      title: title,
      subtitle: subtitle,
      progress: step.progress,
      progressLabel: l10n.onboardingProgress,
      primaryLabel: continueLabel ?? l10n.onboardingContinue,
      onPrimaryPressed: onContinue,
      isPrimaryLoading: isLoading,
      loadingLabel: l10n.onboardingSaving,
      secondaryLabel: secondaryLabel,
      onSecondaryPressed: onSecondary,
      onBack: onBack,
      children: children,
    );
  }
}

/// A choice list: one [AppSelectableRow] per option, with the selection
/// tick (Swift's `.selection` haptic) on every pick.
class OnboardingOptions<T> extends StatelessWidget {
  const new({
    required this.options,
    required this.selected,
    required this.title,
    required this.onSelected,
    this.subtitle,
    this.header,
    this.footer,
    super.key,
  });

  final List<T> options;
  final T? selected;
  final String Function(T option) title;
  final String? Function(T option)? subtitle;
  final ValueChanged<T> onSelected;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      header: header,
      footer: footer,
      children: [
        for (final option in options)
          AppSelectableRow(
            title: title(option),
            subtitle: subtitle?.call(option),
            selected: option == selected,
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              onSelected(option);
            },
          ),
      ],
    );
  }
}

/// Swift's "Unable to save" alert, with the error haptic. [onRetry] adds
/// Try Again beside the dismiss button.
Future<void> showOnboardingFailure(
  BuildContext context, {
  required String title,
  String? message,
  VoidCallback? onRetry,
}) {
  unawaited(HapticFeedback.errorNotification());
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message ?? l10n.onboardingCheckConnection),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            onRetry == null
                ? MaterialLocalizations.of(context).okButtonLabel
                : MaterialLocalizations.of(context).cancelButtonLabel,
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry();
            },
            child: Text(l10n.tryAgainButton),
          ),
      ],
    ),
  );
}

/// The success haptic Swift plays after every save.
void onboardingSaved() => unawaited(HapticFeedback.successNotification());
