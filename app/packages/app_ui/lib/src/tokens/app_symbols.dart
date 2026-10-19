import 'package:material_ui/material_ui.dart';

/// Icons, one per concept. **One concept, one icon.** Write
/// `Icon(AppSymbols.workout)`, never an `Icons.*` literal in a screen.
///
/// Drawn from Flutter's bundled Material Icons font, which is free and needs
/// no extra package, in its outlined style to match the line weight of SF
/// Symbols. Each entry carries the concept of the Swift app's `Symbol` of the
/// same name. A filled glyph is kept only where Swift uses `.fill` for a
/// state (a record, a pin, a like, success, the chosen option). [share] and
/// [more] follow the platform's own glyph.
///
/// Material has no figure lifting a weight, so [workout] is the dumbbell,
/// Material's own glyph for a workout, and [equipment] the kit box.
abstract final class AppSymbols {
  // Training

  /// The workout as a whole.
  static const IconData workout = Icons.fitness_center_outlined;

  /// One exercise.
  static const IconData exercise = Icons.emoji_people_outlined;

  /// A set.
  static const IconData set = Icons.format_list_numbered_outlined;

  /// Repetitions.
  static const IconData reps = Icons.numbers_outlined;

  /// The weight lifted: a weighing scale. A body weight is [scaleWeight].
  static const IconData weight = Icons.scale_outlined;

  /// Training volume.
  static const IconData volume = Icons.layers_outlined;

  /// Equipment: the kit a gym has.
  static const IconData equipment = Icons.inventory_2_outlined;

  /// A gym and its equipment.
  static const IconData gym = Icons.apartment_outlined;

  /// How long something took.
  static const IconData duration = Icons.schedule_outlined;

  /// The rest timer.
  static const IconData rest = Icons.timer_outlined;

  /// A rest day.
  static const IconData restDay = Icons.bed_outlined;

  /// A warm-up set.
  static const IconData warmup = Icons.device_thermostat_outlined;

  /// A superset.
  static const IconData superset = Icons.link_outlined;

  /// A drop or mini-set: a row that is part of the set above it.
  static const IconData subSet = Icons.subdirectory_arrow_right_outlined;

  /// Logging each side of a one-limb exercise as its own row.
  static const IconData splitSides = Icons.vertical_split_outlined;

  /// A personal record.
  static const IconData personalRecord = Icons.emoji_events_rounded;

  /// A mesocycle.
  static const IconData mesocycle = Icons.assignment_outlined;

  /// The glyphs a mesocycle can be given, by the SF Symbol name it stores
  /// (Swift's `MesocycleIconPresenter.defaultIcons`). Any other name draws
  /// [mesocycle].
  static const Map<String, IconData> mesocycleIcons = {
    'flag.pattern.checkered': Icons.sports_score_outlined,
    'arcade.stick': Icons.gamepad_outlined,
    'gamecontroller': Icons.sports_esports_outlined,
    'figure.walk': Icons.directions_walk_outlined,
    'airplane.up.right': Icons.flight_takeoff_outlined,
    'sailboat.fill': Icons.sailing_outlined,
    'gauge.with.dots.needle.bottom.100percent': Icons.speed_outlined,
  };

  /// A macrocycle: mesocycles run one after another.
  static const IconData macrocycle = Icons.view_agenda_outlined;

  /// Workout history.
  static const IconData history = Icons.history_outlined;

  /// A library of exercises or workouts.
  static const IconData library = Icons.library_books_outlined;

  /// A workout template.
  static const IconData template = Icons.style_outlined;

  /// Cardio.
  static const IconData cardio = Icons.directions_run_outlined;

  /// A muscle group.
  static const IconData muscleGroup = Icons.accessibility_new_outlined;

  /// Muscle Balance: every muscle's weekly sets as a grid.
  static const IconData muscleBalance = Icons.grid_view_outlined;

  /// A weekly review.
  static const IconData weeklyReview = Icons.summarize_outlined;

  /// The user's own note on an exercise.
  static const IconData note = Icons.sticky_note_2_outlined;

  /// Adding a note.
  static const IconData addNote = Icons.note_add_outlined;

  /// A note pinned from session to session.
  static const IconData pinnedNote = Icons.push_pin_rounded;

  /// Putting an exercise off until the end of the workout.
  static const IconData doLater = Icons.vertical_align_bottom_outlined;

  /// Bringing an exercise up next.
  static const IconData doNext = Icons.vertical_align_top_outlined;

  /// A step back along a strip; mirrors right to left.
  static const IconData moveEarlier = Icons.arrow_back_outlined;

  /// A step on along a strip; mirrors right to left.
  static const IconData moveLater = Icons.arrow_forward_outlined;

  /// Swapping one exercise for another.
  static const IconData swap = Icons.swap_horiz_outlined;

  /// Smart progression.
  static const IconData smartProgression = Icons.auto_fix_high_outlined;

  // Nutrition

  /// Nutrition as a whole.
  static const IconData nutrition = Icons.eco_outlined;

