import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/dev/gallery/gallery_entry.dart';

/// Every [AppColors] colour by name. A test checks it against the class.
final galleryColors = <(String, Color Function(AppColors))>[
  ('canvas', (c) => c.canvas),
  ('surface', (c) => c.surface),
  ('raised', (c) => c.raised),
  ('accentInk', (c) => c.accentInk),
  ('secondaryLabel', (c) => c.secondaryLabel),
  ('tertiaryLabel', (c) => c.tertiaryLabel),
  ('separator', (c) => c.separator),
  ('calories', (c) => c.calories),
  ('protein', (c) => c.protein),
  ('carbs', (c) => c.carbs),
  ('fat', (c) => c.fat),
  ('vitamins', (c) => c.vitamins),
  ('minerals', (c) => c.minerals),
  ('otherNutrients', (c) => c.otherNutrients),
  ('success', (c) => c.success),
  ('warning', (c) => c.warning),
  ('danger', (c) => c.danger),
  ('warmup', (c) => c.warmup),
  ('superset', (c) => c.superset),
  ('personalRecord', (c) => c.personalRecord),
  ('workouts', (c) => c.workouts),
  ('steps', (c) => c.steps),
  ('expenditure', (c) => c.expenditure),
  ('scaleWeight', (c) => c.scaleWeight),
  ('bodyFat', (c) => c.bodyFat),
  ('measurements', (c) => c.measurements),
  ('nutrition', (c) => c.nutrition),
  ('muscleGroups', (c) => c.muscleGroups),
  ('exercises', (c) => c.exercises),
  ('habits', (c) => c.habits),
];

/// The [ColorScheme] roles the theme sets.
final _schemeColors = <(String, Color Function(ColorScheme))>[
  ('primary', (s) => s.primary),
  ('onPrimary', (s) => s.onPrimary),
  ('secondaryContainer', (s) => s.secondaryContainer),
  ('surface', (s) => s.surface),
  ('onSurface', (s) => s.onSurface),
  ('onSurfaceVariant', (s) => s.onSurfaceVariant),
  ('surfaceContainerHighest', (s) => s.surfaceContainerHighest),
  ('surfaceBright', (s) => s.surfaceBright),
  ('outline', (s) => s.outline),
  ('outlineVariant', (s) => s.outlineVariant),
  ('error', (s) => s.error),
];

