# Feature parity checklist

Every presenter-backed Swift screen module in `docs/codebase-map.md` (generated from it on
14 Oct 2026). Parity means each row is **done** in the Flutter app, or deliberately **dropped** with a
reason recorded in `decisions.md`. The milestone column is the plan's first estimate; slices may move rows.

Status: `todo`, `partial` (the gap is named), `done`, `dropped`. Flutter paths are under `app/lib/`.

**Swept 16 Oct 2026, through #151** (the merged slices into `feature/flutter`; #152, the AI scanners,
is open and counts as in progress). Each row was checked against the Swift presenter's actions and
router destinations, the Flutter code and routes, and the PR's Decisions and Deferred sections.

| | done | partial | todo | dropped | total |
|---|---|---|---|---|---|
| Screen modules | 146 | 37 | 12 | 3 | 198 |
| Platform features | 6 | 11 | 8 | 0 | 25 |

The open work is grouped into slices under [Remaining work](#remaining-work) at the end.

| Area | Swift module | Folder | Milestone | Status | Flutter |
|---|---|---|---|---|---|
| Components | CalendarHeader | `Views/CalendarHeader` | M2 | partial | Nutrition's week strip (#95, `nutrition/view/widgets/calendar_strip.dart`), a swipeable week by decision; no Return to Today, no zoomed calendar, and the Training tab has no calendar header |
| Components | Calendar | `Views/CalendarHeader/Calendar` | M2 | todo | the zoomed month picker behind the header |
| Components | AuthorHeader | `Views/User` | M2 | done | #131, social feed and profile |
| Analytics | Analytics | `Compound/Core/Analytics` | M4 | done | #103, #130, #133, #137 (`progress/`) |
| Analytics | BodyMetrics | `Subviews/BodyMetrics` | M4 | done | #137; Photos row (#150); Sync from Apple Health on Visual Body Fat (#151) |
| Analytics | LogMeasurement | `Subviews/BodyMetrics/LogMeasurement` | M4 | done | #137, `/log-measurement/:kind` |
| Analytics | LogWeight | `Subviews/BodyMetrics/LogMeasurement/LogWeightView` | M4 | done | #106; export to Health first (#151) |
| Analytics | ProgressPhotos | `Subviews/BodyMetrics/ProgressPhotos` | M4 | done | #150, `/progress/body-metrics/photos` and compare |
| Analytics | ScaleWeight | `Subviews/BodyMetrics/ScaleWeight` | M4 | done | #98, #106, #137; Health import on appear (#151) |
| Analytics | ExerciseAnalytics | `Subviews/ExerciseAnalytics` | M4 | done | #133 (profile unit, not per-exercise) |
| Analytics | ExerciseDetail | `Subviews/ExerciseAnalytics/ExerciseDetail` | M4 | done | #133; Ask Coach (#147) |
| Analytics | FoodLoggingConsistency | `Subviews/FoodLoggingConsistency` | M4 | done | #137 |
| Analytics | Habits | `Subviews/Habits` | M4 | done | #137 |
| Analytics | InsightsAndAnalytics | `Subviews/InsightsAndAnalytics` | M4 | done | #137 |
| Analytics | EnergyBalance | `Subviews/InsightsAndAnalytics/EnergyBalance` | M4 | done | #130 (intake as dots); Ask Coach (#147) |
| Analytics | ExpenditureDetail | `Subviews/InsightsAndAnalytics/ExpenditureDetail` | M4 | done | #130, with Edit Profile; Ask Coach (#147) |
| Analytics | GoalProgress | `Subviews/InsightsAndAnalytics/GoalProgress` | M4 | partial | #137; Set Goal and Change Goal wait for a goal editor outside onboarding |
| Analytics | MuscleGroupDetail | `Subviews/InsightsAndAnalytics/MuscleGroupDetail` | M4 | done | #133; Ask Coach (#147) |
| Analytics | Steps | `Subviews/InsightsAndAnalytics/Steps` | M4 | done | #137; access ask and Sync from Apple Health (#151) |
| Analytics | WeightTrend | `Subviews/InsightsAndAnalytics/WeightTrend` | M4 | done | #98, #137; Ask Coach (#147) |
| Analytics | Workout | `Subviews/InsightsAndAnalytics/Workouts` | M4 | done | #133 |
| Analytics | MuscleBalance | `Subviews/MuscleBalance` | M4 | done | #133 |
| Analytics | MuscleGroups | `Subviews/MuscleGroups` | M4 | done | #133 |
| Analytics | NutritionAnalytics | `Subviews/NutritionAnalytics` | M4 | done | #137 |
| Analytics | NutritionMetricDetail | `Subviews/NutritionAnalytics/NutritionMetricDetail` | M4 | done | #137 |
| Analytics | NutritionTargetChart | `Subviews/NutritionTargetChart` | M4 | partial | #137; Create Diet Plan waits for a diet questionnaire outside onboarding |
| Analytics | ProgressCarousel | `Subviews/ProgressCarousel` | M4 | partial | #137; Weekly Workouts has no program targets or Active Program toggle |
| Analytics | WeighInConsistency | `Subviews/WeighInConsistency` | M4 | done | #137 |
| Analytics | WorkoutConsistency | `Subviews/WorkoutConsistency` | M4 | partial | #133; the grid has no month labels or press-and-hold callout |
| AppView | App | `Compound/Core/AppView` | M1 | partial | redirect and shell (#86, #90), profile gate and launch retry (#116), push token, reminders and held links (#127), first-page inbox read (#144); no in-app activity banner (#144 deferred) and no widget snapshot on backgrounding (M6) |
| Challenges | ChallengeDetail | `ChallengeDetail` | M5 | done | #146, `/challenges/:challengeId` |
| Challenges | CreateChallenge | `CreateChallenge` | M5 | done | #146, `/challenges/new` |
| Coach | Coach | `Compound/Core/Coach` | M5 | done | #147, `/coach` and `/coach-chats`; See Plans waits for the paywall |
| DevSettings | DevSettings | `Compound/Core/DevSettings` | M5 | todo | DEV/MOCK-only tools screen; no Flutter equivalent |
| Notifications | Notifications | `Compound/Core/Notifications` | M5 | done | #144, `/social/notifications`; share and challenge rows open (#146, #148) |
| Notifications | NotificationSettings | `NotificationSettings` | M5 | done | #128; permission prompt (#144); reminders applied by #127 |
| Nutrition | Nutrition | `Compound/Core/Nutrition` | M3 | partial | #95, #126, #130, #142, #145, Ask Coach (#147), food import (#151); no Customise Food Log link on the tab (Settings only) |
| Nutrition | CheckIn | `CheckIn` | M3 | done | #130, `/check-in`; Ask Coach (#147) |
| Nutrition | IngredientListBuilder | `Components/IngredientListBuilder` | M3 | done | #142, #145 |
| Nutrition | MealAccessory | `Components/MealAccessory` | M3 | partial | #126; the unlogged-meal bar shows on the Nutrition tab only (Swift: over every tab), and the draft is in memory only |
| Nutrition | MealHourHeader | `Components/MealHourHeader` | M3 | done | #126, + per hour |
| Nutrition | RecipeListBuilder | `Components/RecipeListBuilder` | M3 | done | #145 |
| Nutrition | Foods | `Foods` | M3 | done | #142, `/nutrition/foods` |
| Nutrition | CreateFood | `Foods/CreateFood` | M3 | partial | #142, `/create-food`; no food photo |
| Nutrition | FoodDefinition | `Foods/CreateFood/FoodDefinition` | M3 | done | #142 |
| Nutrition | FoodPackaging | `Foods/CreateFood/FoodPackaging` | M3 | todo | deferred by #142: unreachable in Swift (public contribution switched off), photos only |
| Nutrition | PortionDefinition | `Foods/CreateFood/PortionDefinition` | M3 | done | #142 (the serving option, the only one Swift offers) |
| Nutrition | FoodDetail | `Foods/FoodDetail` | M3 | done | #142, `/nutrition/foods/:foodId` |
| Nutrition | AddMeal | `MealLog/AddMeal` | M3 | partial | #126, `/log-meal`; no nutrient breakdown, and the unlogged draft is lost if the app is killed |
| Nutrition | IngredientAmount | `MealLog/IngredientAmount` | M3 | done | #126 (amount sheet) |
| Nutrition | MealDetail | `MealLog/MealDetail` | M3 | done | #142, `/nutrition/meal/:mealId` |
| Nutrition | MealItemAmountView | `MealLog/MealItemAmountView` | M3 | done | #126 (plate); #142 (timeline) |
| Nutrition | NutritionLibraryPicker | `MealLog/NutritionLibraryPicker` | M3 | partial | #126, #145: Barcode, Search, Quick Add, Library; the AI and Describe tabs are in #152 (open) |
| Nutrition | BarcodeScanner | `MealLog/NutritionLibraryPicker/BarcodeScanner` | M3 | partial | #126 barcode mode; label mode is in #152 (open, typed text, no OCR); no torch |
| Nutrition | FoodItemQuickAdd | `MealLog/NutritionLibraryPicker/FoodItemQuickAdd` | M3 | done | #126 |
| Nutrition | FoodItemSearch | `MealLog/NutritionLibraryPicker/FoodItemSearch` | M3 | done | #126; recipes (#145) |
| Nutrition | FoodLibrary | `MealLog/NutritionLibraryPicker/FoodLibrary` | M3 | done | #126; Recipes / Foods / Favorites (#145) |
| Nutrition | FoodPhotoScanner | `MealLog/NutritionLibraryPicker/FoodPhotoScanner` | M3 | todo | in progress: #152 |
| Nutrition | MealDescribe | `MealLog/NutritionLibraryPicker/MealDescribe` | M3 | todo | in progress: #152 |
| Nutrition | RecipeAmount | `MealLog/RecipeAmount` | M3 | done | #145 |
| Nutrition | NutritionOverview | `NutritionOverview` | M3 | done | #130, `/nutrition/overview` |
| Nutrition | Recipes | `Recipes` | M3 | done | #145, `/nutrition/recipes` |
| Nutrition | CreateRecipe | `Recipes/CreateRecipe` | M3 | done | #145, `/create-recipe` |
| Nutrition | RecipeIngredientAmount | `Recipes/CreateRecipe/RecipeIngredientAmount` | M3 | done | #145 |
| Nutrition | RecipePreparation | `Recipes/CreateRecipe/RecipePreparation` | M3 | partial | #145; no recipe photo |
| Nutrition | RecipeDetail | `Recipes/RecipeDetail` | M3 | done | #145, `/nutrition/recipes/:id` |
| Nutrition | RecipeStart | `Recipes/RecipeStart` | M3 | done | #145 |
| Nutrition | TimelineActions | `TimelineActions` | M3 | done | #142 |
| Onboarding | Welcome | `0 - WelcomeView` | M3 | partial | the sign-in page stands in (#86, #116); Swift's Welcome also sends a non-premium returning user to Subscription, which waits for the paywall |
| Onboarding | Auth | `2 - AuthView` | M3 | partial | `sign_in/` (#86): Google and anonymous; Apple shows on iOS only (Android at M6) |
| Onboarding | Subscription | `3 - Subscription` | M3 | todo | waits for the paywall slice (#116 left it out) |
| Onboarding | NamePhoto | `4 - CompleteAccountSetup/1 - NamePhoto` | M3 | partial | name (#116); the photo step is deferred by #150 |
| Onboarding | Gender | `4 - CompleteAccountSetup/2 - Gender` | M3 | done | #116; Fill from Apple Health on iOS (#151) |
| Onboarding | DateOfBirth | `4 - CompleteAccountSetup/3 - DateOfBirth` | M3 | done | #116; Fill from Apple Health on iOS (#151) |
| Onboarding | Height | `4 - CompleteAccountSetup/4 - Height` | M3 | done | #116; Fill from Health (#151) |
| Onboarding | Weight | `4 - CompleteAccountSetup/5 - Weight` | M3 | done | #116; Fill from Health (#151) |
| Onboarding | ExerciseFrequency | `4 - CompleteAccountSetup/6 - ExerciseFrequency` | M3 | done | #116 |
| Onboarding | Activity | `4 - CompleteAccountSetup/7 - Activity` | M3 | done | #116 |
| Onboarding | Expenditure | `4 - CompleteAccountSetup/9 - Expenditure` | M3 | done | #116 |
| Onboarding | HealthDisclaimer | `5 - HealthDisclaimer` | M3 | done | #116 (document links are placeholders in Swift too) |
| Onboarding | OverarchingObjective | `6 - GoalSetting/1 - OverarchingObjective` | M3 | done | #116 |
| Onboarding | TargetWeight | `6 - GoalSetting/2 - TargetWeight` | M3 | done | #116 |
| Onboarding | WeightRate | `6 - GoalSetting/3 - WeightRate` | M3 | done | #116 |
| Onboarding | GoalSummary | `6 - GoalSetting/4 - GoalSummary` | M3 | done | #116 |
| Onboarding | CustomisingDietProgram | `8 - OnboardingDiet` | M3 | done | #116 |
| Onboarding | PreferredDiet | `8 - OnboardingDiet/1 - PreferredDiet` | M3 | done | #116 (onboarding only; Settings' Nutrition Plan is missing, see Settings) |
| Onboarding | CalorieFloor | `8 - OnboardingDiet/2 - CalorieFloor` | M3 | done | #116 |
| Onboarding | CalorieDistribution | `8 - OnboardingDiet/4 - CalorieDistribution` | M3 | done | #116 |
| Onboarding | ProteinIntake | `8 - OnboardingDiet/5 - ProteinIntake` | M3 | done | #116 |
| Onboarding | DietPlan | `8 - OnboardingDiet/6 - DietPlan` | M3 | done | #116 |
| Onboarding | OnboardingCompleted | `9 - OnboardingCompleted` | M3 | dropped | decisions.md (#116): unreachable, because `.complete` only arises once onboarding is done |
| Paywalls | Paywall | `Paywall` | M4 | todo | `purchases_repository` (#114) only; no paywall screen, and both flavors pass a premium fake (#147) |
| Profile | Settings | `Compound/Core/Profile` | M5 | partial | #128, `/profile/settings`; rows still missing: Subscription, Siri, Weight Goal, Nutrition Plan, Rate, and Save Account for an anonymous user |
| Profile | About | `Subviews/About` | M5 | partial | #128; no version and build (no `package_info_plus`) |
| Profile | Licences | `Subviews/About/Licences` | M5 | done | #128 (`LicensePage`) |
| Profile | AppIcon | `Subviews/AppIcon` | M6 | todo | iOS alternate icons, M6; Swift hides the row (one icon) |
| Profile | EditProfile | `Subviews/EditProfile` | M5 | done | #128; photo (#150) |
| Profile | DeleteAccount | `Subviews/EditProfile/DeleteAccount` | M5 | done | #128 ("Account Deleted" is a snack bar) |
| Profile | EditUsername | `Subviews/EditProfile/EditUsername` | M5 | done | #131, `/username` |
| Profile | CustomiseAnalytics | `Subviews/GeneralSettings/CustomiseAnalytics` | M5 | done | #128 |
| Profile | Integrations | `Subviews/GeneralSettings/Integrations` | M5 | done | #151, `/profile/settings/integrations` |
| Profile | Siri | `Subviews/GeneralSettings/Siri` | M6 | todo | App Intents, M6 |
| Profile | Units | `Subviews/GeneralSettings/Units` | M5 | done | #128 |
| Profile | Legal | `Subviews/Legal` | M5 | done | #128 (titles "not published yet"; Swift's links are placeholders) |
| Profile | MethodsAndSources | `Subviews/MethodsAndSources` | M5 | partial | #128, #130, #133, #137: 18 of Swift's 31 methods; missing energy density, smart progression, mesocycle deload (ported but not listed), warm-up sets, rest intervals, formula expenditure, resting metabolic rate, thermic effect of food, protein target, calorie floor, calorie cycling, weight change rate, goal timeline |
| Profile | ExpenditureSettings | `Subviews/NutritionSettings/ExpenditureSettings` | M5 | partial | #128; its two ⓘ method buttons are missing |
| Profile | FoodLogSettings | `Subviews/NutritionSettings/FoodLogSettings` | M5 | done | #128 |
| Profile | FavouriteMeasurements | `Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements` | M5 | done | #128 |
| Profile | LoggerBanner | `Subviews/NutritionSettings/FoodLogSettings/LoggerBanner` | M5 | done | #128 |
| Profile | LoggerFoodTiles | `Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles` | M5 | done | #128 |
| Profile | TimelineFoodTiles | `Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles` | M5 | done | #128 |
| Profile | StrategySettings | `Subviews/NutritionSettings/StrategySettings` | M5 | done | #128 |
| Profile | ExerciseAssessment | `Subviews/TrainingSettings/ExerciseAssessment` | M5 | dropped | decisions.md (#144): Swift hides the row; the assessment unlocks nothing |
| Profile | GymProfiles | `Subviews/TrainingSettings/GymProfiles` | M5 | done | #140, `/profile/settings/gym-profiles` |
| Profile | GymProfile | `Subviews/TrainingSettings/GymProfiles/GymProfile` | M5 | partial | #140; no gym photo or equipment thumbnails |
| Profile | AddGymMachine | `Subviews/TrainingSettings/GymProfiles/GymProfile/AddGymMachine` | M5 | done | #140 |
| Profile | CreateGymProfile | `Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile` | M5 | done | #140; also onboarding and Choose Gym Profile |
| Profile | EditBand | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand` | M5 | done | #140, shared editor |
| Profile | AddBand | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand` | M5 | done | #140, shared editor |
| Profile | EditBodyWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight` | M5 | done | #140, shared editor |
| Profile | AddBodyWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight` | M5 | done | #140, shared editor |
| Profile | EditFixedWeightBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar` | M5 | done | #140, shared editor |
| Profile | AddFixedWeightBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar` | M5 | done | #140, shared editor |
| Profile | EditFreeWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight` | M5 | done | #140, shared editor |
| Profile | AddFreeWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight` | M5 | done | #140, shared editor |
| Profile | EditLoadableAccessory | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory` | M5 | done | #140 |
| Profile | EditLoadableBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar` | M5 | done | #140, shared editor |
| Profile | AddLoadableBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar` | M5 | done | #140, shared editor |
| Profile | EditPlateLoadedMachine | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine` | M5 | done | #140 |
| Profile | EditStackMachine | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditStackMachine` | M5 | done | #140; cable and pin-loaded share it |
| Profile | AddWeightStack | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditStackMachine/AddWeightStack` | M5 | done | #140 |
| Profile | EditWeightRange | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange` | M5 | done | #140 |
| Profile | WorkoutSettings | `Subviews/TrainingSettings/WorkoutSettings` | M5 | done | #128 |
| Profile | RestTimerSettings | `Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings` | M5 | done | #128 |
| Profile | TimerDuration | `Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration` | M5 | done | #128 |
| Profile | SmartProgressionSettings | `Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings` | M5 | partial | #128; its ⓘ method button is missing (smart progression's `MethodInfo` isn't ported) |
| Profile | Tutorials | `Subviews/Tutorials` | M5 | dropped | decisions.md (#144): Swift hides the row; no tutorials exist |
| Sharing | ShareToFollower | `ShareToFollower` | M5 | done | #148 (pushed dialog) |
| Sharing | SharedItem | `SharedItem` | M5 | done | #148, `/shares/:shareId` |
| Social | Social | `Compound/Core/Social` | M5 | done | #131; bell and badges (#144); challenges and invites (#146) |
| Social | WeeklyGoal | `CircleGoals/WeeklyGoal` | M5 | done | #131 |
| Social | SocialProfile | `SocialProfile` | M5 | partial | #131; Share Profile (#146); Strava This Year (#151); no Report, and no "Following {mesocycle}" line |
| Social | FollowersList | `SocialProfile/FollowersList` | M5 | done | #131 |
| Social | WorkoutSessionRow | `WorkoutSessionRow` | M5 | partial | #131; Share Image and Share with Friends (#148); no text Share link (prod Hosting URL), Save as Template or Report |
| Social | Comments | `WorkoutSessionRow/Comments` | M5 | partial | #131; no Report |
| TabBar | TabBar | `Compound/Core/TabBar` | M1 | done | #90, five tabs, per-tab stacks, deep-link paths |
| Today | Today | `Compound/Core/Today` | M2 | partial | #101, #133, #134, #147, #151; the checklist's planned and rest-day training states, the step-goal picker and the social pulse row are missing |
| Today | WeeklyReview | `WeeklyReview` | M2 | done | #133, `/today/weekly-review`; share card (#148), From Strava (#151), Ask Coach (#147) |
| Training | Training | `Compound/Core/Training` | M3 | partial | #120, #134, #136, #138, #141 (search, active mesocycle, library, + menu); no calendar header, so no tapping a day to open its sessions |
| Training | TodaysWorkoutCard | `Components/TodaysWorkoutCard` | M3 | done | #134 |
| Training | TrainingAccessory | `Components/TrainingAccessory` | M3 | partial | `ActiveWorkoutBar` (#125): name and clock only; no set progress, rest countdown or Skip Rest |
| Training | WorkoutStreak | `Components/WorkoutStreakCard` | M3 | done | #101, Today's `StreakCard` |
| Training | CreateExercise | `Exercises/CreateExercise` | M3 | done | #141, `/create-exercise` |
| Training | EquipmentPicker | `Exercises/CreateExercise/EquipmentPicker` | M3 | done | #141 |
| Training | ExerciseEquipment | `Exercises/CreateExercise/ExerciseEquipment` | M3 | done | #141 |
| Training | ExerciseSave | `Exercises/CreateExercise/ExerciseSave` | M3 | done | #141 |
| Training | FinalExerciseDetails | `Exercises/CreateExercise/FinalExerciseDetails` | M3 | done | #141 |
| Training | MuscleGroupPicker | `Exercises/CreateExercise/MuscleGroupPicker` | M3 | done | #141 |
| Training | ExerciseListBuilder | `Exercises/ExerciseListBuilder` | M3 | done | #120 (filters); Create Exercise row (#141) |
| Training | ExerciseModelDetail | `Exercises/ExerciseModelDetail` | M3 | partial | #120 About and History; Delete (#141); Ask Coach (#147); the Charts and Records tabs are missing |
| Training | Exercises | `Exercises/Exercises` | M3 | done | #120, `/training/exercises`; Create Exercise (#141) |
| Training | ActiveMesocycle | `Programs/ActiveMesocycle` | M3 | done | #134, #136; Ask Coach (#147) |
| Training | CreateMesocycle | `Programs/CreateMesocycle` | M3 | done | #136; onboarding's Build My Own (#138) |
| Training | EditDayOrder | `Programs/CreateMesocycle/EditDayOrder` | M3 | done | #136 |
| Training | EditDeload | `Programs/CreateMesocycle/EditDeload` | M3 | done | #136 |
| Training | EditMesocycleColourIcon | `Programs/CreateMesocycle/EditMesocycleColourIcon` | M3 | done | #136 |
| Training | MesocycleDesign | `Programs/CreateMesocycle/MesocycleDesign` | M3 | done | #136; day editor (#138); Share (#148) |
| Training | MesocycleIcon | `Programs/CreateMesocycle/MesocycleIcon` | M3 | done | #136 |
| Training | MesocycleSettings | `Programs/CreateMesocycle/MesocycleSettings` | M3 | done | #136 |
| Training | NameMesocycle | `Programs/CreateMesocycle/NameMesocycle` | M3 | done | #136 |
| Training | RenameWorkoutTemplateModel | `Programs/CreateMesocycle/RenameWorkoutTemplateModel` | M3 | done | #136 |
| Training | ImportProgram | `Programs/ImportProgram` | M3 | done | #136: xlsx, csv and the app's JSON |
| Training | Macrocycles | `Programs/Macrocycles` | M3 | done | #134, #136 |
| Training | MacrocycleDetail | `Programs/Macrocycles/MacrocycleDetail` | M3 | done | #134 |
| Training | MesocycleLibrary | `Programs/MesocycleLibrary` | M3 | done | #134, #136 |
| Training | InactiveMesocycle | `Programs/MesocycleLibrary/InactiveMesocycle` | M3 | done | #134 |
| Training | MesocycleDisclosureGroup | `Programs/MesocycleLibrary/MesocycleDisclosureGroup` | M3 | done | #134; Edit (#136); Share with Friends (#148) |
| Training | PrebuiltMesocycleDetail | `Programs/MesocycleLibrary/PrebuiltMesocycleDetail` | M3 | done | #134 |
| Training | ExerciseTracker | `Session/ExerciseTracker` | M3 | partial | #125 block card, targets, Last, notes, Delete Exercise, supersets; no swap, Do Next/Do Later or reordering, progression note, Last tap-to-fill or previous-note hints |
| Training | ExerciseSettings | `Session/ExerciseTracker/ExerciseSettings` | M3 | partial | the exercise note is in #125's notes sheet; no per-exercise weight or distance unit, rest timer, side-set rest or Edit Duplicate |
| Training | SetTrackerRow | `Session/ExerciseTracker/SetTrackerRow` | M3 | partial | #125 logging, correction, delete with Undo; no set-type menu (drop, myo, warm-up), sub-sets, split sides, per-row custom rest or unit menu |
| Training | PlateCalculator | `Session/ExerciseTracker/SetTrackerRow/PlateCalculator` | M3 | todo | deferred by #125 (with the loading bar) |
| Training | SetKeyboard | `Session/ExerciseTracker/SetTrackerRow/SetKeyboard` | M3 | partial | #125 keypad, chips and steps; no bands chips, ± assisted key or stopwatch |
| Training | SwapExercisePicker | `Session/ExerciseTracker/SwapExercisePicker` | M3 | todo | deferred by #125 |
| Training | WorkoutExerciseEquipmentSheet | `Session/ExerciseTracker/WorkoutExerciseEquipmentSheet` | M3 | todo | deferred by #125; it also opens #140's scoped gym editor |
| Training | WorkoutHistory | `Session/WorkoutHistory` | M3 | done | #93, `/training/history` |
| Training | WorkoutNotes | `Session/WorkoutNotes` | M3 | done | #125 notes sheet |
| Training | WorkoutSessionDetail | `Session/WorkoutSessionDetail` | M3 | partial | #93; summary (#125); Share Image (#148); Ask Coach (#147); View on Strava and the offer (#151); no editing (sets, start time, duration, Add Exercise), no Delete, no Copy Link |
| Training | WorkoutTracker | `Session/WorkoutTracker` | M3 | partial | #125, #127 (`/workout`); Gym Settings (#140); no Workout Settings from the menu, "Finish at", iPad toolbar or rest-complete sound |
| Training | ChooseGymProfile | `Workouts/CreateWorkout/ChooseGymProfile` | M3 | done | #138; Create Gym Profile (#140) |
| Training | DefineWorkout | `Workouts/CreateWorkout/DefineWorkout` | M3 | done | #138 |
| Training | DefineWorkoutWrapper | `Workouts/CreateWorkout/DefineWorkoutWrapper` | M3 | done | #138 |
| Training | ExercisesPicker | `Workouts/CreateWorkout/ExercisesPicker` | M3 | done | #120 `/exercise-picker`; substitutions (#138) |
| Training | NameWorkout | `Workouts/CreateWorkout/NameWorkout` | M3 | done | #138, `create-workout`, `edit-workout/:id` |
| Training | SetTarget | `Workouts/CreateWorkout/SetTarget` | M3 | partial | #138 for templates; the tracker's session-scope editing waits for tracker editing |
| Training | WeeklyTargets | `Workouts/CreateWorkout/SetTarget/WeeklyTargets` | M3 | done | #138 |
| Training | WorkoutTemplateDetail | `Workouts/WorkoutTemplateDetail` | M3 | partial | #120, #134, #136, #138, #148 (Start, Edit, Delete, Edit Mesocycle, Save a Copy, Share); no Watch link or per-set target grid |
| Training | Workouts | `Workouts/Workouts` | M3 | done | #120, `/training/workouts`; New Workout (#138) |

198 modules.

## Platform features (not screen modules)

| Feature | Swift | Milestone | Status | Flutter |
|---|---|---|---|---|
| Sign in: Apple, Google, anonymous, account linking | SwiftfulAuthenticating | M1 | partial | `auth_repository` (#86); Apple on iOS only; no Save Account (linking an anonymous account) from Settings |
| App Check | `AppCheckProviderFactory` | M1 | done | `main_development.dart`, debug token registered in M1; the production flavor isn't configured |
| Offline data and sync | Sync engines | M1–M3 | done | Firestore cache + `writeLocally` (#111); no `ensureOnline` pre-checks (#146, #148, by decision) |
| Device-local preferences | `UserDefaults` | M5 | partial | proposal dismissals in a JSON file (#130); in memory only: the meal draft (#126), "Still training?" last asked (#127), banner, recap and invite-card dismissals and nudges (#131, #146), the review card's opened flag (#133) |
| Per-exercise unit preferences | `ExerciseUnitPreferenceManager` | M3 | todo | not ported; weights show in the profile's unit (#120, #133, #137) |
| Analytics events (Mixpanel, Firebase, Crashlytics) | `LogManager` | M3 | done | `analytics_repository` (#96) |
| Push notifications and deep links | `PushManager`, `DeepLink.swift` | M4 | partial | `notifications_repository` (#117), wiring (#127), inbox (#144), join links (#146); no in-app activity banner, delivered pushes not cleared on opening, no https share links |
| Local reminders | `PushManager` (local) | M4 | done | come-back and meal reminders, rest-over, "Still training?" (#127); permission prompt (#144) |
| Purchases and paywall (RevenueCat) | `PurchaseManager` | M4 | partial | `purchases_repository` (#114); no paywall UI, RevenueCat logIn not wired, both flavors pass a premium fake (#147) |
| A/B tests (Remote Config) | `ABTestManager` | M5 | todo | Swift runs `notificationsTest` and `paywallTest` |
| App rating prompt | `ReviewMoment` | M5 | todo | Swift asks after the week's goal workout or a 7-day food streak |
| HealthKit (iOS) and Health Connect (Android): steps, weight, workouts, meal import | `HealthKitManager`, `HKWorkoutManager` | M5 | partial | `health_repository` (#121), UI and native setup (#151); no live workout session (heart rate, active energy); HealthKit capability is an owner TODO |
| Live Activity and Dynamic Island (iOS); ongoing notification (Android) | `LiveActivityManager`, `WorkoutSessionActivity/` | M3 (Android), M6 (iOS) | partial | Android ongoing notification (#127); no foreground service; iOS at M6 |
| Home screen widgets | `WorkoutSessionActivity/HomeWidgets.swift` | M6 | todo | M6 |
| Siri and Shortcuts (App Intents) | `Managers/AppIntents` | M6 | todo | M6, with the `browse_recipes` shortcut (#145) |
| Strava upload and import | `StravaManager` | M5 | partial | `strava_repository` (#122), UI (#151); no `pushEdit` (sessions can't be edited yet); Keychain-token migration not ported |
| AI: food photo, meal description, nutrition label, image generation | `AIManager` | M5 | partial | `ai_repository` (#118); scanners in progress (#152), label OCR deferred there; image generation has no caller in Swift's screens |
| AI coach (streaming) | `CoachManager` | M5 | done | `coach_repository` (#118), UI (#147) |
| Image upload and progress photos | `ImageUploadManager` | M5 | partial | `image_repository` (#150): progress photos and the profile photo; food, recipe, gym and equipment images not done |
| Reporting and moderation | `ReportManager` | M5 | todo | no Report on profiles, sessions or comments |
| Haptics and sound effects | `HapticManager`, `SoundEffectManager` | M3 | partial | haptics in the views across slices; no in-app rest-complete sound (needs an audio package, #127) |
| Spanish localisation, 100% | `Localizable.xcstrings` | M1 | done | `scripts/arb-spanish.py`, CI check |
| iPad and wide layouts | `ContentWidth`, `Dashboard` | M6 | todo | only Progress's grid widens (2–4 columns, #103); no readable width or `Dashboard` |
| Mac (Catalyst) | Catalyst | M6 | todo | decided at M6; the macOS folder was removed (#82) |
| Methods & Sources (citations) | `Components/Science` | M4 | partial | `science/method_info.dart`: 18 of 31 methods (see MethodsAndSources) |

## Remaining work

Ordered by user value. Each slice is meant to be one PR into `feature/flutter`; it names the Swift
modules it finishes and the deferrals it closes.

### In progress
- **AI scanners** (#152, `flutter/m5-ai-scanners`): FoodPhotoScanner, MealDescribe, label mode of
  BarcodeScanner, the picker's AI and Describe tabs. Still open after it: on-device label OCR
  (`google_mlkit_text_recognition`), deferred by #152.

### Proposed slices
1. **Tracker: loading and set editing.** PlateCalculator, WorkoutExerciseEquipmentSheet (with #140's
   scoped gym editor), SetTrackerRow (set-type menu: drop, myo, warm-up; sub-sets; split sides;
   per-row custom rest; unit menu), SetKeyboard (bands chips, ± assisted key, stopwatch), the
   loading bar. Closes #125's "loading and set editing" list and #140's scoped-editor deferral.
2. **Tracker: exercise flow and settings.** SwapExercisePicker, ExerciseTracker (Do Next/Do Later,
   reordering, the progression note, Last tap-to-fill, previous-note hints), ExerciseSettings (weight
   and distance unit, rest timer, side-set rest, Edit Duplicate from #141) with per-exercise unit
   preferences, SetTarget's session scope, WorkoutTracker (Workout Settings from the menu, "Finish
   at", the per-attempt `finish_workout_save_error` event, Voice Control labels), TrainingAccessory
   (progress, rest countdown, Skip Rest). Closes the rest of #125's list and #133's per-exercise unit
   note.
3. **Editing a finished workout.** WorkoutSessionDetail: edit sets, start time and duration, Add
   Exercise, Delete; then Strava `pushEdit` (#151 deferral).
4. **Goals and diet outside onboarding.** Settings' Weight Goal flow (edit, or start new with the old
   goal abandoned) and Nutrition Plan (PreferredDiet from Settings); GoalProgress's Set/Change Goal;
   NutritionTargetChart's Create Diet Plan; ProgressCarousel's program targets and Active Program
   toggle. Closes #137's deferrals.
5. **Paywall and subscription.** Paywall, Onboarding Subscription, Welcome's non-premium gate,
   Settings' Subscription row, the coach's See Plans (#147), RevenueCat logIn with the uid, and the
   A/B tests (`paywallTest`, `notificationsTest`). Needs the RevenueCat owner TODO first.
6. **Reporting and moderation.** `ReportManager` port; Report on SocialProfile, WorkoutSessionRow and
   Comments; Save as Template from the feed card; the profile's "Following {mesocycle}" line (#131,
   #148 deferrals). The text Share link and Copy Link wait for the link-host owner decision below.
7. **Today, Training and Nutrition gaps.** Today's planned and rest-day checklist states (#101, #134),
   the step-goal picker and social pulse; CalendarHeader on Training (tap a day to open its sessions)
   and the Calendar month picker (#134); ExerciseModelDetail's Charts and Records tabs and
   WorkoutTemplateDetail's Watch link and per-set grid (#120); AddMeal's nutrient breakdown (#126);
   MealAccessory over every tab; Customise Food Log on the Nutrition tab; WorkoutConsistency's month
   labels and callout (#133); interactive charts (paging, press-and-hold readout, Energy Balance bars;
   #98, #130).
8. **Images for the rest.** Food (CreateFood), recipe (RecipePreparation), gym photo and equipment
   thumbnails (GymProfile), workout template pictures, and onboarding NamePhoto's photo (#140, #142,
   #145, #150 deferrals). FoodPackaging stays `todo` until the public food database ships (#142).
9. **Settings, account and polish.** Save Account (link an anonymous account from Settings), Rate and
   the review prompt (`ReviewMoment`), About's version (`package_info_plus`), the 13 missing
   `MethodInfo` entries and the ⓘ buttons on Expenditure and Smart Progression settings (#128),
   DevSettings, the in-app activity banner and clearing delivered pushes (#144), a device key-value
   store for every in-memory flag listed under Device-local preferences (#126, #127, #131, #133,
   #146), the rest-complete sound and an Android foreground service (#127), the haptic after the
   check-in weigh-in (#130), the first weekday from the device region (#101), bodyweight sets
   showing "@ 0 kg" (#93), `AppSelectableRow`'s semantics pattern (#141), and the new profile's
   missing `authProviders` and `creationVersion` (#116).

### Owner TODOs
- **RevenueCat:** apps for iOS `com.andrewcoyle.compound.flutter.dev` and Play
  `com.andrewcoyle.compound.dev`, the Play subscriptions on the same entitlement, and a Play
  service-account credential (#114).
- **Push:** upload the APNs key to `compound-development`; Push Notifications capability and the Time
  Sensitive entitlement on the Flutter dev bundle id; optionally the remote-notifications background
  mode (#117, #127). `compound://` is shared with the Swift app on one device (#127).
- **Health:** HealthKit capability and entitlement for the development and production bundle ids; the
  Play Console Health Connect declaration; a privacy policy page for the rationale screen (#121, #151).
- **Strava:** `STRAVA_CLIENT_ID` in `app/dart_defines.json`; confirm the dev Strava app's callback
  domain is `localhost` (#122, #151).
- **Mixpanel:** `MIXPANEL_TOKEN` in `app/dart_defines.json` (#96).
- **Native wording:** review the camera usage text and add its Spanish `InfoPlist.strings`; try the
  barcode scanner on a device (#126); `NSPhotoLibraryUsageDescription` is English only (#150).
- **Storage rules (dev):** any signed-in user can write and delete another user's photos; one
  leftover anonymous account in `compound-development` Auth (#150).
- **Firestore rules:** user exercises in `exercise_templates` are readable by every signed-in user
  (`swift-findings.md`).
- **Share links:** choose a dev-safe host for web share links and Copy Link (#148).
- **Legal and support:** publish the legal documents and the disclaimer's links (#116, #128).
- **Brand assets** for `app_ui` (the share cards draw a glyph, #148).
- **Production flavor:** it throws at launch until the prod project is configured (#86); Play
  Console account and closed test before Android 1.0 (plan, M3).
- The Swift findings in `swift-findings.md` each need the owner's decision.

### Waits for M6 (iOS)
- Live Activity and Dynamic Island (keep `WorkoutSessionActivity`, driven over a platform channel).
- Home screen widgets, and the widget snapshot on backgrounding (`AppPresenter`).
- Siri and Shortcuts (App Intents), the Siri settings screen and the `browse_recipes` shortcut (#145).
- AppIcon (alternate icons).
- Sign in with Apple on Android (iOS only today).
- iPad and wide layouts; the Mac Catalyst decision.
- iOS flavors under the existing bundle ids, the Strava Keychain-token migration (#122, #151), and the
  final Swift release that flushes pending writes.