  /// A meal.
  static const IconData meal = Icons.restaurant_outlined;

  /// A food.
  static const IconData food = Icons.shopping_basket_outlined;

  /// A recipe.
  static const IconData recipe = Icons.menu_book_outlined;

  /// Calories.
  static const IconData calories = Icons.local_fire_department_outlined;

  /// Protein.
  static const IconData protein = Icons.bolt_outlined;

  /// Carbohydrates.
  static const IconData carbs = Icons.grain_outlined;

  /// Fat.
  static const IconData fat = Icons.water_drop_outlined;

  /// Energy expenditure.
  static const IconData expenditure = Icons.monitor_heart_outlined;

  /// A nutrition strategy.
  static const IconData strategy = Icons.alt_route_outlined;

  /// A barcode scan.
  static const IconData barcode = Icons.barcode_reader;

  /// The camera.
  static const IconData camera = Icons.photo_camera_outlined;

  /// The camera's torch, lit.
  static const IconData torchOn = Icons.flashlight_on_outlined;

  /// The camera's torch, off.
  static const IconData torchOff = Icons.flashlight_off_outlined;

  /// A meal described in words for the AI (Swift `text.bubble`).
  static const IconData describe = Icons.chat_outlined;

  /// The photo library.
  static const IconData photoLibrary = Icons.photo_library_outlined;

  /// Add a photo (Swift `photo.badge.plus`).
  static const IconData addPhoto = Icons.add_photo_alternate_outlined;

  /// Change the photo set (Swift `photo.badge.checkmark`).
  static const IconData changePhoto = Icons.image_outlined;

  /// Progress photos (Swift `photo.stack`).
  static const IconData progressPhotos = Icons.collections_outlined;

  // Body and progress

  /// Steps.
  static const IconData steps = Icons.directions_walk_outlined;

  /// Scale weight.
  static const IconData scaleWeight = Icons.monitor_weight_outlined;

  /// Body fat.
  static const IconData bodyFat = Icons.percent_outlined;

  /// A body measurement.
  static const IconData measurement = Icons.straighten_outlined;

  /// A goal.
  static const IconData goal = Icons.track_changes_outlined;

  /// The weekly streak.
  static const IconData streak = Icons.event_available_outlined;

  /// Habits.
  static const IconData habits = Icons.repeat_outlined;

  /// Analytics.
  static const IconData analytics = Icons.show_chart_outlined;

  /// A date or schedule.
  static const IconData calendar = Icons.calendar_today_outlined;

  // App and profile

  /// The Today tab: the day at a glance.
  static const IconData today = Icons.home_outlined;

  // The tab bar's selected glyphs: each tab's icon filled, as iOS fills the
  // selected tab. A line chart has no filled form, so [analyticsFilled] is
  // the same line drawn solid.

  /// [today], selected in the tab bar.
  static const IconData todayFilled = Icons.home;

  /// [workout], selected in the tab bar.
  static const IconData workoutFilled = Icons.fitness_center;

  /// [nutrition], selected in the tab bar.
  static const IconData nutritionFilled = Icons.eco;

  /// [analytics], selected in the tab bar.
  static const IconData analyticsFilled = Icons.show_chart;

  /// [friends], selected in the tab bar.
  static const IconData friendsFilled = Icons.group;

  /// Settings.
  static const IconData settings = Icons.settings_outlined;

  /// Notifications.
  static const IconData notifications = Icons.notifications_outlined;

  /// The subscription (`tag`).
  static const IconData subscription = Icons.sell_outlined;

  /// The user's profile.
  static const IconData profile = Icons.account_circle_outlined;

  /// Friends and followers.
  static const IconData friends = Icons.group_outlined;

  /// Inviting someone to the app (`person.badge.plus`).
  static const IconData invite = Icons.person_add_alt_1_outlined;

  /// Leaving a group, such as a challenge
  /// (`rectangle.portrait.and.arrow.right`).
  static const IconData leave = Icons.logout_outlined;

  /// The roadmap.
  static const IconData roadmap = Icons.map_outlined;

  /// The knowledge base.
  static const IconData knowledgeBase = Icons.lightbulb_outlined;

  /// Tutorials.
  static const IconData tutorials = Icons.school_outlined;

  /// The AI coach, and every "Ask Coach" way into it.
  static const IconData coach = Icons.auto_awesome_outlined;

  /// Legal documents.
  static const IconData legal = Icons.description_outlined;

  /// Getting help: Settings' Support row.
  static const IconData help = Icons.help_outline_outlined;

  // Actions

  /// Adding something.
  static const IconData add = Icons.add_outlined;

  /// Starting a workout now, as opposed to building one.
  static const IconData start = Icons.play_arrow_outlined;

  /// Editing.
  static const IconData edit = Icons.edit_outlined;

  /// Deleting.
  static const IconData delete = Icons.delete_outlined;

  /// Duplicating.
  static const IconData duplicate = Icons.library_add_outlined;

  /// Making something the usual one, such as the favourite gym.
  static const IconData favourite = Icons.star_rounded;