/// Every [AppSymbols] icon by name. A test checks it against the class.
final gallerySymbols = <(String, IconData)>[
  ('workout', AppSymbols.workout),
  ('exercise', AppSymbols.exercise),
  ('set', AppSymbols.set),
  ('reps', AppSymbols.reps),
  ('weight', AppSymbols.weight),
  ('volume', AppSymbols.volume),
  ('equipment', AppSymbols.equipment),
  ('gym', AppSymbols.gym),
  ('duration', AppSymbols.duration),
  ('rest', AppSymbols.rest),
  ('restDay', AppSymbols.restDay),
  ('warmup', AppSymbols.warmup),
  ('superset', AppSymbols.superset),
  ('subSet', AppSymbols.subSet),
  ('splitSides', AppSymbols.splitSides),
  ('personalRecord', AppSymbols.personalRecord),
  ('mesocycle', AppSymbols.mesocycle),
  ('macrocycle', AppSymbols.macrocycle),
  ('history', AppSymbols.history),
  ('library', AppSymbols.library),
  ('template', AppSymbols.template),
  ('cardio', AppSymbols.cardio),
  ('muscleGroup', AppSymbols.muscleGroup),
  ('muscleBalance', AppSymbols.muscleBalance),
  ('weeklyReview', AppSymbols.weeklyReview),
  ('note', AppSymbols.note),
  ('addNote', AppSymbols.addNote),
  ('pinnedNote', AppSymbols.pinnedNote),
  ('doLater', AppSymbols.doLater),
  ('doNext', AppSymbols.doNext),
  ('moveEarlier', AppSymbols.moveEarlier),
  ('moveLater', AppSymbols.moveLater),
  ('swap', AppSymbols.swap),
  ('smartProgression', AppSymbols.smartProgression),
  ('nutrition', AppSymbols.nutrition),
  ('meal', AppSymbols.meal),
  ('food', AppSymbols.food),
  ('recipe', AppSymbols.recipe),
  ('calories', AppSymbols.calories),
  ('protein', AppSymbols.protein),
  ('carbs', AppSymbols.carbs),
  ('fat', AppSymbols.fat),
  ('expenditure', AppSymbols.expenditure),
  ('strategy', AppSymbols.strategy),
  ('barcode', AppSymbols.barcode),
  ('camera', AppSymbols.camera),
  ('torchOn', AppSymbols.torchOn),
  ('torchOff', AppSymbols.torchOff),
  ('describe', AppSymbols.describe),
  ('photoLibrary', AppSymbols.photoLibrary),
  ('addPhoto', AppSymbols.addPhoto),
  ('changePhoto', AppSymbols.changePhoto),
  ('progressPhotos', AppSymbols.progressPhotos),
  ('steps', AppSymbols.steps),
  ('scaleWeight', AppSymbols.scaleWeight),
  ('bodyFat', AppSymbols.bodyFat),
  ('measurement', AppSymbols.measurement),
  ('goal', AppSymbols.goal),
  ('streak', AppSymbols.streak),
  ('habits', AppSymbols.habits),
  ('analytics', AppSymbols.analytics),
  ('calendar', AppSymbols.calendar),
  ('today', AppSymbols.today),
  ('todayFilled', AppSymbols.todayFilled),
  ('workoutFilled', AppSymbols.workoutFilled),
  ('nutritionFilled', AppSymbols.nutritionFilled),
  ('analyticsFilled', AppSymbols.analyticsFilled),
  ('friendsFilled', AppSymbols.friendsFilled),
  ('settings', AppSymbols.settings),
  ('notifications', AppSymbols.notifications),
  ('subscription', AppSymbols.subscription),
  ('profile', AppSymbols.profile),
  ('friends', AppSymbols.friends),
  ('invite', AppSymbols.invite),
  ('leave', AppSymbols.leave),
  ('roadmap', AppSymbols.roadmap),
  ('knowledgeBase', AppSymbols.knowledgeBase),
  ('tutorials', AppSymbols.tutorials),
  ('coach', AppSymbols.coach),
  ('legal', AppSymbols.legal),
  ('help', AppSymbols.help),
  ('add', AppSymbols.add),
  ('start', AppSymbols.start),
  ('edit', AppSymbols.edit),
  ('delete', AppSymbols.delete),
  ('reorder', AppSymbols.reorder),
  ('duplicate', AppSymbols.duplicate),
  ('favourite', AppSymbols.favourite),
  ('rate', AppSymbols.rate),
  ('developer', AppSymbols.developer),
  ('close', AppSymbols.close),
  ('confirm', AppSymbols.confirm),
  ('openExternally', AppSymbols.openExternally),
  ('integrations', AppSymbols.integrations),
  ('sync', AppSymbols.sync),
  ('video', AppSymbols.video),
  ('search', AppSymbols.search),
  ('clearText', AppSymbols.clearText),
  ('filter', AppSymbols.filter),
  ('skip', AppSymbols.skip),
  ('choose', AppSymbols.choose),
  ('repeatMacrocycle', AppSymbols.repeatMacrocycle),
  ('logAgain', AppSymbols.logAgain),
  ('nextField', AppSymbols.nextField),
  ('hideKeyboard', AppSymbols.hideKeyboard),
  ('decrease', AppSymbols.decrease),
  ('deleteBackward', AppSymbols.deleteBackward),
  ('minimize', AppSymbols.minimize),
  ('pause', AppSymbols.pause),
  ('like', AppSymbols.like),
  ('liked', AppSymbols.liked),
  ('comment', AppSymbols.comment),
  ('heart', AppSymbols.heart),
  ('heartFilled', AppSymbols.heartFilled),
  ('reply', AppSymbols.reply),
  ('send', AppSymbols.send),
  ('stop', AppSymbols.stop),
  ('jumpToLatest', AppSymbols.jumpToLatest),
  ('regenerate', AppSymbols.regenerate),
  ('copy', AppSymbols.copy),
  ('helpful', AppSymbols.helpful),
  ('notHelpful', AppSymbols.notHelpful),
  ('username', AppSymbols.username),
  ('lock', AppSymbols.lock),
  ('block', AppSymbols.block),
  ('report', AppSymbols.report),
  ('saveAsTemplate', AppSymbols.saveAsTemplate),
  ('leader', AppSymbols.leader),
  ('info', AppSymbols.info),
  ('success', AppSymbols.success),
  ('previous', AppSymbols.previous),
  ('next', AppSymbols.next),
  ('increase', AppSymbols.increase),
  ('reduce', AppSymbols.reduce),
  ('steady', AppSymbols.steady),
  ('selected', AppSymbols.selected),
  ('warning', AppSymbols.warning),
  ('error', AppSymbols.error),
  ('plateCalculator', AppSymbols.plateCalculator),
  ('disclosure', AppSymbols.disclosure),
  ('choiceSelected', AppSymbols.choiceSelected),
  ('choiceUnselected', AppSymbols.choiceUnselected),
  ('share', AppSymbols.share),
  ('more', AppSymbols.more),
];

