import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/l10n/l10n.dart';

/// One message of the conversation, in its bubble: the user's on the
/// trailing side in the accent's tint, the coach's on the leading side.
///
/// The one place a message is drawn. Structured content (cards, charts)
/// after 1.0 is an addition to the message model drawn here; nothing else
/// changes.
class CoachMessageBody extends StatelessWidget {
  const new({required this.role, required this.text, super.key});

  final CoachMessageRole role;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isUser = role == CoachMessageRole.user;
    final colors = context.appColors;
    final bubble = Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.tintedSurface(Theme.of(context).colorScheme.primary)
            : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: SelectableText.rich(
        TextSpan(children: coachMarkdown(text)),
        style: AppTextStyles.rowTitle,
      ),
    );
    return Semantics(
      label: isUser ? l10n.coachYouSaid(text) : l10n.coachCoachSaid(text),
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
    );
  }
}

/// The light markdown the model answers in: `**bold**` and `*italic*` (or
/// `_italic_`). Anything else shows as it came, whitespace and list
/// markers included, as Swift's `inlineOnlyPreservingWhitespace`.
// ponytail: bold and italics only; links and code show as typed. Add a
// markdown package if answers start using more.
List<TextSpan> coachMarkdown(String text) {
  final spans = <TextSpan>[];
  var start = 0;
  for (final match in _emphasis.allMatches(text)) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
    }
    final bold = match.group(1);
    spans.add(
      bold != null
          ? TextSpan(
              text: bold,
              style: const TextStyle(fontWeight: FontWeight.w600),
            )
          : TextSpan(
              text: match.group(2) ?? match.group(3),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
    );
    start = match.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

final _emphasis = RegExp(r'\*\*(.+?)\*\*|\*(\S.*?)\*|\b_(\S.*?)_\b');
