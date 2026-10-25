import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/notifications/inbox/view/notification_titles.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A notification that just arrived, over the top of whatever screen is up
/// for four seconds (Swift's `ActivityNotificationBannerView` in
/// `AppView`): a tap opens the inbox, a flick up puts it away, and a
/// screen reader is told.
class ActivityBannerOverlay extends StatefulWidget {
  const new({required this.child, required this.onOpen, super.key});

  /// The app beneath.
  final Widget child;

  /// Opens the inbox.
  final VoidCallback onOpen;

  /// How long a banner stays (`AppPresenter.activityBannerDuration`).
  static const duration = Duration(seconds: 4);

  @override
  State<ActivityBannerOverlay> createState() => _ActivityBannerOverlayState();
}

class _ActivityBannerOverlayState extends State<ActivityBannerOverlay> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss(String id) =>
      context.read<InboxBloc>().add(InboxBannerDismissed(id));

  void _open(String id) {
    _dismiss(id);
    widget.onOpen();
  }

  void _shown(BuildContext context, InboxState state) {
    final banner = state.banner;
    _timer?.cancel();
    if (banner == null) return;
    _timer = Timer(ActivityBannerOverlay.duration, () => _dismiss(banner.id));
    // It appears over whatever the person is doing, so a screen reader
    // has to be told.
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        notificationTitle(context.l10n, banner),
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return BlocConsumer<InboxBloc, InboxState>(
      listenWhen: (previous, current) => previous.banner != current.banner,
      listener: _shown,
      buildWhen: (previous, current) => previous.banner != current.banner,
      builder: (context, state) {
        final banner = state.banner;
        return Stack(
          children: [
            widget.child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AnimatedSwitcher(
                  duration: AppMotion.standard.durationOf(context),
                  switchInCurve: AppMotion.standard.curve,
                  switchOutCurve: AppMotion.standard.curve,
                  child: banner == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(banner.id),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.s,
                            AppSpacing.xl,
                            0,
                          ),
                          // One element: the message, opening the inbox.
                          child: Semantics(
                            container: true,
                            button: true,
                            label: notificationTitle(l10n, banner),
                            hint: l10n.activityBannerHint,
                            onTap: () => _open(banner.id),
                            excludeSemantics: true,
                            child: GestureDetector(
                              onVerticalDragEnd: (details) {
                                if ((details.primaryVelocity ?? 0) < 0) {
                                  _dismiss(banner.id);
                                }
                              },
                              child: Material(
                                color: scheme.surfaceContainerHigh,
                                elevation: 6,
                                shape: const RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(AppRadius.xl),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AppPressable(
                                  key: const Key('ActivityBanner'),
                                  onTap: () => _open(banner.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.l,
                                      vertical: AppSpacing.m,
                                    ),
                                    child: Row(
                                      spacing: AppSpacing.m,
                                      children: [
                                        ExcludeSemantics(
                                          child: Icon(
                                            AppSymbols.notifications,
                                            size: AppIconSize.small.of(context),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            notificationTitle(l10n, banner),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.rowDetail,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