/// The text styles, spacing, radii, colours, icons and motion of `app_ui`.
List<Widget> galleryTokens(BuildContext context) {
  final l10n = context.l10n;
  final locale = context.dateLocale;
  final light = AppTheme.light;
  final dark = AppTheme.dark;
  return [
    galleryEntry('AppTextStyles', [
      for (final (name, style) in [
        ('largeTitle', AppTextStyles.largeTitle),
        ('sectionTitle', AppTextStyles.sectionTitle),
        ('rowTitle', AppTextStyles.rowTitle),
        ('rowDetail', AppTextStyles.rowDetail),
        ('label', AppTextStyles.label),
      ])
        galleryBlock(name, Text(l10n.devGallerySampleTitle, style: style)),
      galleryBlock(
        'overline',
        Text(
          l10n.devGallerySampleTitle.toUpperCase(),
          style: AppTextStyles.overline,
        ),
      ),
      for (final (name, style) in [
        ('hero', AppTextStyles.hero),
        ('display', AppTextStyles.display),
        ('metricLarge', AppTextStyles.metricLarge),
        ('metric', AppTextStyles.metric),
        ('metricSmall', AppTextStyles.metricSmall),
      ])
        galleryBlock(
          name,
          Text(AppFormat.kcal(1850, locale: locale), style: style),
        ),
    ]),
    galleryEntry('AppColors', [
      for (final (name, color) in galleryColors)
        _swatches(
          name,
          color(light.extension<AppColors>()!),
          color(dark.extension<AppColors>()!),
        ),
    ], note: 'light | dark'),
    galleryEntry('ColorScheme', [
      for (final (name, color) in _schemeColors)
        _swatches(name, color(light.colorScheme), color(dark.colorScheme)),
    ], note: 'light | dark'),
    galleryEntry('AppSpacing', [
      for (final (name, value) in [
        ('xxs', AppSpacing.xxs),
        ('xs', AppSpacing.xs),
        ('s', AppSpacing.s),
        ('m', AppSpacing.m),
        ('l', AppSpacing.l),
        ('xl', AppSpacing.xl),
        ('xxl', AppSpacing.xxl),
      ])
        AppListRow(
          title: name,
          subtitle: AppFormat.number(value, locale: locale),
          accessory: AppListRowCustom(
            _Shape(width: value, height: AppControlSize.icon, radius: 0),
          ),
        ),
    ]),
    galleryEntry('AppRadius', [
      for (final (name, value) in [
        ('s', AppRadius.s),
        ('m', AppRadius.m),
        ('l', AppRadius.l),
        ('xl', AppRadius.xl),
      ])
        AppListRow(
          title: name,
          subtitle: AppFormat.number(value, locale: locale),
          accessory: AppListRowCustom(
            _Shape(
              width: AppControlSize.cta,
              height: AppControlSize.cta,
              radius: value,
            ),
          ),
        ),
    ]),
    galleryEntry('AppChartMark', [
      for (final (name, value) in [
        ('lineWidth', AppChartMark.lineWidth),
        ('sparkWidth', AppChartMark.sparkWidth),
        ('dotRadius', AppChartMark.dotRadius),
        ('barCorner', AppChartMark.barCorner),
        ('stackGap', AppChartMark.stackGap),
        ('barFill', AppChartMark.barFill),
        ('gridWidth', AppChartMark.gridWidth),
        ('stubHeight', AppChartMark.stubHeight),
        ('ruleWidth', AppChartMark.ruleWidth),
        ('areaOpacity', AppChartMark.areaOpacity),
        ('arcWidth', AppChartMark.arcWidth),
        ('arcWidthSmall', AppChartMark.arcWidthSmall),
        ('arcWidthHero', AppChartMark.arcWidthHero),
        ('lapShadowOpacity', AppChartMark.lapShadowOpacity),
        ('bulletWidth', AppChartMark.bulletWidth),
        ('bulletWidthSmall', AppChartMark.bulletWidthSmall),
        ('tickWidth', AppChartMark.tickWidth),
        ('tickOverhang', AppChartMark.tickOverhang),
        ('caretSize', AppChartMark.caretSize),
        ('heatCell', AppChartMark.heatCell),
        ('heatGap', AppChartMark.heatGap),
        ('heatCorner', AppChartMark.heatCorner),
        ('heatFirstShade', AppChartMark.heatFirstShade),
        ('heatRingWidth', AppChartMark.heatRingWidth),
      ])
        AppListRow(
          title: name,
          accessory: AppListRowValue(
            AppFormat.number(value, maxFractionDigits: 1, locale: locale),
          ),
        ),
    ]),
    galleryEntry('AppMotion', [const _Motion()]),
    galleryEntry('AppSymbols', [
      for (final (name, icon) in gallerySymbols)
        AppListRow(title: name, icon: icon),
    ]),
  ];
}

