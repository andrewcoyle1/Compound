import 'package:material_ui/material_ui.dart';

/// Icons, one per concept. **One concept, one icon.** Write
/// `Icon(AppSymbols.workout)`, never an `Icons.*` literal in a screen.
///
/// Drawn from Flutter's bundled Material Icons font, rounded style, which
/// is free and needs no extra package. Each entry carries the concept of the
/// Swift app's `Symbol` of the same name. [share] and [more] follow the
/// platform's own glyph.
abstract final class AppSymbols {
  // Training

  /// The workout as a whole.
  static const IconData workout = Icons.sports_gymnastics_rounded;

  /// One exercise.
  static const IconData exercise = Icons.sports_martial_arts_rounded;

  /// A set.
  static const IconData set = Icons.format_list_numbered_rounded;

  /// Repetitions.
  static const IconData reps = Icons.numbers_rounded;

  /// The weight lifted.
  static const IconData weight = Icons.speed_rounded;

  /// Training volume.
  static const IconData volume = Icons.layers_rounded;

  /// Equipment.
  static const IconData equipment = Icons.fitness_center_rounded;

  /// A gym and its equipment.
  static const IconData gym = Icons.apartment_rounded;

  /// How long something took.
  static const IconData duration = Icons.schedule_rounded;

  /// The rest timer.
  static const IconData rest = Icons.timer_rounded;

  /// A rest day.
  static const IconData restDay = Icons.bed_rounded;

  /// A warm-up set.
  static const IconData warmup = Icons.device_thermostat_rounded;

  /// A superset.
  static const IconData superset = Icons.link_rounded;

  /// A drop or mini-set: a row that is part of the set above it.
  static const IconData subSet = Icons.subdirectory_arrow_right_rounded;

  /// Logging each side of a one-limb exercise as its own row.
  static const IconData splitSides = Icons.vertical_split_rounded;

  /// A personal record.
  static const IconData personalRecord = Icons.emoji_events_rounded;

  /// A mesocycle.
  static const IconData mesocycle = Icons.assignment_rounded;

  /// A macrocycle: mesocycles run one after another.
  static const IconData macrocycle = Icons.view_agenda_rounded;

  /// Workout history.
  static const IconData history = Icons.history_rounded;

  /// A library of exercises or workouts.
  static const IconData library = Icons.library_books_rounded;

  /// A workout template.
  static const IconData template = Icons.style_rounded;

  /// Cardio.
  static const IconData cardio = Icons.directions_run_rounded;

  /// A muscle group.
  static const IconData muscleGroup = Icons.accessibility_new_rounded;

  /// The user's own note on an exercise.
  static const IconData note = Icons.sticky_note_2_rounded;

  /// Adding a note.
  static const IconData addNote = Icons.note_add_rounded;

  /// A note pinned from session to session.
  static const IconData pinnedNote = Icons.push_pin_rounded;

  /// Putting an exercise off until the end of the workout.
  static const IconData doLater = Icons.vertical_align_bottom_rounded;

  /// Bringing an exercise up next.
  static const IconData doNext = Icons.vertical_align_top_rounded;

  /// A step back along a strip; mirrors right to left.
  static const IconData moveEarlier = Icons.arrow_back_rounded;

  /// A step on along a strip; mirrors right to left.
  static const IconData moveLater = Icons.arrow_forward_rounded;

  /// Swapping one exercise for another.
  static const IconData swap = Icons.swap_horiz_rounded;

  /// Smart progression.
  static const IconData smartProgression = Icons.auto_fix_high_rounded;

  // Nutrition

  /// Nutrition as a whole.
  static const IconData nutrition = Icons.eco_rounded;

  /// A meal.
  static const IconData meal = Icons.restaurant_rounded;

  /// A food.
  static const IconData food = Icons.shopping_basket_rounded;

  /// A recipe.
  static const IconData recipe = Icons.menu_book_rounded;

  /// Calories.
  static const IconData calories = Icons.local_fire_department_rounded;

  /// Protein.
  static const IconData protein = Icons.bolt_rounded;

  /// Carbohydrates.
  static const IconData carbs = Icons.grain_rounded;

  /// Fat.
  static const IconData fat = Icons.water_drop_rounded;

  /// Energy expenditure.
  static const IconData expenditure = Icons.monitor_heart_rounded;

  /// A nutrition strategy.
  static const IconData strategy = Icons.alt_route_rounded;

  /// A barcode scan.
  static const IconData barcode = Icons.barcode_reader;

  /// The camera.
  static const IconData camera = Icons.photo_camera_rounded;

