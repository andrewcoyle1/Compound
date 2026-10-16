import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';
import 'package:intl/intl.dart';
import 'package:social_repository/social_repository.dart';

/// A person's picture, falling back to the person glyph (`UserAvatarView`).
/// Hidden from screen readers: the name beside it says who this is.
class UserAvatar extends StatelessWidget {
  const new({
    required this.imageUrl,
    this.size = AppControlSize.row,
    super.key,
  });

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      AppSymbols.profile,
      size: size,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final url = imageUrl;
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: url == null
              ? placeholder
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

/// `@handle` under a name; nothing for someone without one
/// (`UsernameLabel`).
class UsernameLabel extends StatelessWidget {
  const new({required this.username, super.key});

  final String? username;

  @override
  Widget build(BuildContext context) {
    final username = this.username;
    if (username == null || username.isEmpty) return const SizedBox.shrink();
    return Text(
      '@$username',
      style: AppTextStyles.label.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A person in a list: picture, name and handle, and whatever the screen
/// puts at the trailing edge (`UserRowView`). Tapping opens [onPressed].
class UserRow extends StatelessWidget {
  const new({
    required this.user,
    required this.onPressed,
    this.trailing,
    super.key,
  });

  final UserModel user;
  final VoidCallback onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        child: Row(
          spacing: AppSpacing.m,
          children: [
            UserAvatar(imageUrl: profileImageOf(user)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listNameOf(user) ?? context.l10n.socialUnknown,
                    style: AppTextStyles.rowTitle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  UsernameLabel(username: user.username),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The Follow, Following or Requested pill (`FollowButton`). Follow is the
/// primary action, so it is filled; the others are outlined.
class FollowButton extends StatelessWidget {
  const new({required this.state, required this.onPressed, super.key});

  final FollowState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = Text(switch (state) {
      FollowState.follow => l10n.socialFollow,
      FollowState.following => l10n.socialFollowing,
      FollowState.requested => l10n.socialRequested,
    });
    final button = state == FollowState.follow
        ? FilledButton(onPressed: onPressed, child: label)
        : OutlinedButton(onPressed: onPressed, child: label);
    return Semantics(
      hint: state == FollowState.requested
          ? l10n.socialCancelRequestHint
          : null,
      child: button,
    );
  }
}

/// Who wrote a workout and when, opening their profile
/// (`AuthorHeaderView`).
class AuthorHeader extends StatelessWidget {
  const new({
    required this.author,
    required this.date,
    required this.onPressed,
    super.key,
  });

  final UserModel author;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = fullNameOf(author);
    return Semantics(
      button: true,
      hint: context.l10n.socialOpensProfile,
      child: InkWell(
        onTap: onPressed,
        child: Row(
          spacing: AppSpacing.m,
          children: [
            UserAvatar(
              imageUrl: profileImageOf(author),
              size: AppControlSize.thumbnail,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (name != null)
                        Text(
                          name,
                          style: AppTextStyles.rowDetail.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      UsernameLabel(username: author.username),
                    ],
                  ),
                  Text(
                    DateFormat.yMMMd(locale).add_jm().format(date.toLocal()),
                    style: AppTextStyles.label.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A centred message with an icon, title, text and optional action: the
/// `ContentUnavailableView` of the social screens.
class SocialEmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final message = this.message;
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s,
        children: [
          Icon(icon, size: AppIconSize.large.of(context), color: secondary),
          Text(
            title,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          if (message != null)
            Text(
              message,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
          ?action,
        ],
      ),
    );
  }
}

/// A section's title, with an optional action at its trailing edge
/// (`SectionHeaderView`).
class SocialSectionHeader extends StatelessWidget {
  const new({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.s,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppTextStyles.sectionTitle),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// A person to tick, with their picture and full name: challenge members
/// and share recipients. Announced as selected when ticked.
class SelectablePersonRow extends StatelessWidget {
  const new({
    required this.user,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final UserModel user;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onPressed,
          child: AppListRow(
            title: fullNameOf(user) ?? context.l10n.socialUser,
            thumbnail: UserAvatar(
              imageUrl: profileImageOf(user),
              size: AppControlSize.thumbnail,
            ),
            accessory: AppListRowCheckmark(selected: selected),
          ),
        ),
      ),
    );
  }
}
