import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/undo/pending_deletes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How long an Undo stays on screen: past the 5 seconds people need to
/// notice a mistake and reach for it.
const undoWindow = Duration(seconds: 6);

/// How long an Undo snack bar stays here: [undoWindow], or until dismissed
/// when a screen reader or switch control is driving, which take longer to
/// reach it.
Duration? undoDuration(BuildContext context) =>
    MediaQuery.accessibleNavigationOf(context) ? null : undoWindow;

/// Deletes something at once, with an Undo, instead of asking first.
///
/// [key] (its document path) is hidden from the lists right away through
/// [PendingDeletes], and a snack bar says [message] with Undo. Undo shows it
/// again and writes nothing; any other way the snack bar goes (its time
/// running out, a swipe, another snack bar) runs [commit]. If [commit]
/// throws, the item shows again and a snack bar says [failedMessage].
///
/// [commit] runs after this screen may have gone, so it uses repositories,
/// never a cubit. Use it only for the user's own single item that can be
/// written back as it was; an irreversible, bulk or shared action still
/// confirms with `AppDialog.confirmDestructive`.
AppSnackBarHandle showUndoableDelete(
  BuildContext context, {
  required String key,
  required String message,
  required String failedMessage,
  required Future<void> Function() commit,
  VoidCallback? onUndo,
}) {
  final pending = context.read<PendingDeletes>();
  final snackBars = AppSnackBarScope.of(context);
  pending.schedule(key, commit);
  unawaited(AppHaptics.success());
  return snackBars.show(
    message,
    action: AppSnackBarAction(
      label: context.l10n.undo,
      onPressed: () {
        pending.undo(key);
        onUndo?.call();
      },
    ),
    duration: undoDuration(context),
    onClosed: (reason) {
      if (reason == AppSnackBarCloseReason.action) return;
      unawaited(
        pending.commit(key).catchError((Object _) {
          unawaited(AppHaptics.error());
          snackBars.show(failedMessage, style: AppSnackBarStyle.error);
        }),
      );
    },
  );
}
