import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:social_repository/social_repository.dart';

/// The row of faces over the feed: who in the circle has trained today,
/// each with a ring for the week's sessions (`CircleActivityStripView`).
/// Nudge is a visible button under a greyed face, not a hidden menu.
class CircleStrip extends StatelessWidget {
  const new({
    required this.members,
    required this.onMemberPressed,
    required this.onNudgePressed,
    this.onSetGoalPressed,
    super.key,
  });

  final List<CircleMember> members;
  final ValueChanged<CircleMember> onMemberPressed;
  final ValueChanged<CircleMember> onNudgePressed;

  /// Shown under the reader's own face while they have no weekly goal.
  final VoidCallback? onSetGoalPressed;

  @override
  Widget build(BuildContext context) {
    // Grows with the text so "Nudge" and the name keep to one line.
    final width = MediaQuery.textScalerOf(context).scale(76);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.l,
        children: [
          for (final member in members)
            SizedBox(
              width: width,
              child: _MemberCell(
                member: member,
                onPressed: () => onMemberPressed(member),
                onNudgePressed: () => onNudgePressed(member),
                onSetGoalPressed: member.isCurrentUser
                    ? onSetGoalPressed
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberCell extends StatelessWidget {
  const new({
    required this.member,
    required this.onPressed,
    required this.onNudgePressed,
    required this.onSetGoalPressed,
  });

  final CircleMember member;
  final VoidCallback onPressed;
  final VoidCallback onNudgePressed;
  final VoidCallback? onSetGoalPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = commonNameOf(member.user) ?? l10n.socialUnknown;
    final toGo = member.sessionsToGo;
    final onSetGoalPressed = this.onSetGoalPressed;
    return Column(
      spacing: AppSpacing.xs,
      children: [
        Semantics(
          button: true,
          hint: l10n.socialOpensProfile,
          label: member.trainedToday
              ? l10n.socialMemberTrained(
                  name,
                  member.sessionsThisWeek,
                  member.weeklyGoal,
                )
              : l10n.socialMemberNotTrained(
                  name,
                  member.sessionsThisWeek,
                  member.weeklyGoal,
                ),
          excludeSemantics: true,
          child: AppPressable(
            onTap: onPressed,
            shape: const CircleBorder(),
            child: Column(
              spacing: AppSpacing.xs,
              children: [
                _RingedAvatar(member: member),
                Text(
                  toGo != null
                      ? l10n.socialToGo(toGo)
                      : firstNameOf(member.user) ?? name,
                  style: toGo != null
                      ? AppTextStyles.label.semibold
                      : member.trainedToday
                      ? AppTextStyles.label
                      : AppTextStyles.label.secondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (member.canNudge)
          Semantics(
            label: l10n.socialNudgeLabel(name),
            excludeSemantics: true,
            button: true,
            child: AppCtaButton(
              label: l10n.socialNudge,
              size: AppCtaSize.compact,
              variant: AppCtaVariant.secondary,
              onPressed: onNudgePressed,
            ),
          ),
        if (onSetGoalPressed != null)
          Semantics(
            label: l10n.socialSetGoalLabel,
            excludeSemantics: true,
            button: true,
            child: AppCtaButton(
              label: l10n.socialSetGoal,
              size: AppCtaSize.compact,
              variant: AppCtaVariant.secondary,
              onPressed: onSetGoalPressed,
            ),
          ),
      ],
    );
  }
}

/// The face, greyed until they train today, inside the week's ring, with a
/// check once trained.
class _RingedAvatar extends StatelessWidget {
  const new({required this.member});

  final CircleMember member;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    const avatar = 52.0;
    const ring = 3.0;
    final progress = member.progress;
    final face = UserAvatar(
      imageUrl: profileImageOf(member.user),
      size: avatar,
    );
    return SizedBox.square(
      dimension: avatar + AppSpacing.xs * 2 + ring,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: ring,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
              // Done is the accent: a closed ring stays in it.
              color: colors.accentInk,
            ),
          ),
          if (member.trainedToday)
            face
          else
            Opacity(
              opacity: 0.5,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_greyscale),
                child: face,
              ),
            ),
          if (member.trainedToday)
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const CircleBorder(),
                  color: colors.canvas,
                ),
                child: const AppDoneMark(size: AppIconSize.small),
              ),
            ),
        ],
      ),
    );
  }
}

const _greyscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];
