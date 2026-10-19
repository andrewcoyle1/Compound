import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/account/username/edit_username_bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_repository/social_repository.dart';

/// Choosing a username (Swift `EditUsernameView`), pushed from Edit
/// Profile and from Social's username banner.
class EditUsernamePage extends StatelessWidget {
  const new({super.key});

  /// Over the tabs: `/username`.
  static const path = '/username';

  /// The route name.
  static const name = 'editUsername';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    final viewer = state is AppAuthenticated ? state.profile : null;
    if (viewer == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => EditUsernameBloc(
        social: context.read<SocialRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        connectivity: context.read(),
        current: viewer.username,
      )..appeared(),
      child: EditUsernameView(viewer: viewer),
    );
  }
}

class EditUsernameView extends StatefulWidget {
  const new({required this.viewer, super.key});

  final UserModel viewer;

  @override
  State<EditUsernameView> createState() => _EditUsernameViewState();
}

class _EditUsernameViewState extends State<EditUsernameView> {
  late final EditUsernameBloc _bloc;
  late final _controller = TextEditingController(text: _bloc.state.text);

  @override
  void initState() {
    super.initState();
    _bloc = context.read<EditUsernameBloc>();
  }

  @override
  void dispose() {
    _bloc.disappeared();
    _controller.dispose();
    super.dispose();
  }

  void _save() => _bloc.add(EditUsernameSavePressed(widget.viewer));

  void _onChanged(BuildContext context, EditUsernameState state) {
    if (_controller.text != state.text) {
      _controller.value = TextEditingValue(
        text: state.text,
        selection: TextSelection.collapsed(offset: state.text.length),
      );
    }
    if (state.saved) {
      unawaited(HapticFeedback.mediumImpact());
      if (context.canPop()) context.pop();
    }
  }

  void _onFailure(BuildContext context, EditUsernameState state) {
    final l10n = context.l10n;
    unawaited(HapticFeedback.heavyImpact());
    unawaited(
      showAppDialog<void>(
        context: context,
        title: l10n.usernameSaveFailedTitle,
        message: l10n.usernameSaveFailedMessage,
        actions: [AppDialogAction(label: l10n.settingsOk)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<EditUsernameBloc>().state;
    final scheme = Theme.of(context).colorScheme;
    return MultiBlocListener(
      listeners: [
        BlocListener<EditUsernameBloc, EditUsernameState>(
          listenWhen: (previous, current) =>
              previous.text != current.text || current.saved,
          listener: _onChanged,
        ),
        BlocListener<EditUsernameBloc, EditUsernameState>(
          listenWhen: (previous, current) =>
              previous.failureId != current.failureId,
          listener: _onFailure,
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.usernameTitle),
          actions: [
            AppToolbarButton.confirm(
              semanticLabel: l10n.usernameSave,
              isSaving: state.isSaving,
              onPressed: state.canSave ? _save : null,
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      prefixText: '@',
                      hintText: l10n.usernamePlaceholder,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (text) =>
                        _bloc.add(EditUsernameTextChanged(text, widget.viewer)),
                    onSubmitted: (_) {
                      if (state.canSave) _save();
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  0,
                ),
                child: _Status(
                  state: state,
                  secondary: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const new({required this.state, required this.secondary});

  final EditUsernameState state;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = AppTextStyles.label.copyWith(color: secondary);
    return switch (state.status) {
      UsernameStatus.idle => Text(l10n.usernameIdle, style: style),
      UsernameStatus.current => Text(l10n.usernameCurrent, style: style),
      UsernameStatus.invalid => AppInlineMessage(
        kind: AppInlineMessageKind.warning,
        kindLabel: l10n.usernameTitle,
        text: switch (state.validation) {
          UsernameValidation.tooShort => l10n.usernameTooShort(
            Username.minLength,
          ),
          UsernameValidation.tooLong => l10n.usernameTooLong(
            Username.maxLength,
          ),
          UsernameValidation.edgeDot => l10n.usernameEdgeDot,
          _ => l10n.usernameInvalidCharacters,
        },
      ),
      UsernameStatus.checking => Row(
        spacing: AppSpacing.s,
        children: [
          const SizedBox.square(
            dimension: AppSpacing.l,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          Text(l10n.usernameChecking, style: style),
        ],
      ),
      UsernameStatus.available => Row(
        spacing: AppSpacing.xs,
        children: [
          Icon(
            AppSymbols.success,
            color: context.appColors.success,
            size: AppIconSize.small.of(context),
          ),
          Text(
            l10n.usernameAvailable,
            style: style.copyWith(color: context.appColors.success),
          ),
        ],
      ),
      UsernameStatus.taken => AppInlineMessage(
        kind: AppInlineMessageKind.error,
        kindLabel: l10n.errorLabel,
        text: l10n.usernameTaken,
      ),
      UsernameStatus.failed => Text(l10n.usernameFailed, style: style),
    };
  }
}
