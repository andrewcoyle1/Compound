import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// An empty state: an icon, a title and a line under it (Swift
/// `ContentUnavailableView`), as [AppEmptyState] draws it.
class LibraryEmptyState extends StatelessWidget {
  const new({required this.icon, required this.title, this.message, super.key});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) =>
      AppEmptyState(icon: icon, title: title, description: message);
}

/// A failed read, with a way to try again, as [AppErrorState] draws it.
class LibraryFailure extends StatelessWidget {
  const new({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppErrorState(
    title: message,
    actionLabel: context.l10n.tryAgainButton,
    onAction: onRetry,
  );
}

/// A muscle an exercise works. Primary and secondary differ by fill, weight
/// and the spoken label, so the difference never rests on colour alone
/// (Swift `MuscleChip`).
class MuscleChip extends StatelessWidget {
  const new(this.muscle, this.target, {super.key});

  final Muscles muscle;
  final MuscleTargetType target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = l10n.muscleName(muscle);
    final primary = target == MuscleTargetType.primary;
    return Semantics(
      label: primary
          ? l10n.muscleChipPrimary(name)
          : l10n.muscleChipSecondary(name),
      excludeSemantics: true,
      child: AppChip(
        label: name,
        tint: context.appColors.muscleGroups,
        selected: primary,
      ),
    );
  }
}

/// A row of muscle chips that scrolls sideways.
class MuscleChips extends StatelessWidget {
  const new(this.muscles, {super.key});

  final List<(Muscles, MuscleTargetType)> muscles;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          for (final (muscle, target) in muscles) MuscleChip(muscle, target),
        ],
      ),
    );
  }
}

/// Provides a [TrainingLibraryBloc] following [uid]'s library to [child].
class TrainingLibraryProvider extends StatelessWidget {
  const new({required this.uid, required this.child, super.key});

  final String uid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TrainingLibraryBloc(
        libraryRepository: context.read<TrainingLibraryRepository>(),
        programRepository: context.read<ProgramRepository>(),
        uid: uid,
      )..add(const TrainingLibrarySubscriptionRequested()),
      child: child,
    );
  }
}

/// Sections down a screen with the usual gaps.
class LibrarySections extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.l),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
      itemBuilder: (_, index) => children[index],
    );
  }
}
