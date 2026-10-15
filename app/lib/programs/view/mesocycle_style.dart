import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:flutter/services.dart';
import 'package:program_repository/program_repository.dart';

/// The glyph for a mesocycle's stored SF Symbol name.
IconData mesocycleGlyph(String icon) =>
    AppSymbols.mesocycleIcons[icon] ?? AppSymbols.mesocycle;

/// What VoiceOver and TalkBack read for one of [mesocycleColours]
/// (`MesocycleColourIconGrid.name(of:)`).
String mesocycleColourName(AppLocalizations l10n, String colour) =>
    switch (mesocycleColours.indexOf(colour)) {
      0 => l10n.programColourDefault,
      1 => l10n.programColourRed,
      2 => l10n.programColourOrange,
      3 => l10n.programColourYellow,
      4 => l10n.programColourGreen,
      5 => l10n.programColourBlue,
      _ => l10n.programColourPurple,
    };

/// What is read for one of [mesocycleIcons].
String mesocycleIconName(AppLocalizations l10n, String icon) =>
    switch (mesocycleIcons.indexOf(icon)) {
      0 => l10n.programIconFlag,
      1 => l10n.programIconJoystick,
      2 => l10n.programIconController,
      3 => l10n.programIconWalking,
      4 => l10n.programIconAirplane,
      5 => l10n.programIconSailboat,
      _ => l10n.programIconGauge,
    };

/// The colour row and icon grid a mesocycle is styled with, shared by the
/// create flow's icon step and the settings' colour and icon editor (Swift
/// `MesocycleColourIconGrid`). The swatches draw in the mesocycle's own
/// colours; the ring around the chosen one is the accent.
class const MesocycleColourIconGrid({
  required final String colour,
  required final String icon,
  required final ValueChanged<String> onColourPressed,
  required final ValueChanged<String> onIconPressed,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Fewer, larger swatches at large text, where seven across no longer
    // fit.
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    Widget grid(List<Widget> children) => GridView.count(
      crossAxisCount: large ? 4 : children.length.clamp(1, 7),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      children: children,
    );
    return Column(
      spacing: AppSpacing.l,
      children: [
        grid([
          for (final option in mesocycleColours)
            _Swatch(
              glyph: mesocycleGlyph(icon),
              colour: option,
              label: mesocycleColourName(l10n, option),
              selected: option == colour,
              onPressed: () => onColourPressed(option),
            ),
        ]),
        const Divider(),
        grid([
          for (final option in mesocycleIcons)
            _Swatch(
              glyph: mesocycleGlyph(option),
              colour: colour,
              label: mesocycleIconName(l10n, option),
              selected: option == icon,
              onPressed: () => onIconPressed(option),
            ),
        ]),
      ],
    );
  }
}

class const _Swatch({
  required final IconData glyph,
  required final String colour,
  required final String label,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = mesocycleColour(colour) ?? scheme.onSurface;
    final side = MediaQuery.textScalerOf(context).scale(AppControlSize.row);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Center(
        child: InkResponse(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onPressed();
          },
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: AppColors.tintedSurface(tint),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
            child: Icon(glyph, color: tint),
          ),
        ),
      ),
    );
  }
}