  // Body and progress

  /// Steps.
  static const IconData steps = Icons.directions_walk_rounded;

  /// Scale weight.
  static const IconData scaleWeight = Icons.monitor_weight_rounded;

  /// Body fat.
  static const IconData bodyFat = Icons.percent_rounded;

  /// A body measurement.
  static const IconData measurement = Icons.straighten_rounded;

  /// A goal.
  static const IconData goal = Icons.track_changes_rounded;

  /// The weekly streak.
  static const IconData streak = Icons.event_available_rounded;

  /// Habits.
  static const IconData habits = Icons.repeat_rounded;

  /// Analytics.
  static const IconData analytics = Icons.show_chart_rounded;

  /// A date or schedule.
  static const IconData calendar = Icons.calendar_today_rounded;

  // App and profile

  /// Settings.
  static const IconData settings = Icons.settings_rounded;

  /// Notifications.
  static const IconData notifications = Icons.notifications_rounded;

  /// The user's profile.
  static const IconData profile = Icons.account_circle_rounded;

  /// Friends and followers.
  static const IconData friends = Icons.group_rounded;

  /// The roadmap.
  static const IconData roadmap = Icons.map_rounded;

  /// The knowledge base.
  static const IconData knowledgeBase = Icons.lightbulb_rounded;

  /// Tutorials.
  static const IconData tutorials = Icons.school_rounded;

  /// The AI coach, and every "Ask Coach" way into it.
  static const IconData coach = Icons.auto_awesome_rounded;

  /// Legal documents.
  static const IconData legal = Icons.description_rounded;

  // Actions

  /// Adding something.
  static const IconData add = Icons.add_rounded;

  /// Starting a workout now, as opposed to building one.
  static const IconData start = Icons.play_arrow_rounded;

  /// Editing.
  static const IconData edit = Icons.edit_rounded;

  /// Deleting.
  static const IconData delete = Icons.delete_rounded;

  /// Duplicating.
  static const IconData duplicate = Icons.library_add_rounded;

  /// Closing.
  static const IconData close = Icons.close_rounded;

  /// Opening something in another app or the browser.
  static const IconData openExternally = Icons.open_in_new_rounded;

  /// Watching a demonstration video.
  static const IconData video = Icons.smart_display_rounded;

  /// Searching.
  static const IconData search = Icons.search_rounded;

  /// Filtering.
  static const IconData filter = Icons.filter_list_rounded;

  /// Skipping a planned workout so the next one moves up.
  static const IconData skip = Icons.skip_next_rounded;

  /// A menu that picks one of several.
  static const IconData choose = Icons.unfold_more_rounded;

  /// Running a macrocycle again.
  static const IconData repeatMacrocycle = Icons.replay_rounded;

  /// Logging something again.
  static const IconData logAgain = Icons.replay_rounded;

  /// The set keypad's key to the row's next field.
  static const IconData nextField = Icons.arrow_forward_rounded;

  /// Puts the set keypad away without logging.
  static const IconData hideKeyboard = Icons.keyboard_hide_rounded;

  /// Decreasing a value.
  static const IconData decrease = Icons.remove_rounded;

  /// The set keypad's delete key.
  static const IconData deleteBackward = Icons.backspace_rounded;

  /// The tracker's way out: the workout carries on in the background.
  static const IconData minimize = Icons.expand_more_rounded;

  /// Pausing.
  static const IconData pause = Icons.pause_rounded;

  // Status

  /// Information.
  static const IconData info = Icons.info_outline_rounded;

  /// Success.
  static const IconData success = Icons.check_circle_rounded;

  /// The plain tick: a menu's chosen item.
  static const IconData selected = Icons.check_rounded;

  /// A warning.
  static const IconData warning = Icons.warning_amber_rounded;

  /// An error.
  static const IconData error = Icons.error_outline_rounded;

  /// The plate calculator: the bar and plates for a weight.
  static const IconData plateCalculator = Icons.tune_rounded;

  // Chrome

  /// A row that opens another screen.
  static const IconData disclosure = Icons.chevron_right_rounded;

  /// A chosen option in a choice list.
  static const IconData choiceSelected = Icons.check_circle_rounded;

  /// An option not chosen in a choice list.
  static const IconData choiceUnselected = Icons.radio_button_unchecked_rounded;

  /// Sharing: the platform's own share glyph.
  static IconData get share => Icons.adaptive.share;

  /// A menu of more actions: the platform's own glyph.
  static IconData get more => Icons.adaptive.more;
}
