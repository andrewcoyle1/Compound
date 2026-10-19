import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/view/coach_surface.dart';
import 'package:compound/l10n/l10n.dart';

/// One message of the conversation, in its bubble: the user's on the
/// trailing side in the accent's tint, the coach's on the leading side,
/// its markdown set as text ([AppMarkdownText]). An answer's [blocks]
/// follow its text, in order, full width ([CoachSurface]).
///
/// The one place a message is drawn.
class CoachMessageBody extends StatelessWidget {
  const new({
    required this.role,
    required this.text,
    required this.onFollowUp,
    this.blocks = const [],
    this.saved = false,
    super.key,
  });

  final CoachMessageRole role;
  final String text;

  /// The answer's blocks.
  final List<CoachBlock> blocks;

  /// Whether the message is from a saved chat, so its blocks are dated.
  final bool saved;

  /// Sends a block's follow-up question.
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isUser = role == CoachMessageRole.user;
    final plain = AppMarkdownText.plainText(text);
    final bubble = Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.tintedSurface(Theme.of(context).colorScheme.primary)
            : context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: AppMarkdownText(text),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.m,
      children: [
        if (text.isNotEmpty)
          Semantics(
            label: isUser
                ? l10n.coachYouSaid(plain)
                : l10n.coachCoachSaid(plain),
            excludeSemantics: true,
            child: Row(
              children: [
                if (isUser) const SizedBox(width: AppSpacing.xxl),
                Flexible(
                  child: Align(
                    alignment: isUser
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: bubble,
                  ),
                ),
                if (!isUser) const SizedBox(width: AppSpacing.xxl),
              ],
            ),
          ),
        for (final block in blocks)
          CoachSurface(
            key: ValueKey(block.surfaceId),
            block: block,
            saved: saved,
            onFollowUp: onFollowUp,
          ),
      ],
    );
  }
}
