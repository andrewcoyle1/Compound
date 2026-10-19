import 'package:app_ui/app_ui.dart';

/// What sits at the trailing end of an [AppListRow].
sealed class AppListRowAccessory {
  const new();
}

/// A disclosure chevron: the row opens another screen.
final class AppListRowChevron extends AppListRowAccessory {
  /// A disclosure chevron.
  const new();
}

/// A selection indicator: a filled check in the accent when [selected], an
/// empty circle when not. The row is announced as selected.
final class AppListRowCheckmark extends AppListRowAccessory {
  /// A selection indicator.
  const new({required this.selected});

  /// Whether the row is the chosen option.
  final bool selected;
}

/// A trailing value in secondary text.
final class AppListRowValue extends AppListRowAccessory {
  /// A trailing value.
  const new(this.value);

  /// The formatted value.
  final String value;
}

/// Any trailing widget, such as a switch or a button.
final class AppListRowCustom extends AppListRowAccessory {
  /// A trailing widget.
  const new(this.child);

  /// The widget.
  final Widget child;
}

/// {@template app_list_row}
/// The one list row: a leading icon or thumbnail, a title and subtitle, and
/// an [accessory]. It draws content only; put it in an [AppSection].
/// [AppListRowButton], [AppListRowToggle] and [AppSelectableRow] wrap it for
/// the interactive cases.
///
/// Text scales with the user's setting, the row is at least 52 pt tall (iOS
/// 26's inset-grouped row), and
/// at the largest text sizes a value or custom accessory moves under the
/// title instead of squeezing it. The subtitle stops at two lines, except at
/// those sizes and on a checkmark row, whose subtitle explains the choice.
/// {@endtemplate}
class AppListRow extends StatelessWidget {
  /// {@macro app_list_row}
  const new({
    required this.title,
    this.subtitle,
    this.icon,
    this.thumbnail,
    this.tint,
    this.accessory,
    super.key,
  });

  /// Text scaled this far or more counts as an accessibility size (iOS's
  /// smallest accessibility size is 1.65 times the default).
  static const accessibilityTextScale = 1.6;

  /// The title, localized or the user's own.
  final String title;

  /// A line under the title.
  final String? subtitle;

  /// A leading icon, in [tint].
  final IconData? icon;

  /// A leading image, such as an exercise photo, clipped to a rounded square.
  /// Ignored when [icon] is set.
  final Widget? thumbnail;

  /// The icon's colour. Defaults to the accent.
  final Color? tint;

  /// The trailing accessory, or none.
  final AppListRowAccessory? accessory;

  /// Where the text starts, from the row's leading edge: past the leading
  /// [icon] or [thumbnail] when there is one. [AppSection] starts the
  /// divider below the row there, as iOS does.
  static double textInset(
    TextScaler scaler, {
    IconData? icon,
    Widget? thumbnail,
  }) {
    final leading = icon != null
        ? AppControlSize.icon
        : thumbnail != null
        ? AppControlSize.thumbnail
        : null;
    return leading == null
        ? AppSpacing.l
        : AppSpacing.l + scaler.scale(leading) + AppSpacing.m;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final isAccessibilitySize =
        scaler.scale(AppTextStyles.rowTitle.fontSize!) >=
        AppTextStyles.rowTitle.fontSize! * accessibilityTextScale;
    final accessory = this.accessory;
    final icon = this.icon;
    final thumbnail = this.thumbnail;

    final leading = icon != null
        ? Icon(
            icon,
            size: scaler.scale(AppControlSize.icon),
            color: tint ?? scheme.primary,
          )
        : thumbnail != null
        ? ClipRSuperellipse(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.s)),
            child: SizedBox.square(
              dimension: scaler.scale(AppControlSize.thumbnail),
              child: thumbnail,
            ),
          )
        : null;

    final wrapsSubtitle =
        accessory is AppListRowCheckmark || isAccessibilitySize;
    final subtitle = this.subtitle;
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xxs,
      children: [
        Text(
          title,
          style: AppTextStyles.rowTitle.copyWith(color: scheme.onSurface),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: AppTextStyles.rowDetail.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: wrapsSubtitle ? null : 2,
            overflow: wrapsSubtitle ? null : TextOverflow.ellipsis,
          ),
      ],
    );

    final inline = switch (accessory) {
      AppListRowValue(:final value) => Text(
        value,
        style: AppTextStyles.rowTitle.copyWith(color: scheme.onSurfaceVariant),
        textAlign: isAccessibilitySize ? TextAlign.start : TextAlign.end,
      ),
      AppListRowCustom(:final child) => child,
      _ => null,
    };

    final glyphSize = AppIconSize.small.of(context);
    final trailing = switch (accessory) {
      AppListRowChevron() => Icon(
        AppSymbols.disclosure,
        size: glyphSize,
        color: scheme.outline,
      ),
      AppListRowCheckmark(:final selected) => Icon(
        selected ? AppSymbols.choiceSelected : AppSymbols.choiceUnselected,
        size: glyphSize,
        color: selected ? scheme.primary : scheme.outline,
      ),
      _ => null,
    };

    final Widget middle;
    if (inline == null) {
      middle = titles;
    } else if (isAccessibilitySize) {
      middle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s,
        children: [titles, inline],
      );
    } else {
      middle = Row(
        spacing: AppSpacing.s,
        children: [
          Expanded(child: titles),
          inline,
        ],
      );
    }

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppControlSize.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          spacing: AppSpacing.m,
          children: [
            if (leading != null) ExcludeSemantics(child: leading),
            Expanded(child: middle),
            if (trailing != null) ExcludeSemantics(child: trailing),
          ],
        ),
      ),
    );

    // A checkmark row reads as one element carrying the selected state.
    // Other rows keep their children apart, so a custom accessory's button
    // stays reachable.
    if (accessory is AppListRowCheckmark) {
      return MergeSemantics(
        child: Semantics(selected: accessory.selected, child: row),
      );
    }
    return row;
  }
}
