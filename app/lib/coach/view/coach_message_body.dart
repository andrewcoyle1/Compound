import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/view/coach_surface.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

/// Something to do with a message, offered on a long press and to screen
/// readers as a custom action: Copy, Helpful.
typedef CoachMessageAction = (IconData icon, String label, VoidCallback run);

/// One message of the conversation: the user's in a bubble on the trailing
/// side in the accent's tint, the coach's as full-width prose, its markdown
/// set as text ([AppMarkdownText]). An answer's [blocks] follow its text,
/// in order, full width ([CoachSurface]).
///
/// The one place a message is drawn.
class CoachMessageBody extends StatelessWidget {
  const new({
    required this.role,
    required this.text,
    required this.onFollowUp,
    this.blocks = const [],
    this.saved = false,
    this.streaming = false,
    this.actions = const [],
    super.key,
  });

  final CoachMessageRole role;
  final String text;

  /// The answer's blocks.
  final List<CoachBlock> blocks;

  /// Whether the message is from a saved chat, so its blocks are dated.
  final bool saved;

  /// Whether [text] is an answer still streaming in: it is revealed at a
  /// steady pace rather than in the chunks it arrives in.
  final bool streaming;

  /// What a long press on the text offers.
  final List<CoachMessageAction> actions;

  /// Sends a block's follow-up question.
  final ValueChanged<String> onFollowUp;

  /// The actions as a sheet of rows, compact for up to three; the chosen
  /// one runs once the sheet has closed.
  Future<void> _showActions(BuildContext context) async {
    final chosen = await showAppSheet<VoidCallback>(
      context: context,
      size: actions.length > 3 ? AppSheetSize.half : AppSheetSize.compact,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            children: [
              for (final (icon, label, run) in actions)
                AppListRowButton(
                  title: label,
                  icon: icon,
                  accessory: null,
                  onPressed: () => Navigator.of(context).pop(run),
                ),
            ],
          ),
        ],
      ),
    );
    chosen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isUser = role == CoachMessageRole.user;
    final plain = AppMarkdownText.plainText(text, streaming: streaming);
    final body = streaming
        ? _RevealedText(text)
        : AppMarkdownText(text, selectable: false);
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
            customSemanticsActions: {
              for (final (_, label, run) in actions)
                CustomSemanticsAction(label: label): run,
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: actions.isEmpty
                  ? null
                  : () => unawaited(_showActions(context)),
              child: isUser
                  ? Row(
                      children: [
                        const SizedBox(width: AppSpacing.xxl),
                        Flexible(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: AppCard(
                              style: AppCardStyle.tinted(
                                Theme.of(context).colorScheme.primary,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.m),
                                child: body,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : body,
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

/// A streaming answer, revealed a few characters a frame at a steady pace
/// that keeps within about a quarter of a second of what has arrived,
/// instead of a chunk at a time. All of it at once under reduced motion.
class _RevealedText extends StatefulWidget {
  const new(this.text);

  final String text;

  /// The slowest it reveals, in characters a second.
  static const charactersPerSecond = 60;

  /// How far behind what has arrived it may fall.
  static const catchUp = Duration(milliseconds: 250);

  @override
  State<_RevealedText> createState() => _RevealedTextState();
}

class _RevealedTextState extends State<_RevealedText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  int _shown = 0;
  Duration _last = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(_RevealedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    final length = widget.text.length;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ticker.stop();
      _shown = length;
      return;
    }
    _shown = math.min(_shown, length);
    if (_shown < length && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final text = widget.text;
    final behind = text.length - _shown;
    final step = math.max(
      (_RevealedText.charactersPerSecond * seconds).ceil(),
      (behind * seconds * 1e6 / _RevealedText.catchUp.inMicroseconds).ceil(),
    );
    var shown = math.min(_shown + step, text.length);
    // Never between the halves of a surrogate pair, such as an emoji.
    if (shown > 0 &&
        shown < text.length &&
        _isLead(text.codeUnitAt(shown - 1))) {
      shown++;
    }
    setState(() => _shown = shown);
    if (shown == text.length) _ticker.stop();
  }

  static bool _isLead(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppMarkdownText(
    widget.text.substring(0, _shown),
    streaming: true,
    selectable: false,
  );
}
