import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:flutter/services.dart';

/// Says that a follow or nudge failed, wherever the user is: a snack bar
/// rather than Swift's alert, since the app shows it from above every
/// screen.
void showCircleNotice(BuildContext context, CircleState state) {
  final l10n = context.l10n;
  final notice = state.notice;
  if (notice == null) return;
  unawaited(HapticFeedback.heavyImpact());
  final title = switch (notice) {
    CircleNotice.followFailed => l10n.socialFollowFailed,
    CircleNotice.unfollowFailed => l10n.socialUnfollowFailed,
    CircleNotice.cancelRequestFailed => l10n.socialCancelRequestFailed,
    CircleNotice.nudgeFailed => l10n.socialNudgeFailed(
      state.noticeName ?? l10n.socialUnknown,
    ),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$title. ${l10n.socialTryAgain}')));
}
