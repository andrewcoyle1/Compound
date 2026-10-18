import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/cubit/settings_document_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The signed-in user's uid; the router shows settings only while someone
/// is signed in.
String? signedInUid(BuildContext context) =>
    switch (context.read<AppBloc>().state) {
      AppAuthenticated(:final user) => user.uid,
      _ => null,
    };

/// A settings screen over a [SettingsDocumentCubit]: a spinner until the
/// document is read, then [sections] in a list; a failed save says so, as
/// Swift's "Unable to Save Settings" alert does.
class SettingsDocumentScaffold<C extends SettingsDocumentCubit<T>, T>
    extends StatelessWidget {
  const new({required this.title, required this.sections, super.key});

  final String title;

  /// The screen's sections for the document read.
  final List<Widget> Function(BuildContext context, T settings) sections;

  @override
  Widget build(BuildContext context) {
    final settings = context.select<C, T?>((cubit) => cubit.state.settings);
    return BlocListener<C, SettingsDocumentState<T>>(
      listenWhen: (before, after) => after.saveFailures > before.saveFailures,
      listener: (context, _) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.foodLogSettingsSaveFailed)),
        ),
      child: AppScaffold(
        appBar: AppBar(title: Text(title)),
        body: settings == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: [
                    for (final (index, section) in sections(
                      context,
                      settings,
                    ).indexed) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.xl),
                      section,
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// A row showing the choice made, which opens the options in a sheet, as
/// Swift's inline pickers do; [onChanged] gets the option picked.
class ChoiceRow<T> extends StatelessWidget {
  const new({
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final T value;
  final List<T> options;

  /// What an option is called.
  final String Function(T option) label;

  /// What an option means, beneath it in the sheet.
  final String? Function(T option)? subtitle;
  final IconData? icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppListRowButton(
      title: title,
      icon: icon,
      accessory: AppListRowValue(label(value)),
      onPressed: () => unawaited(_choose(context)),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.xl,
        ),
        children: [
          AppSection(
            header: title,
            children: [
              for (final option in options)
                AppSelectableRow(
                  title: label(option),
                  subtitle: subtitle?.call(option),
                  selected: option == value,
                  onPressed: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}