  /// Rating the app in the store.
  static const IconData rate = Icons.star_outline_outlined;

  /// The developer tools (development and staging builds).
  static const IconData developer = Icons.code_outlined;

  /// Closing.
  static const IconData close = Icons.close_outlined;

  /// Confirming a modal's changes: its toolbar's trailing button.
  static const IconData confirm = Icons.check_outlined;

  /// Opening something in another app or the browser.
  static const IconData openExternally = Icons.open_in_new_outlined;

  /// Apps connected to Compound, such as Strava (Swift
  /// `app.connected.to.app.below.fill`).
  static const IconData integrations = Icons.hub_outlined;

  /// Fetching again from another app, such as "Sync from Apple Health"
  /// (Swift `arrow.clockwise`).
  static const IconData sync = Icons.sync_outlined;

  /// Watching a demonstration video.
  static const IconData video = Icons.smart_display_outlined;

  /// Searching.
  static const IconData search = Icons.search_outlined;

  /// Emptying a text field, such as a search.
  static const IconData clearText = Icons.cancel;

  /// Filtering.
  static const IconData filter = Icons.filter_list_outlined;

  /// Skipping a planned workout so the next one moves up.
  static const IconData skip = Icons.skip_next_outlined;

  /// A menu that picks one of several.
  static const IconData choose = Icons.unfold_more_outlined;

  /// Running a macrocycle again.
  static const IconData repeatMacrocycle = Icons.replay_outlined;

  /// Logging something again.
  static const IconData logAgain = Icons.replay_outlined;

  /// The set keypad's key to the row's next field.
  static const IconData nextField = Icons.arrow_forward_outlined;

  /// Puts the set keypad away without logging.
  static const IconData hideKeyboard = Icons.keyboard_hide_outlined;

  /// Decreasing a value.
  static const IconData decrease = Icons.remove_outlined;

  /// The set keypad's delete key.
  static const IconData deleteBackward = Icons.backspace_outlined;

  /// The tracker's way out: the workout carries on in the background.
  static const IconData minimize = Icons.expand_more_outlined;

  /// Pausing.
  static const IconData pause = Icons.pause_outlined;

  // Social

  /// A like on a workout.
  static const IconData like = Icons.thumb_up_alt_outlined;

  /// A like given.
  static const IconData liked = Icons.thumb_up_alt_rounded;

  /// Comments on a workout.
  static const IconData comment = Icons.chat_bubble_outline_outlined;

  /// A like on a comment.
  static const IconData heart = Icons.favorite_border_outlined;

  /// A like given to a comment.
  static const IconData heartFilled = Icons.favorite_rounded;

  /// Replying to a comment.
  static const IconData reply = Icons.reply_outlined;

  /// Sending a comment.
  static const IconData send = Icons.send_outlined;

  /// A username: the `@` handle.
  static const IconData username = Icons.alternate_email_outlined;

  /// A private profile.
  static const IconData lock = Icons.lock_outlined;

  /// Blocking someone.
  static const IconData block = Icons.block_outlined;

  /// Reporting a profile, workout or comment (`exclamationmark.bubble`).
  static const IconData report = Icons.flag_outlined;

  /// Saving someone's workout as one's own template
  /// (`square.and.arrow.down`).
  static const IconData saveAsTemplate = Icons.download_outlined;

  /// The leader of the week.
  static const IconData leader = Icons.workspace_premium_outlined;

  // Status

  /// Information.
  static const IconData info = Icons.info_outlined;

  /// Success.
  static const IconData success = Icons.check_circle_rounded;

  /// The previous page, such as last week.
  static const IconData previous = Icons.chevron_left_outlined;

  /// The next page, such as next week.
  static const IconData next = Icons.chevron_right_outlined;

  /// Up: more than wanted, or a step up.
  static const IconData increase = Icons.arrow_circle_up_outlined;

  /// Down: less than wanted, or a step down.
  static const IconData reduce = Icons.arrow_circle_down_outlined;

  /// Holding steady.
  static const IconData steady = Icons.remove_circle_outline_outlined;

  /// The plain tick: a menu's chosen item.
  static const IconData selected = Icons.check_outlined;

  /// A warning.
  static const IconData warning = Icons.warning_amber_outlined;

  /// An error.
  static const IconData error = Icons.error_outline_outlined;

  /// The plate calculator: the bar and plates for a weight.
  static const IconData plateCalculator = Icons.tune_outlined;

  // Chrome

  /// A row that opens another screen: the heavier chevron with round caps,
  /// closest to iOS's.
  static const IconData disclosure = Icons.arrow_forward_ios_rounded;

  /// A chosen option in a choice list.
  static const IconData choiceSelected = Icons.check_circle_rounded;

  /// An option not chosen in a choice list.
  static const IconData choiceUnselected =
      Icons.radio_button_unchecked_outlined;

  /// Sharing: the platform's own share glyph.
  static IconData get share => Icons.adaptive.share;

  /// A menu of more actions: the platform's own glyph.
  static IconData get more => Icons.adaptive.more;
}
