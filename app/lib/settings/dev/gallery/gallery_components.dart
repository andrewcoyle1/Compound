import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress_photos/sample_photo.dart';
import 'package:compound/settings/dev/gallery/component_gallery_page.dart';
import 'package:compound/settings/dev/gallery/gallery_entry.dart';
import 'package:go_router/go_router.dart';

// Every public `app_ui` widget, by part of the gallery. Captions are the
// parameters that make each state, so they are not translated (as Developer
// Settings' field names are not). A test fails while a widget in
// `app_ui/lib/src/widgets/` has no entry here.

/// [AppCtaButton], [AppTextButton], [AppIconButton], [AppToolbarButton] and
/// the sign-in buttons.
List<Widget> galleryButtons(BuildContext context) {
  final l10n = context.l10n;
  return [
    galleryEntry('AppCtaButton', [
      for (final variant in AppCtaVariant.values) ...[
        galleryBlock(
          variant.name,
          AppCtaButton(
            label: l10n.devGallerySampleAction,
            variant: variant,
            onPressed: galleryNoop,
          ),
        ),
        galleryBlock(
          '${variant.name}, disabled',
          AppCtaButton(
            label: l10n.devGallerySampleAction,
            variant: variant,
            onPressed: null,
          ),
        ),
        galleryBlock(
          '${variant.name}, isLoading',
          AppCtaButton(
            label: l10n.devGallerySampleAction,
            variant: variant,
            isLoading: true,
            loadingLabel: l10n.devGallerySampleLoading,
            onPressed: galleryNoop,
          ),
        ),
      ],
      for (final variant in AppCtaVariant.values)
        for (final (state, onPressed, loading) in [
          ('', galleryNoop, false),
          (', disabled', null, false),
          (', isLoading', galleryNoop, true),
        ])
          galleryInline(
            'compact, ${variant.name}$state',
            AppCtaButton(
              label: l10n.devGallerySampleShortAction,
              variant: variant,
              size: AppCtaSize.compact,
              isLoading: loading,
              loadingLabel: l10n.devGallerySampleLoading,
              onPressed: onPressed,
            ),
          ),
    ]),
    galleryEntry('AppTextButton', [
      galleryInline(
        'enabled',
        AppTextButton(
          label: l10n.devGallerySampleTextAction,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        'isDestructive',
        AppTextButton(
          label: l10n.devGallerySampleDelete,
          isDestructive: true,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        'disabled',
        AppTextButton(label: l10n.devGallerySampleTextAction, onPressed: null),
      ),
      galleryInline(
        'inline',
        AppTextButton(
          label: l10n.devGallerySampleTextAction,
          inline: true,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        'isSmall',
        AppTextButton(
          label: l10n.devGallerySampleTextAction,
          isSmall: true,
          onPressed: galleryNoop,
        ),
      ),
    ]),
    galleryEntry('AppFloatingButton', [
      galleryInline(
        'icon, label',
        AppFloatingButton(
          icon: AppSymbols.jumpToLatest,
          label: l10n.coachJumpToLatest,
          onPressed: galleryNoop,
        ),
      ),
    ]),
    galleryEntry('AppPressable', [
      galleryInline(
        'icon, 44 pt target',
        const AppPressable(onTap: galleryNoop, child: Icon(AppSymbols.add)),
      ),
      galleryInline(
        'own surface, haptic',
        AppPressable(
          onTap: galleryNoop,
          haptic: AppHaptic.selection,
          color: context.appColors.raised,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Text(l10n.devGallerySampleTextAction),
          ),
        ),
      ),
    ]),
    galleryEntry('AppDoneMark', [
      galleryInline('medium', const AppDoneMark()),
      galleryInline('small', const AppDoneMark(size: AppIconSize.small)),
    ]),
    galleryEntry('AppIconBadge', [
      galleryInline('filled', const AppIconBadge(icon: AppSymbols.meal)),
      galleryInline(
        'ring, badge',
        const AppIconBadge(
          icon: AppSymbols.meal,
          size: AppIconSize.hero,
          filled: false,
          badge: AppSymbols.edit,
        ),
      ),
    ]),
    galleryEntry('AppSwatch', [
      galleryInline('colour', AppSwatch(color: context.appColors.scaleWeight)),
      galleryInline(
        'glyph, selected',
        AppSwatch(
          color: context.appColors.workouts,
          icon: AppSymbols.streak,
          selected: true,
        ),
      ),
    ]),
    galleryEntry('AppSelectionRing', [
      for (final selected in [false, true])
        galleryInline(
          selected ? 'ring on' : 'ring off',
          AppSelectionRing(
            selected: selected,
            radius: AppRadius.m,
            filled: true,
            child: const SizedBox.square(dimension: AppControlSize.row),
          ),
        ),
    ]),
    galleryEntry('AppIconButton', [
      galleryInline(
        'enabled',
        AppIconButton(
          icon: AppSymbols.edit,
          semanticLabel: l10n.devGallerySampleEdit,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        'isDestructive',
        AppIconButton(
          icon: AppSymbols.delete,
          semanticLabel: l10n.devGallerySampleDelete,
          isDestructive: true,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        'disabled',
        AppIconButton(
          icon: AppSymbols.edit,
          semanticLabel: l10n.devGallerySampleEdit,
          onPressed: null,
        ),
      ),
      galleryInline(
        '.plain, label, selected',
        AppIconButton.plain(
          icon: AppSymbols.liked,
          semanticLabel: l10n.devGallerySampleEdit,
          label: '12',
          selected: true,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.plain',
        AppIconButton.plain(
          icon: AppSymbols.comment,
          semanticLabel: l10n.devGallerySampleEdit,
          onPressed: galleryNoop,
        ),
      ),
    ]),
    galleryEntry('AppToolbarButton', [
      galleryInline(
        'icon',
        AppToolbarButton(
          icon: AppSymbols.more,
          semanticLabel: l10n.devGallerySampleEdit,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        'icon, badgeCount',
        AppToolbarButton(
          icon: AppSymbols.notifications,
          semanticLabel: l10n.devGallerySampleEdit,
          badgeCount: 3,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.close',
        AppToolbarButton.close(
          semanticLabel: l10n.devGallerySampleClose,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.confirm',
        AppToolbarButton.confirm(
          semanticLabel: l10n.devGallerySampleSave,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.confirm, disabled',
        AppToolbarButton.confirm(
          semanticLabel: l10n.devGallerySampleSave,
          onPressed: null,
        ),
      ),
      galleryInline(
        '.confirm, isSaving',
        AppToolbarButton.confirm(
          semanticLabel: l10n.devGallerySampleSave,
          isSaving: true,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.avatar, initials',
        AppToolbarButton.avatar(
          semanticLabel: l10n.devGallerySampleProfile,
          initials: 'AC',
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.avatar, image',
        AppToolbarButton.avatar(
          semanticLabel: l10n.devGallerySampleProfile,
          image: AppImages.appIcon,
          onPressed: galleryNoop,
        ),
      ),
      galleryInline(
        '.avatar',
        AppToolbarButton.avatar(
          semanticLabel: l10n.devGallerySampleProfile,
          onPressed: galleryNoop,
        ),
      ),
    ]),
    galleryEntry('AppSignInWithAppleButton', [
      galleryBlock(
        'enabled',
        AppSignInWithAppleButton(
          label: l10n.signInWithAppleButton,
          onPressed: galleryNoop,
        ),
      ),
      galleryBlock(
        'isLoading',
        AppSignInWithAppleButton(
          label: l10n.signInWithAppleButton,
          isLoading: true,
          onPressed: galleryNoop,
        ),
      ),
    ]),
    galleryEntry('AppSignInWithGoogleButton', [
      galleryBlock(
        'enabled',
        AppSignInWithGoogleButton(
          label: l10n.signInWithGoogleButton,
          onPressed: galleryNoop,
        ),
      ),
      galleryBlock(
        'isLoading',
        AppSignInWithGoogleButton(
          label: l10n.signInWithGoogleButton,
          isLoading: true,
          onPressed: galleryNoop,
        ),
      ),
    ]),
  ];
}

/// [AppListRow] and its accessories, the row wrappers, [AppSection] and
/// [AppSwipeActions].
List<Widget> galleryRows(BuildContext context) {
  final l10n = context.l10n;
  final colors = context.appColors;
  final weight = AppFormat.weight(
    82.5,
    AppWeightUnit.kilograms,
    locale: context.dateLocale,
  );
  return [
    galleryEntry('AppListRow', [
      const AppListRow(title: 'title'),
      AppListRow(title: 'subtitle', subtitle: l10n.devGallerySampleSubtitle),
      const AppListRow(title: 'icon', icon: AppSymbols.workout),
      AppListRow(
        title: 'icon, tint',
        icon: AppSymbols.protein,
        tint: colors.protein,
      ),
      const AppListRow(
        title: 'thumbnail',
        thumbnail: Image(image: AppImages.appIcon),
      ),
      const AppListRow(
        title: 'AppListRowChevron',
        accessory: AppListRowChevron(),
      ),
      const AppListRow(
        title: 'AppListRowCheckmark, selected',
        accessory: AppListRowCheckmark(selected: true),
      ),
      const AppListRow(
        title: 'AppListRowCheckmark',
        accessory: AppListRowCheckmark(selected: false),
      ),
      AppListRow(title: 'AppListRowValue', accessory: AppListRowValue(weight)),
      AppListRow(
        title: 'AppListRowMenu',
        accessory: AppListRowMenu(AppWeightUnit.kilograms.symbol),
      ),
      AppListRow(
        title: 'AppListRowCustom',
        accessory: AppListRowCustom(
          AppChip(label: l10n.devGallerySampleShortAction),
        ),
      ),
      AppListRow(
        title: 'AppListRowCustom(pinned)',
        subtitle: l10n.devGallerySampleSubtitle,
        accessory: const AppListRowCustom(
          Icon(AppSymbols.choiceUnselected),
          pinned: true,
        ),
      ),
      const AppListRow(
        title: 'destructive',
        icon: AppSymbols.delete,
        destructive: true,
      ),
      AppListRow(
        title: l10n.devGallerySampleLongTitle,
        subtitle: l10n.devGallerySampleMessage,
        icon: AppSymbols.note,
        accessory: AppListRowValue(weight),
      ),
    ]),
    galleryEntry('AppListRowButton', [
      const AppListRowButton(title: 'chevron', onPressed: galleryNoop),
      AppListRowButton(
        title: 'icon, subtitle',
        subtitle: l10n.devGallerySampleSubtitle,
        icon: AppSymbols.settings,
        onPressed: galleryNoop,
      ),
      AppListRowButton(
        title: 'tint, no accessory',
        icon: AppSymbols.add,
        tint: colors.success,
        accessory: null,
        onPressed: galleryNoop,
      ),
      const AppListRowButton(
        title: 'destructive',
        icon: AppSymbols.delete,
        destructive: true,
        accessory: null,
        onPressed: galleryNoop,
      ),
      const AppListRowButton(title: 'disabled', onPressed: null),
    ]),
    galleryEntry('AppListRowToggle', [
      for (final (caption, initial, subtitle, icon) in [
        ('on', true, null, null),
        ('off', false, null, null),
        (
          'icon, subtitle',
          true,
          l10n.devGallerySampleSubtitle,
          AppSymbols.notifications,
        ),
      ])
        GalleryLive(
          initial: initial,
          builder: (value, update) => AppListRowToggle(
            title: caption,
            subtitle: subtitle,
            icon: icon,
            value: value,
            onChanged: update,
          ),
        ),
      const AppListRowToggle(title: 'disabled', value: true, onChanged: null),
    ]),
    galleryEntry('AppSelectableRow', [
      GalleryLive(
        initial: 0,
        builder: (selected, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, caption) in [
              'selected',
              'not selected',
              'subtitle',
            ].indexed)
              AppSelectableRow(
                title: caption,
                subtitle: index == 2 ? l10n.devGallerySampleSubtitle : null,
                selected: selected == index,
                onPressed: () => update(index),
              ),
          ],
        ),
      ),
      const AppSelectableRow(
        title: 'disabled',
        selected: false,
        onPressed: null,
      ),
    ]),
    AppSection(
      header: 'AppSection: header, trailing Text, footer',
      trailing: Text(AppFormat.number(3)),
      footer: l10n.devGallerySampleMessage,
      children: [AppListRow(title: l10n.devGallerySampleTitle)],
    ),
    AppSection(
      header: 'AppSection: trailing AppChip',
      trailing: AppChip(
        label: l10n.devGallerySampleTextAction,
        onPressed: galleryNoop,
      ),
      children: [AppListRow(title: l10n.devGallerySampleTitle)],
    ),
    AppSection(
      header: 'AppSection: grouped false',
      grouped: false,
      children: [
        AppCard(child: AppListRow(title: l10n.devGallerySampleTitle)),
        AppCard(child: AppListRow(title: l10n.devGallerySampleTitle)),
      ],
    ),
    galleryEntry('AppSwipeActions', [
      AppSwipeActions(
        leading: [
          AppSwipeAction(
            label: l10n.devGallerySamplePin,
            icon: AppSymbols.pinnedNote,
            onPressed: galleryNoop,
          ),
        ],
        trailing: [
          AppSwipeAction(
            label: l10n.devGallerySampleArchive,
            tint: colors.warning,
            onPressed: galleryNoop,
          ),
          AppSwipeAction(
            label: l10n.devGallerySampleDelete,
            icon: AppSymbols.delete,
            isDestructive: true,
            onPressed: galleryNoop,
          ),
        ],
        child: const AppListRow(title: 'leading, trailing: swipe either way'),
      ),
    ]),
  ];
}

/// [AppSearchField], [AppNumberField], [AppTextFieldRow], [AppTextField] and
/// [AppSegmentedControl].
List<Widget> galleryInputs(BuildContext context) {
  final l10n = context.l10n;
  final units = [for (final unit in AppWeightUnit.values) unit.symbol];
  final periods = [
    l10n.devGallerySampleDay,
    l10n.devGallerySampleWeek,
    l10n.devGallerySampleMonth,
  ];
  AppSegmentedControl<int> segments(
    List<String> labels,
    int? selected,
    ValueChanged<int>? onChanged,
  ) => AppSegmentedControl<int>(
    segments: [
      for (final (index, label) in labels.indexed)
        AppSegment(value: index, label: label),
    ],
    selected: selected,
    onChanged: onChanged,
  );
  return [
    galleryEntry('AppSearchField', [
      galleryBlock(
        'empty',
        AppSearchField(
          hint: l10n.devGallerySampleSearch,
          clearLabel: l10n.devGallerySampleClear,
          onChanged: (_) {},
        ),
      ),
      galleryBlock(
        'initialValue',
        AppSearchField(
          hint: l10n.devGallerySampleSearch,
          clearLabel: l10n.devGallerySampleClear,
          initialValue: l10n.devGallerySampleTitle,
          onChanged: (_) {},
        ),
      ),
    ]),
    galleryEntry('AppNumberField', [
      galleryBlock(
        'prompt, unit',
        GalleryLive<double?>(
          initial: null,
          builder: (value, update) => AppNumberField(
            value: value,
            prompt: '0',
            unit: AppWeightUnit.kilograms.symbol,
            onChanged: update,
          ),
        ),
      ),
      galleryBlock(
        'label, value',
        GalleryLive<double?>(
          initial: 82.5,
          builder: (value, update) => AppNumberField(
            value: value,
            label: l10n.devGallerySampleWeight,
            unit: AppWeightUnit.kilograms.symbol,
            onChanged: update,
          ),
        ),
      ),
      galleryBlock(
        '.units',
        GalleryLive(
          initial: units.first,
          builder: (unit, update) => AppNumberField.units(
            value: 82.5,
            label: l10n.devGallerySampleWeight,
            unit: unit,
            units: units,
            unitsLabel: l10n.devGallerySampleUnit,
            onUnitChanged: update,
            onChanged: (_) {},
          ),
        ),
      ),
    ]),
    galleryEntry('AppTextFieldRow', [
      galleryBlock(
        'empty',
        AppSection(
          children: [
            AppTextFieldRow(
              label: l10n.devGallerySampleTitle,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
      galleryBlock(
        'initialValue',
        AppSection(
          children: [
            AppTextFieldRow(
              label: l10n.devGallerySampleTitle,
              initialValue: l10n.devGallerySampleSubtitle,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
      galleryBlock(
        'prefixText, suffixText',
        AppSection(
          children: [
            AppTextFieldRow(
              label: l10n.devGallerySampleTitle,
              initialValue: '50',
              keyboardType: TextInputType.number,
              prefixText: '@',
              suffixText: '%',
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    ]),
    galleryEntry('AppTextField', [
      galleryBlock(
        'boxed: label, helper',
        AppTextField(
          label: l10n.devGallerySampleTitle,
          helper: l10n.devGallerySampleSubtitle,
        ),
      ),
      galleryBlock(
        'composer',
        AppTextField(
          hint: l10n.devGallerySampleTitle,
          style: AppTextFieldStyle.composer,
          minLines: 1,
          maxLines: 5,
        ),
      ),
      galleryBlock(
        'plain',
        AppTextField(
          hint: l10n.devGallerySampleTitle,
          style: AppTextFieldStyle.plain,
        ),
      ),
    ]),
    galleryEntry('AppSegmentedControl', [
      galleryBlock(
        'two',
        GalleryLive(
          initial: 0,
          builder: (value, update) => segments(units, value, update),
        ),
      ),
      galleryBlock(
        'three',
        GalleryLive(
          initial: 1,
          builder: (value, update) => segments(periods, value, update),
        ),
      ),
      galleryBlock(
        'nothing selected',
        GalleryLive<int?>(
          initial: null,
          builder: (value, update) => segments(periods, value, update),
        ),
      ),
      galleryBlock('disabled', segments(periods, 2, null)),
    ]),
  ];
}

/// [AppTabBar] and [AppTabAccessory], and the screen layouts:
/// [AppScaffold] with [AppReadableWidth], [AppDashboard], [AppBottomCta]
/// and [AppOnboardingStepScaffold], each opened as a screen.
List<Widget> galleryNavigation(BuildContext context) {
  final l10n = context.l10n;
  final tabs = [
    AppTabBarItem(
      icon: AppSymbols.today,
      selectedIcon: AppSymbols.todayFilled,
      label: l10n.tabToday,
    ),
    AppTabBarItem(
      icon: AppSymbols.workout,
      selectedIcon: AppSymbols.workoutFilled,
      label: l10n.tabTraining,
    ),
    AppTabBarItem(
      icon: AppSymbols.nutrition,
      selectedIcon: AppSymbols.nutritionFilled,
      label: l10n.tabNutrition,
    ),
    AppTabBarItem(
      icon: AppSymbols.analytics,
      selectedIcon: AppSymbols.analyticsFilled,
      label: l10n.tabProgress,
    ),
    AppTabBarItem(
      icon: AppSymbols.friends,
      selectedIcon: AppSymbols.friendsFilled,
      label: l10n.tabSocial,
      badgeCount: 3,
    ),
  ];
  final meal = AppTabAccessory(
    semanticLabel: l10n.mealDraftLabel(2),
    onTap: galleryNoop,
    child: Row(
      spacing: AppSpacing.m,
      children: [
        const Icon(AppSymbols.meal),
        Expanded(child: Text(l10n.mealDraftTitle)),
        const Icon(AppSymbols.disclosure),
      ],
    ),
  );
  return [
    galleryEntry('AppTabBar', [
      galleryBlock(
        'selectedIndex, badgeCount',
        GalleryLive(
          initial: 0,
          builder: (selected, update) => AppTabBar(
            selectedIndex: selected,
            onSelected: update,
            items: tabs,
          ),
        ),
      ),
      galleryBlock(
        'accessory',
        GalleryLive(
          initial: 1,
          builder: (selected, update) => AppTabBar(
            selectedIndex: selected,
            onSelected: update,
            items: tabs,
            accessory: meal,
          ),
        ),
      ),
    ]),
    galleryEntry('AppTabAccessory', [
      galleryBlock('semanticLabel, onTap', meal),
      galleryBlock(
        'trailing',
        AppTabAccessory(
          semanticLabel: l10n.devGallerySampleTitle,
          onTap: galleryNoop,
          trailing: AppToolbarButton(
            icon: AppSymbols.skip,
            semanticLabel: l10n.accessorySkipRest,
            onPressed: galleryNoop,
          ),
          child: Text(l10n.devGallerySampleTitle),
        ),
      ),
    ]),
    galleryEntry('AppScaffold', [
      AppListRowButton(
        title: 'largeTitle, AppDashboard, AppBottomCta',
        onPressed: () =>
            unawaited(galleryPush(context, const _SampleTabRoot())),
      ),
      AppListRowButton(
        title: 'AppOnboardingStepScaffold',
        onPressed: () =>
            unawaited(galleryPush(context, const _SampleOnboardingStep())),
      ),
    ], note: 'AppReadableWidth holds every AppScaffold to a 700 pt column.'),
  ];
}

/// [showAppDialog] and [AppDialog], [showAppSnackBar] and [AppSnackBar],
/// [showAppSheet] and [AppSheetPage], [AppMenuItem], and [AppTip] with its
/// [AppTipScope] and [AppTipCallout].
List<Widget> galleryOverlays(BuildContext context) {
  final l10n = context.l10n;
  final keep = AppDialogAction<void>(label: l10n.devGallerySampleKeepEditing);
  final cancel = AppDialogAction<void>(
    label: l10n.devGallerySampleCancel,
    role: AppDialogRole.cancel,
  );
  final discard = AppDialogAction<void>(
    label: l10n.devGallerySampleDiscard,
    role: AppDialogRole.destructive,
  );
  void dialog(List<AppDialogAction<void>> actions, {Widget? content}) =>
      unawaited(
        showAppDialog<void>(
          context: context,
          title: l10n.devGallerySampleDialogTitle,
          message: l10n.devGallerySampleDialogMessage,
          content: content,
          actions: actions,
        ),
      );
  return [
    galleryEntry('showAppDialog', [
      AppListRowButton(
        title: 'cancel, destructive',
        onPressed: () => dialog([cancel, discard]),
      ),
      AppListRowButton(
        title: 'standard, preferred',
        onPressed: () => dialog([
          keep,
          AppDialogAction(
            label: l10n.devGallerySampleSave,
            role: AppDialogRole.preferred,
          ),
        ]),
      ),
      AppListRowButton(
        title: 'three actions, stacked',
        onPressed: () => dialog([cancel, keep, discard]),
      ),
      AppListRowButton(
        title: 'content',
        onPressed: () => dialog(
          [cancel, keep],
          content: AppNumberField(value: null, prompt: '0', onChanged: (_) {}),
        ),
      ),
      AppListRowButton(
        title: 'AppDialog.confirmDestructive',
        onPressed: () => unawaited(
          AppDialog.confirmDestructive(
            context,
            title: l10n.devGallerySampleDialogTitle,
            message: l10n.devGallerySampleDialogMessage,
            confirmLabel: l10n.devGallerySampleDiscard,
          ),
        ),
      ),
    ], note: 'On iOS an alert keeps the app theme, not the gallery switch.'),
    galleryEntry(
      'showAppSnackBar',
      [
        for (final style in AppSnackBarStyle.values)
          AppListRowButton(
            title: style.name,
            onPressed: () => showAppSnackBar(
              context,
              l10n.devGallerySampleMessage,
              style: style,
            ),
          ),
        AppListRowButton(
          title: 'action, stays until tapped',
          onPressed: () => showAppSnackBar(
            context,
            l10n.trackerSetDeleted,
            action: AppSnackBarAction(
              label: l10n.trackerUndo,
              onPressed: () {},
            ),
          ),
        ),
      ],
      note:
          'Drawn above the app by AppSnackBarScope (AppSnackBarScopeState '
          'shows one after an await); AppSnackBarClearance keeps it above '
          'the tab bar and a bottom CTA.',
    ),
    galleryEntry('AppSnackBar', [
      for (final style in AppSnackBarStyle.values)
        galleryBlock(
          style.name,
          AppSnackBar(message: l10n.devGallerySampleMessage, style: style),
        ),
      galleryBlock(
        'action',
        AppSnackBar(
          message: l10n.trackerSetDeleted,
          action: AppSnackBarAction(label: l10n.trackerUndo, onPressed: () {}),
        ),
      ),
    ]),
    galleryEntry('showAppSheet', [
      for (final size in AppSheetSize.values)
        AppListRowButton(
          title: size.name,
          onPressed: () => unawaited(
            showAppSheet<void>(
              context: context,
              size: size,
              builder: (_) => GalleryOverride.wrap(context, const _SheetBody()),
            ),
          ),
        ),
    ]),
    galleryEntry('AppSheetPage', [
      AppListRowButton(
        title: 'half',
        onPressed: () =>
            unawaited(context.pushNamed(ComponentGalleryPage.sheetName)),
      ),
    ]),
    galleryEntry('AppMenuItem', [
      AppListRow(
        title: 'icon, text only, isDestructive',
        accessory: AppListRowCustom(
          PopupMenuButton<void>(
            tooltip: l10n.devGallerySampleEdit,
            icon: Icon(AppSymbols.more),
            itemBuilder: (_) => [
              AppMenuItem(
                label: l10n.devGallerySampleEdit,
                value: null,
                icon: AppSymbols.edit,
              ),
              AppMenuItem(label: l10n.devGallerySampleSave, value: null),
              AppMenuItem(
                label: l10n.devGallerySampleDelete,
                value: null,
                icon: AppSymbols.delete,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    ]),
    galleryEntry('AppTipCallout', [
      galleryBlock(
        'title, message',
        AppTipCallout(
          title: l10n.tipMetricChartTitle,
          message: l10n.tipMetricChartMessage,
          dismissLabel: l10n.tipGotIt,
          onDismiss: () {},
        ),
      ),
    ]),
    galleryEntry(
      'AppTip',
      const [_TipDemo()],
      note:
          'An AppTipScope shows its first new AppTip a second after the '
          'screen settles, once per visit. Here it is never seen.',
    ),
  ];
}

/// A row that, once asked, carries a tip its [AppTipScope] shows.
class _TipDemo extends StatefulWidget {
  const new();

  @override
  State<_TipDemo> createState() => _TipDemoState();
}

class _TipDemoState extends State<_TipDemo> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = AppListRowButton(
      title: 'show the tip',
      accessory: null,
      onPressed: _on ? null : () => setState(() => _on = true),
    );
    if (!_on) return row;
    return AppTipScope(
      tips: const ['gallery'],
      isSeen: (_) => false,
      onShown: (_) {},
      onDismissed: (_) => setState(() => _on = false),
      dismissLabel: l10n.tipGotIt,
      child: AppTip(
        id: 'gallery',
        title: l10n.tipMetricChartTitle,
        message: l10n.tipMetricChartMessage,
        child: row,
      ),
    );
  }
}

/// [AppEmptyState], [AppErrorState], [AppLoadingView], [AppSpinner],
/// [AppPlaceholder] and [AppPlaceholderRow].
List<Widget> galleryStates(BuildContext context) {
  final l10n = context.l10n;
  return [
    galleryEntry('AppEmptyState', [
      galleryBlock(
        'description, action',
        AppEmptyState(
          icon: AppSymbols.workout,
          title: l10n.devGallerySampleEmptyTitle,
          description: l10n.devGallerySampleMessage,
          actionLabel: l10n.devGallerySampleAction,
          onAction: galleryNoop,
        ),
      ),
      galleryBlock(
        'title',
        AppEmptyState(
          icon: AppSymbols.search,
          title: l10n.devGallerySampleEmptyTitle,
        ),
      ),
    ]),
    galleryEntry('AppErrorState', [
      galleryBlock(
        'description, action',
        AppErrorState(
          title: l10n.devGallerySampleErrorTitle,
          description: l10n.devGallerySampleMessage,
          actionLabel: l10n.devGallerySampleRetry,
          onAction: galleryNoop,
        ),
      ),
    ]),
    galleryEntry('AppLoadingView', [
      galleryBlock(
        'label',
        AppLoadingView(label: l10n.devGallerySampleLoading),
      ),
    ]),
    galleryEntry('AppSpinner', [
      galleryBlock('regular', const AppSpinner()),
      galleryBlock('small', const AppSpinner(size: AppSpinnerSize.small)),
      galleryBlock(
        'color: onSurfaceVariant',
        AppSpinner(
          size: AppSpinnerSize.small,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ]),
    galleryEntry('AppPlaceholderRow', [
      AppPlaceholderRow(semanticLabel: l10n.devGallerySampleLoading),
      const AppPlaceholderRow(hasLeading: true),
      const AppPlaceholderRow(hasSubtitle: false),
    ], note: 'default, hasLeading, hasSubtitle: false'),
    galleryEntry('AppPlaceholder', [
      galleryBlock(
        'height: AppChartHeight.compact',
        const AppPlaceholder(height: AppChartHeight.compact),
      ),
      galleryBlock(
        'width, radius',
        const AppPlaceholder(
          height: AppControlSize.icon,
          width: AppChartHeight.compact,
          radius: AppRadius.l,
        ),
      ),
    ]),
  ];
}

/// [AppCard], [AppCarousel], [AppStat], [AppStatTile], [AppSummaryCard],
/// [AppChip], [AppConfetti], [AppFootnote], [AppInlineMessage],
/// [AppMarkdownText] and [AppViewfinder].
List<Widget> galleryContent(BuildContext context) {
  final l10n = context.l10n;
  final colors = context.appColors;
  final locale = context.dateLocale;
  final weight = AppFormat.weight(
    82.5,
    AppWeightUnit.kilograms,
    locale: locale,
  );
  final kcal = AppFormat.kcal(1850, locale: locale);
  Widget padded(Widget child) =>
      Padding(padding: const EdgeInsets.all(AppSpacing.l), child: child);
  return [
    // Cards sit on the canvas, as on a screen: inside a section's card
    // they would vanish.
    for (final (caption, style) in [
      ('AppCard: card', AppCardStyle.card),
      ('AppCard: tile', AppCardStyle.tile),
      ('AppCard: tinted', AppCardStyle.tinted(colors.protein)),
    ])
      AppCard(style: style, child: padded(Text(caption))),
    galleryEntry('AppCarousel', [
      galleryBlock(
        'three pages',
        AppCarousel(
          height: 120,
          pages: [
            for (final label in [
              l10n.devGallerySampleDay,
              l10n.devGallerySampleWeek,
              l10n.devGallerySampleMonth,
            ])
              AppCard(
                style: AppCardStyle.tile,
                child: Center(child: Text(label)),
              ),
          ],
        ),
      ),
    ]),
    galleryEntry('AppStat', [
      for (final size in AppStatSize.values)
        galleryBlock(
          size.name,
          AppStat(
            value: weight,
            label: l10n.devGallerySampleWeight,
            size: size,
          ),
        ),
      galleryBlock(
        'icon, tint, centre',
        AppStat(
          value: kcal,
          label: l10n.devGallerySampleTitle,
          icon: AppSymbols.calories,
          tint: colors.calories,
          alignment: CrossAxisAlignment.center,
        ),
      ),
    ]),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.l,
      children: [
        Expanded(
          child: AppStatTile(value: weight, label: 'AppStatTile'),
        ),
        Expanded(
          child: AppStatTile(
            value: kcal,
            label: 'AppStatTile: small, icon, tint',
            icon: AppSymbols.calories,
            tint: colors.calories,
            size: AppStatSize.small,
          ),
        ),
      ],
    ),
    galleryEntry('AppSummaryCard', [
      galleryBlock(
        'value, unit, delta, footer, onTap',
        AppSummaryCard(
          title: l10n.devGallerySampleTitle,
          icon: AppSymbols.calories,
          tint: colors.calories,
          value: AppFormat.number(1850, locale: locale),
          unit: 'kcal',
          delta: AppChip(label: l10n.devGallerySampleShortAction),
          footer: l10n.devGallerySampleSubtitle,
          onTap: () {},
        ),
      ),
      galleryBlock(
        'size: hero, chart beside, goal met',
        AppSummaryCard(
          title: l10n.devGallerySampleTitle,
          icon: AppSymbols.today,
          tint: colors.accentInk,
          value: '4/4',
          size: AppSummaryCardSize.hero,
          delta: AppChip(
            label: l10n.devGallerySampleShortAction,
            icon: AppSymbols.success,
            selected: true,
          ),
          chart: const SizedBox.square(
            dimension: 72,
            child: CircularProgressIndicator(value: 1),
          ),
          chartBeside: true,
        ),
      ),
      galleryBlock(
        'size: large, rows',
        AppSummaryCard(
          title: l10n.devGallerySampleTitle,
          value: '6',
          unit: 'weeks',
          size: AppSummaryCardSize.large,
          rows: [
            AppListRowButton(
              title: l10n.devGallerySampleSubtitle,
              onPressed: () {},
            ),
          ],
        ),
      ),
      galleryBlock(
        'chart only, trailing chip',
        AppSummaryCard(
          title: l10n.devGallerySampleTitle,
          chart: const LinearProgressIndicator(value: 0.6),
          semanticValue: '60%',
          trailing: AppChip(
            label: l10n.devGallerySampleShortAction,
            onPressed: () {},
          ),
        ),
      ),
    ]),
    galleryEntry('AppChip', [
      galleryInline('label', AppChip(label: l10n.devGallerySampleTextAction)),
      galleryInline(
        'icon, tint',
        AppChip(
          label: l10n.devGallerySampleTitle,
          icon: AppSymbols.protein,
          tint: colors.protein,
        ),
      ),
      galleryInline(
        'onPressed, selected',
        GalleryLive(
          initial: true,
          builder: (selected, update) => AppChip(
            label: l10n.devGallerySampleShortAction,
            selected: selected,
            onPressed: () => update(!selected),
          ),
        ),
      ),
      galleryInline(
        'size: large, onPressed, selected',
        GalleryLive(
          initial: false,
          builder: (selected, update) => AppChip(
            label: l10n.devGallerySampleShortAction,
            icon: AppSymbols.filter,
            size: AppChipSize.large,
            selected: selected,
            onPressed: () => update(!selected),
          ),
        ),
      ),
    ]),
    galleryEntry('AppConfetti', [
      // A new burst on each tap: the count keys a fresh one.
      galleryInline(
        'playsOnMount',
        GalleryLive(
          initial: 0,
          builder: (bursts, update) => AppConfetti(
            key: ValueKey(bursts),
            playsOnMount: bursts > 0,
            child: AppChip(
              label: l10n.devGallerySampleShortAction,
              icon: AppSymbols.success,
              onPressed: () => update(bursts + 1),
            ),
          ),
        ),
      ),
    ]),
    galleryEntry('AppFootnote', [
      galleryBlock(
        'lines, one with ⓘ',
        AppFootnote(
          lines: [
            AppFootnoteLine(
              l10n.devGallerySampleMessage,
              infoLabel: l10n.infoLabel,
              onInfo: () {},
            ),
            AppFootnoteLine(l10n.devGallerySampleSubtitle),
          ],
        ),
      ),
    ]),
    galleryEntry('AppInlineMessage', [
      for (final (kind, label) in [
        (AppInlineMessageKind.error, l10n.errorLabel),
        (AppInlineMessageKind.warning, l10n.warningLabel),
        (AppInlineMessageKind.info, l10n.infoLabel),
      ])
        galleryBlock(
          kind.name,
          AppInlineMessage(
            kind: kind,
            kindLabel: label,
            text: l10n.devGallerySampleMessage,
          ),
        ),
    ]),
    galleryEntry('AppMarkdownText', [
      galleryBlock(
        'an answer',
        padded(
          const AppMarkdownText(
            '## What to try\n\nYour trend is down **0.1 kg a week**, '
            '*slower* than planned.\n\n- Log every meal\n- Weigh in each '
            'morning\n\n1. Check in on `Sunday`',
          ),
        ),
      ),
      galleryBlock(
        'streaming',
        padded(
          const AppMarkdownText(
            'Your trend is **down 0.4 kg a week**, *a little fast',
            streaming: true,
          ),
        ),
      ),
    ]),
    galleryEntry('AppViewfinder', [
      galleryBlock('opening', const AppViewfinder()),
      galleryBlock(
        'live, action',
        AppViewfinder(
          preview: Image.asset(samplePhotoAsset, fit: BoxFit.cover),
          caption: l10n.labelHoldInFrame,
          action: AppIconButton(
            icon: AppSymbols.torchOff,
            semanticLabel: l10n.torchTurnOn,
            onPressed: () {},
          ),
        ),
      ),
      galleryBlock(
        'busy',
        AppViewfinder(caption: l10n.labelReading, busy: true),
      ),
    ]),
  ];
}

/// A tab root: a large title, a dashboard of sections and a bottom CTA.
class _SampleTabRoot extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = context.dateLocale;
    return AppScaffold(
      largeTitle: l10n.tabToday,
      maxWidth: AppContentWidth.dashboard,
      actions: [
        AppToolbarButton.avatar(
          semanticLabel: l10n.devGallerySampleProfile,
          initials: 'AC',
          onPressed: galleryNoop,
        ),
      ],
      body: AppDashboard(
        sections: [
          for (var i = 0; i < 4; i++)
            AppSection(
              header: l10n.devGallerySampleTitle,
              trailing: AppChip(
                label: l10n.devGallerySampleTextAction,
                onPressed: galleryNoop,
              ),
              children: [
                AppListRowButton(
                  title: l10n.devGallerySampleTitle,
                  subtitle: l10n.devGallerySampleSubtitle,
                  icon: AppSymbols.workout,
                  onPressed: galleryNoop,
                ),
                AppListRow(
                  title: l10n.devGallerySampleWeight,
                  accessory: AppListRowValue(
                    AppFormat.weight(
                      82.5,
                      AppWeightUnit.kilograms,
                      locale: locale,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            label: l10n.devGallerySampleAction,
            onPressed: galleryNoop,
          ),
          AppCtaButton(
            label: l10n.devGallerySampleTextAction,
            variant: AppCtaVariant.plain,
            onPressed: galleryNoop,
          ),
        ],
      ),
    );
  }
}

/// An onboarding step with progress, a choice and both actions.
class _SampleOnboardingStep extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    return AppOnboardingStepScaffold(
      title: l10n.devGallerySampleLongTitle,
      subtitle: l10n.devGallerySampleMessage,
      progress: 0.4,
      progressLabel: AppFormat.percent(0.4, locale: context.dateLocale),
      primaryLabel: l10n.devGallerySampleAction,
      onPrimaryPressed: navigator.pop,
      secondaryLabel: l10n.devGallerySampleTextAction,
      onSecondaryPressed: navigator.pop,
      onBack: navigator.pop,
      children: [
        GalleryLive(
          initial: 0,
          builder: (selected, update) => AppSection(
            children: [
              for (final (index, label) in [
                l10n.devGallerySampleDay,
                l10n.devGallerySampleWeek,
                l10n.devGallerySampleMonth,
              ].indexed)
                AppSelectableRow(
                  title: label,
                  selected: selected == index,
                  onPressed: () => update(index),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A sheet's content: a list that drags the sheet as it scrolls.
class _SheetBody extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        AppSection(
          header: l10n.devGallerySampleTitle,
          footer: l10n.devGallerySampleMessage,
          children: [
            for (var i = 0; i < 12; i++)
              AppListRow(
                title: l10n.devGallerySampleTitle,
                subtitle: l10n.devGallerySampleSubtitle,
              ),
          ],
        ),
      ],
    );
  }
}

/// [AppSheetPage]'s content, for its route under the gallery.
class GallerySheetContent extends StatelessWidget {
  /// The sample sheet.
  const new({super.key});

  @override
  Widget build(BuildContext context) => const _SheetBody();
}