/// [name]'s light and dark colours side by side.
Widget _swatches(String name, Color light, Color dark) => AppListRow(
  title: name,
  accessory: AppListRowCustom(
    Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s,
      children: [_Shape.swatch(light), _Shape.swatch(dark)],
    ),
  ),
);

/// A filled rounded rectangle: a spacing bar, radius sample or colour
/// swatch. The token on show is the shape, so it is drawn here.
class _Shape extends StatelessWidget {
  const new({required this.width, required this.height, required this.radius})
    : color = null;

  const new swatch(Color this.color)
    : width = AppControlSize.thumbnail,
      height = AppControlSize.icon,
      radius = AppRadius.s;

  final double width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? scheme.primary,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

/// Each [AppMotion] moving a dot across, once per press of Play.
class _Motion extends StatefulWidget {
  const new();

  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> {
  var _end = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final motion in AppMotion.values)
        galleryBlock(
          '${motion.name}, '
          '${motion.duration.inMilliseconds} ms, ${motion.curve}',
          AnimatedAlign(
            alignment: _end
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            duration: motion.durationOf(context),
            curve: motion.curve,
            child: const _Shape(
              width: AppControlSize.icon,
              height: AppControlSize.icon,
              radius: AppRadius.m,
            ),
          ),
        ),
      AppListRowButton(
        title: context.l10n.devGalleryPlay,
        icon: AppSymbols.start,
        accessory: null,
        onPressed: () => setState(() => _end = !_end),
      ),
    ],
  );
}
