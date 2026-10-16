import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/share_card/share_card_content.dart';
import 'package:compound/sharing/share_card/share_card_renderer.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Draws [session]'s card in [format] and hands it to the share sheet
/// (`WorkoutSessionRowPresenter.onShareImagePressed`); says so when the
/// image cannot be made. [history] is the author's own sessions, for the
/// records and the weekly count. Tracks `<eventPrefix>_ShareImage_*` when
/// given, as the feed card does.
Future<void> shareWorkoutCard(
  BuildContext context,
  WorkoutSessionModel session, {
  required UserModel? author,
  required List<WorkoutSessionModel> history,
  required ShareCardFormat format,
  String? eventPrefix,
}) async {
  final l10n = context.l10n;
  final analytics = context.read<AnalyticsRepository>();
  final shareSheet = context.read<ShareSheet>();
  final messenger = ScaffoldMessenger.of(context);
  void track(String outcome, [LogType type = LogType.analytic]) {
    if (eventPrefix != null) {
      analytics.trackEvent(
        AnalyticsEvent('${eventPrefix}_ShareImage_$outcome', type: type),
      );
    }
  }

  final content = ShareCardContent.fromHistory(
    l10n,
    session,
    author: author,
    history: history,
    firstDayOfWeek: firstDayOfWeekIndex(context),
    locale: Localizations.localeOf(context).toLanguageTag(),
  );
  final accent = Theme.of(context).colorScheme.primary;
  track('Start');
  final avatar = await loadShareCardImage(context, content.avatarUrl);
  if (!context.mounted) return;
  final png = await renderShareCard(
    context,
    WorkoutShareCard(
      content: content,
      format: format,
      accent: accent,
      l10n: l10n,
      avatar: avatar,
    ),
    size: format.size,
  );
  if (png == null || !context.mounted) {
    track('Fail', LogType.severe);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${l10n.shareImageFailed}. ${l10n.socialTryAgain}'),
        ),
      );
    return;
  }
  track('Success');
  await shareSheet.shareImage(context, png, name: 'compound-workout.png');
}

/// Share Image and its two formats, Story and Square, as a submenu.
SubmenuButton shareImageSubmenu(
  AppLocalizations l10n,
  ValueChanged<ShareCardFormat> onSelected,
) => SubmenuButton(
  leadingIcon: Icon(AppSymbols.share),
  menuChildren: [
    for (final (format, title) in [
      (ShareCardFormat.story, l10n.shareImageStory),
      (ShareCardFormat.square, l10n.shareImageSquare),
    ])
      MenuItemButton(onPressed: () => onSelected(format), child: Text(title)),
  ],
  child: Text(l10n.shareImage),
);
