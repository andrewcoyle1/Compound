import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/mesocycle_design_page.dart';
import 'package:compound/programs/view/mesocycle_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// The first step of building a mesocycle (Swift `NameMesocycleView`): its
/// name, today's date to begin with. Opened as the flow's first screen, so
/// it has the close button; from onboarding's Build My Own it is pushed
/// [inPlace], with a back button, and each step pushes the next itself, as
/// onboarding allows no other route.
class NameMesocyclePage extends StatefulWidget {
  const new({this.inPlace = false, super.key});

  /// Onboarding's Build My Own: the steps push one another in place.
  final bool inPlace;

  /// Opens the flow from onboarding's program step (Swift
  /// `CreateMesocycleDelegate(onComplete:)`); activating its mesocycle
  /// moves onboarding on.
  static Future<void> openInPlace(BuildContext context) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => const NameMesocyclePage(inPlace: true),
        ),
      );

  /// The path under the Training tab.
  static const path = 'create-mesocycle';

  /// The route name.
  static const name = 'createMesocycle';

  /// Opens the create flow.
  static Future<void> open(BuildContext context) => context.pushNamed(name);

  @override
  State<NameMesocyclePage> createState() => _NameMesocyclePageState();
}

class _NameMesocyclePageState extends State<NameMesocyclePage> {
  static const _screen = 'NameProgramView';

  late final ProgramsCubit _cubit;

  /// Today as `yyyy-MM-dd`, as Swift's `formattedDate` writes it.
  late final _name = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );

  String get _trimmed => _name.text.trim();

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProgramsCubit>()..appeared(_screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(_screen);
    _name.dispose();
    super.dispose();
  }

  void _continue() {
    if (_trimmed.isEmpty) return;
    if (widget.inPlace) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MesocycleIconPage(mesocycleName: _trimmed, inPlace: true),
        ),
      );
      return;
    }
    unawaited(
      context.pushNamed(
        MesocycleIconPage.name,
        queryParameters: {MesocycleIconPage.nameParameter: _trimmed},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: widget.inPlace
            ? null
            : IconButton(
                icon: const Icon(AppSymbols.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => context.pop(),
              ),
        title: Text(l10n.programCreateMesocycle),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            AppSection(
              header: l10n.programMesocycleNameHeader,
              footer: l10n.programMesocycleNameFooter,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    key: const Key('NameProgram.name'),
                    controller: _name,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: l10n.programMesocycleNameHint,
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _continue(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            key: const Key('NameProgram.continue'),
            label: l10n.programContinue,
            onPressed: _trimmed.isEmpty ? null : _continue,
          ),
        ],
      ),
    );
  }
}

/// The second step (Swift `MesocycleIconView`): its colour and icon, then
/// the days.
class const MesocycleIconPage({
  required final String mesocycleName,

  /// Onboarding's Build My Own: the design step is pushed in place.
  final bool inPlace = false,
  super.key,
}) extends StatefulWidget {
  /// The path under the name step.
  static const path = 'icon';

  /// The route name.
  static const name = 'createMesocycleIcon';

  /// The query parameter holding the name chosen.
  static const nameParameter = 'name';

  @override
  State<MesocycleIconPage> createState() => _MesocycleIconPageState();
}

class _MesocycleIconPageState extends State<MesocycleIconPage> {
  static const _screen = 'ProgramIconView';

  late final ProgramsCubit _cubit;
  String _colour = mesocycleColours.first;
  String _icon = mesocycleIcons.first;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProgramsCubit>()..appeared(_screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(_screen);
    super.dispose();
  }

  Future<void> _continue() async {
    final l10n = context.l10n;
    // Reachable: the user can be signed out under the flow.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) {
      await showFailureAlert(
        context,
        l10n.programCreateFailed,
        l10n.programTryAgain,
      );
      return;
    }
    final mesocycle = newMesocycle(
      id: newUuid(),
      authorId: state.user.uid,
      name: widget.mesocycleName,
      icon: _icon,
      colour: _colour,
      now: DateTime.now(),
    );
    if (widget.inPlace) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MesocycleDesignPage(draft: mesocycle),
        ),
      );
      return;
    }
    await context.pushNamed(MesocycleDesignPage.createName, extra: mesocycle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(title: Text(l10n.programCreateMesocycle)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Text(
                l10n.programChooseIcon,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            MesocycleColourIconGrid(
              colour: _colour,
              icon: _icon,
              onColourPressed: (colour) => setState(() => _colour = colour),
              onIconPressed: (icon) => setState(() => _icon = icon),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            key: const Key('ProgramIcon.continue'),
            label: l10n.programContinue,
            onPressed: () => unawaited(_continue()),
          ),
        ],
      ),
    );
  }
}
