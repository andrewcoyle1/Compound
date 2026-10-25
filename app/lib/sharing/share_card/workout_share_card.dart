import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/share_card/share_card_content.dart';

/// The two shapes a workout card comes in, in points; three times this in
/// pixels (`WorkoutShareCardView.Format`).
enum ShareCardFormat {
  /// 1080 × 1920, for Stories.
  story(Size(360, 640)),

  /// 1080 × 1080, for a post.
  square(Size(360, 360));

  new(this.size);

  final Size size;
}

/// A finished session laid out as an image for Stories or a square post
/// (`WorkoutShareCardView`). A fixed-size image, so it uses its own sizes
/// and colours rather than the app's tokens: white on black with a glow of
/// [accent]. Its strings come from [content], except the stat headers.
class WorkoutShareCard extends StatelessWidget {
  const new({
    required this.content,
    required this.format,
    required this.accent,
    required this.l10n,
    this.avatar,
    super.key,
  });

  final ShareCardContent content;
  final ShareCardFormat format;
  final Color accent;
  final AppLocalizations l10n;

  /// The author's picture, already loaded; an initial stands in without it.
  final ImageProvider? avatar;

  bool get _isStory => format == ShareCardFormat.story;

  @override
  Widget build(BuildContext context) {
    final records = content.personalRecordLines.take(_isStory ? 3 : 2);
    final firstName = content.firstName;
    return ShareCardFrame(
      accent: accent,
      size: format.size,
      padding: _isStory ? 28 : 20,
      bottomInset: _isStory ? 72 : 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _isStory ? 20 : 10,
        children: [
          if (firstName != null || avatar != null)
            Row(
              spacing: 10,
              children: [
                _Avatar(
                  image: avatar,
                  initial: firstName?.characters.first ?? '',
                  size: _isStory ? 44 : 32,
                ),
                if (firstName != null)
                  Flexible(
                    child: Text(
                      firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _isStory ? 17 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                content.sessionName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _isStory ? 34 : 24,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(content.dateText, style: _secondary(15)),
            ],
          ),
          Wrap(
            spacing: _isStory ? 24 : 16,
            runSpacing: 8,
            children: [
              if (content.durationText case final duration?)
                ShareCardStat(
                  header: l10n.statDuration,
                  value: duration,
                  large: _isStory,
                ),
              if (content.volumeText case final volume?)
                ShareCardStat(
                  header: l10n.statVolume,
                  value: volume,
                  large: _isStory,
                ),
              ShareCardStat(
                header: l10n.shareCardSets(content.setCount),
                value: '${content.setCount}',
                large: _isStory,
              ),
            ],
          ),
          if (records.isNotEmpty ||
              content.streakText != null ||
              content.weeklyText != null)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final record in records)
                  _Capsule(
                    text: l10n.shareCardRecord(record),
                    icon: Icons.emoji_events_rounded,
                    tint: Colors.yellow,
                  ),
                if (content.streakText case final streak?)
                  _Capsule(
                    text: streak,
                    icon: Icons.local_fire_department_rounded,
                    tint: Colors.orange,
                  ),
                if (content.weeklyText case final weekly?)
                  _Capsule(
                    text: weekly,
                    icon: Icons.calendar_today_rounded,
                    tint: Colors.lightBlueAccent,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

TextStyle _secondary(double size) =>
    TextStyle(fontSize: size, color: Colors.white.withValues(alpha: 0.75));

/// A share card's background and layout box: black with a glow of [accent],
/// white text, [size] points (shared with the Weekly Review card). The
/// app's mark sits at the top and [child] at the bottom, shrunk to fit if
/// it would not.
class ShareCardFrame extends StatelessWidget {
  const new({
    required this.accent,
    required this.size,
    required this.child,
    this.padding = 28,
    this.bottomInset = 72,
    super.key,
  });

  final Color accent;
  final Size size;
  final Widget child;
  final double padding;

  /// Stories lay their own reply bar over the bottom of the image.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          // Black, with the accent glowing from the top corner and gone by
          // the middle: white text stays at least 8:1 everywhere on it.
          // Volt at full strength behind white text was 1.3:1.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.55],
            colors: [accent.withValues(alpha: 0.35), Colors.black],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            padding,
            padding,
            padding,
            padding + bottomInset,
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const ShareCardMark(),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: size.width - padding * 2,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app icon and "Compound", top left of every card (Swift's
/// `appMark`). `renderShareCard` loads the icon before drawing.
class ShareCardMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const Image(image: AppImages.appIcon, width: 24, height: 24),
        ),
        const Text(
          'Compound',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// A header over a big number.
class ShareCardStat extends StatelessWidget {
  const new({
    required this.header,
    required this.value,
    this.large = true,
    super.key,
  });

  final String header;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          header.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: large ? 24 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const new({required this.image, required this.initial, required this.size});

  final ImageProvider? image;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        image: image == null
            ? null
            : DecorationImage(image: image, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(
              initial,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            )
          : null,
    );
  }
}

class _Capsule extends StatelessWidget {
  const new({required this.text, required this.icon, required this.tint});

  final String text;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 13, color: tint),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
