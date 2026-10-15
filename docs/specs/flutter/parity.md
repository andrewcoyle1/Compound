# Feature parity checklist

Every presenter-backed Swift screen module in `docs/codebase-map.md` (generated from it on
14 Oct 2026). Parity means each row is **done** in the Flutter app, or deliberately **dropped** with a
reason recorded in `decisions.md`. The milestone column is the plan's first estimate; slices may move rows.

Status: `todo`, `partial` (read-only or part of the screen), `done`, `dropped`.

| Area | Swift module | Folder | Milestone | Status | Flutter |
|---|---|---|---|---|---|
| Components | CalendarHeader | `Views/CalendarHeader` | M2 | todo | |
| Components | Calendar | `Views/CalendarHeader/Calendar` | M2 | todo | |
| Components | AuthorHeader | `Views/User` | M2 | done | social feed and profile (M5 Social 1) |
| Analytics | Analytics | `Compound/Core/Analytics` | M4 | partial | overview cards (#103); Expenditure and Energy Balance (#130); Muscle Groups and Exercises sections (#133); the carousel and the More list to come |
| Analytics | BodyMetrics | `Subviews/BodyMetrics` | M4 | todo | |
| Analytics | LogMeasurement | `Subviews/BodyMetrics/LogMeasurement` | M4 | todo | |
| Analytics | LogWeight | `Subviews/BodyMetrics/LogMeasurement/LogWeightView` | M4 | done | #106 (HealthKit export M5) |
| Analytics | ProgressPhotos | `Subviews/BodyMetrics/ProgressPhotos` | M4 | todo | |
| Analytics | ScaleWeight | `Subviews/BodyMetrics/ScaleWeight` | M4 | partial | read-only + Log Weight (#98, #106) |
| Analytics | ExerciseAnalytics | `Subviews/ExerciseAnalytics` | M4 | done | #133 (profile unit, not per-exercise) |
| Analytics | ExerciseDetail | `Subviews/ExerciseAnalytics/ExerciseDetail` | M4 | done | #133 |
| Analytics | FoodLoggingConsistency | `Subviews/FoodLoggingConsistency` | M4 | todo | |
| Analytics | Habits | `Subviews/Habits` | M4 | partial | card on Progress (#103) |
| Analytics | InsightsAndAnalytics | `Subviews/InsightsAndAnalytics` | M4 | todo | |
| Analytics | EnergyBalance | `Subviews/InsightsAndAnalytics/EnergyBalance` | M4 | todo | |
| Analytics | ExpenditureDetail | `Subviews/InsightsAndAnalytics/ExpenditureDetail` | M4 | todo | |
| Analytics | GoalProgress | `Subviews/InsightsAndAnalytics/GoalProgress` | M4 | partial | card on Progress (#103) |
| Analytics | MuscleGroupDetail | `Subviews/InsightsAndAnalytics/MuscleGroupDetail` | M4 | done | #133 (Ask Coach waits for the coach UI) |
| Analytics | Steps | `Subviews/InsightsAndAnalytics/Steps` | M4 | todo | |
| Analytics | WeightTrend | `Subviews/InsightsAndAnalytics/WeightTrend` | M4 | partial | read-only (#98) |
| Analytics | Workout | `Subviews/InsightsAndAnalytics/Workouts` | M4 | done | #133 |
| Analytics | MuscleBalance | `Subviews/MuscleBalance` | M4 | done | #133 |
| Analytics | MuscleGroups | `Subviews/MuscleGroups` | M4 | done | #133 |
| Analytics | NutritionAnalytics | `Subviews/NutritionAnalytics` | M4 | todo | |
| Analytics | NutritionMetricDetail | `Subviews/NutritionAnalytics/NutritionMetricDetail` | M4 | todo | |
| Analytics | NutritionTargetChart | `Subviews/NutritionTargetChart` | M4 | todo | |
| Analytics | ProgressCarousel | `Subviews/ProgressCarousel` | M4 | todo | |
| Analytics | WeighInConsistency | `Subviews/WeighInConsistency` | M4 | todo | |
| Analytics | WorkoutConsistency | `Subviews/WorkoutConsistency` | M4 | done | #133 (no month labels or press callout) |
| AppView | App | `Compound/Core/AppView` | M1 | partial | sign-in redirect, shell (#86, #90) |
| Challenges | ChallengeDetail | `ChallengeDetail` | M5 | todo | |
| Challenges | CreateChallenge | `CreateChallenge` | M5 | todo | |
| Coach | Coach | `Compound/Core/Coach` | M5 | todo | |
| DevSettings | DevSettings | `Compound/Core/DevSettings` | M5 | todo | |
| Notifications | Notifications | `Compound/Core/Notifications` | M5 | todo | |
| Notifications | NotificationSettings | `NotificationSettings` | M5 | todo | |
| Nutrition | Nutrition | `Compound/Core/Nutrition` | M3 | partial | read-only day view (#95) |
| Nutrition | CheckIn | `CheckIn` | M3 | todo | |
| Nutrition | IngredientListBuilder | `Components/IngredientListBuilder` | M3 | todo | |
| Nutrition | MealAccessory | `Components/MealAccessory` | M3 | todo | |
| Nutrition | MealHourHeader | `Components/MealHourHeader` | M3 | todo | |
| Nutrition | RecipeListBuilder | `Components/RecipeListBuilder` | M3 | todo | |
| Nutrition | Foods | `Foods` | M3 | todo | |
| Nutrition | CreateFood | `Foods/CreateFood` | M3 | todo | |
| Nutrition | FoodDefinition | `Foods/CreateFood/FoodDefinition` | M3 | todo | |
| Nutrition | FoodPackaging | `Foods/CreateFood/FoodPackaging` | M3 | todo | |
| Nutrition | PortionDefinition | `Foods/CreateFood/PortionDefinition` | M3 | todo | |
| Nutrition | FoodDetail | `Foods/FoodDetail` | M3 | todo | |
| Nutrition | AddMeal | `MealLog/AddMeal` | M3 | todo | |
| Nutrition | IngredientAmount | `MealLog/IngredientAmount` | M3 | todo | |
| Nutrition | MealDetail | `MealLog/MealDetail` | M3 | todo | |
| Nutrition | MealItemAmountView | `MealLog/MealItemAmountView` | M3 | todo | |
| Nutrition | NutritionLibraryPicker | `MealLog/NutritionLibraryPicker` | M3 | todo | |
| Nutrition | BarcodeScanner | `MealLog/NutritionLibraryPicker/BarcodeScanner` | M3 | todo | |
| Nutrition | FoodItemQuickAdd | `MealLog/NutritionLibraryPicker/FoodItemQuickAdd` | M3 | todo | |
| Nutrition | FoodItemSearch | `MealLog/NutritionLibraryPicker/FoodItemSearch` | M3 | todo | |
| Nutrition | FoodLibrary | `MealLog/NutritionLibraryPicker/FoodLibrary` | M3 | todo | |
| Nutrition | FoodPhotoScanner | `MealLog/NutritionLibraryPicker/FoodPhotoScanner` | M3 | todo | |
| Nutrition | MealDescribe | `MealLog/NutritionLibraryPicker/MealDescribe` | M3 | todo | |
| Nutrition | RecipeAmount | `MealLog/RecipeAmount` | M3 | todo | |
| Nutrition | NutritionOverview | `NutritionOverview` | M3 | todo | |
| Nutrition | Recipes | `Recipes` | M3 | todo | |
| Nutrition | CreateRecipe | `Recipes/CreateRecipe` | M3 | todo | |
| Nutrition | RecipeIngredientAmount | `Recipes/CreateRecipe/RecipeIngredientAmount` | M3 | todo | |
| Nutrition | RecipePreparation | `Recipes/CreateRecipe/RecipePreparation` | M3 | todo | |
| Nutrition | RecipeDetail | `Recipes/RecipeDetail` | M3 | todo | |
| Nutrition | RecipeStart | `Recipes/RecipeStart` | M3 | todo | |
| Nutrition | TimelineActions | `TimelineActions` | M3 | todo | |
| Onboarding | Welcome | `0 - WelcomeView` | M3 | partial | onboarding flow (#116) |
| Onboarding | Auth | `2 - AuthView` | M3 | partial | onboarding flow (#116) |
| Onboarding | Subscription | `3 - Subscription` | M3 | todo | |
| Onboarding | NamePhoto | `4 - CompleteAccountSetup/1 - NamePhoto` | M3 | todo | |
| Onboarding | Gender | `4 - CompleteAccountSetup/2 - Gender` | M3 | partial | onboarding flow (#116) |
| Onboarding | DateOfBirth | `4 - CompleteAccountSetup/3 - DateOfBirth` | M3 | partial | onboarding flow (#116) |
| Onboarding | Height | `4 - CompleteAccountSetup/4 - Height` | M3 | partial | onboarding flow (#116) |
| Onboarding | Weight | `4 - CompleteAccountSetup/5 - Weight` | M3 | partial | onboarding flow (#116) |
| Onboarding | ExerciseFrequency | `4 - CompleteAccountSetup/6 - ExerciseFrequency` | M3 | partial | onboarding flow (#116) |
| Onboarding | Activity | `4 - CompleteAccountSetup/7 - Activity` | M3 | partial | onboarding flow (#116) |
| Onboarding | Expenditure | `4 - CompleteAccountSetup/9 - Expenditure` | M3 | partial | onboarding flow (#116) |
| Onboarding | HealthDisclaimer | `5 - HealthDisclaimer` | M3 | todo | |
| Onboarding | OverarchingObjective | `6 - GoalSetting/1 - OverarchingObjective` | M3 | partial | onboarding flow (#116) |
| Onboarding | TargetWeight | `6 - GoalSetting/2 - TargetWeight` | M3 | partial | onboarding flow (#116) |
| Onboarding | WeightRate | `6 - GoalSetting/3 - WeightRate` | M3 | partial | onboarding flow (#116) |
| Onboarding | GoalSummary | `6 - GoalSetting/4 - GoalSummary` | M3 | partial | onboarding flow (#116) |
| Onboarding | CustomisingDietProgram | `8 - OnboardingDiet` | M3 | partial | onboarding flow (#116) |
| Onboarding | PreferredDiet | `8 - OnboardingDiet/1 - PreferredDiet` | M3 | partial | onboarding flow (#116) |
| Onboarding | CalorieFloor | `8 - OnboardingDiet/2 - CalorieFloor` | M3 | partial | onboarding flow (#116) |
| Onboarding | CalorieDistribution | `8 - OnboardingDiet/4 - CalorieDistribution` | M3 | partial | onboarding flow (#116) |
| Onboarding | ProteinIntake | `8 - OnboardingDiet/5 - ProteinIntake` | M3 | partial | onboarding flow (#116) |
| Onboarding | DietPlan | `8 - OnboardingDiet/6 - DietPlan` | M3 | partial | onboarding flow (#116) |
| Onboarding | OnboardingCompleted | `9 - OnboardingCompleted` | M3 | partial | onboarding flow (#116) |
| Paywalls | Paywall | `Paywall` | M4 | todo | |
| Profile | Settings | `Compound/Core/Profile` | M5 | todo | |
| Profile | About | `Subviews/About` | M5 | todo | |
| Profile | Licences | `Subviews/About/Licences` | M5 | todo | |
| Profile | AppIcon | `Subviews/AppIcon` | M5 | todo | |
| Profile | EditProfile | `Subviews/EditProfile` | M5 | todo | |
| Profile | DeleteAccount | `Subviews/EditProfile/DeleteAccount` | M5 | todo | |
| Profile | EditUsername | `Subviews/EditProfile/EditUsername` | M5 | done | from Edit Profile and Social (M5 Social 1) |
| Profile | CustomiseAnalytics | `Subviews/GeneralSettings/CustomiseAnalytics` | M5 | todo | |
| Profile | Integrations | `Subviews/GeneralSettings/Integrations` | M5 | todo | |
| Profile | Siri | `Subviews/GeneralSettings/Siri` | M5 | todo | |
| Profile | Units | `Subviews/GeneralSettings/Units` | M5 | todo | |
| Profile | Legal | `Subviews/Legal` | M5 | todo | |
| Profile | MethodsAndSources | `Subviews/MethodsAndSources` | M5 | todo | |
| Profile | ExpenditureSettings | `Subviews/NutritionSettings/ExpenditureSettings` | M5 | todo | |
| Profile | FoodLogSettings | `Subviews/NutritionSettings/FoodLogSettings` | M5 | todo | |
| Profile | FavouriteMeasurements | `Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements` | M5 | todo | |
| Profile | LoggerBanner | `Subviews/NutritionSettings/FoodLogSettings/LoggerBanner` | M5 | todo | |
| Profile | LoggerFoodTiles | `Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles` | M5 | todo | |
| Profile | TimelineFoodTiles | `Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles` | M5 | todo | |
| Profile | StrategySettings | `Subviews/NutritionSettings/StrategySettings` | M5 | todo | |
| Profile | ExerciseAssessment | `Subviews/TrainingSettings/ExerciseAssessment` | M5 | todo | |
| Profile | GymProfiles | `Subviews/TrainingSettings/GymProfiles` | M5 | todo | |
| Profile | GymProfile | `Subviews/TrainingSettings/GymProfiles/GymProfile` | M5 | todo | |
| Profile | AddGymMachine | `Subviews/TrainingSettings/GymProfiles/GymProfile/AddGymMachine` | M5 | todo | |
| Profile | CreateGymProfile | `Subviews/TrainingSettings/GymProfiles/GymProfile/CreateGymProfile` | M5 | todo | |
| Profile | EditBand | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand` | M5 | todo | |
| Profile | AddBand | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBand/AddBand` | M5 | todo | |
| Profile | EditBodyWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight` | M5 | todo | |
| Profile | AddBodyWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditBodyWeight/AddBodyWeight` | M5 | todo | |
| Profile | EditFixedWeightBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar` | M5 | todo | |
| Profile | AddFixedWeightBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFixedWeightBar/AddFixedWeightBar` | M5 | todo | |
| Profile | EditFreeWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight` | M5 | todo | |
| Profile | AddFreeWeight | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditFreeWeight/AddFreeWeight` | M5 | todo | |
| Profile | EditLoadableAccessory | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableAccessory` | M5 | todo | |
| Profile | EditLoadableBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar` | M5 | todo | |
| Profile | AddLoadableBar | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditLoadableBar/AddLoadableBar` | M5 | todo | |
| Profile | EditPlateLoadedMachine | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditPlateLoadedMachine` | M5 | todo | |
| Profile | EditStackMachine | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditStackMachine` | M5 | todo | |
| Profile | AddWeightStack | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditStackMachine/AddWeightStack` | M5 | todo | |
| Profile | EditWeightRange | `Subviews/TrainingSettings/GymProfiles/GymProfile/EditWeightRange` | M5 | todo | |
| Profile | WorkoutSettings | `Subviews/TrainingSettings/WorkoutSettings` | M5 | todo | |
| Profile | RestTimerSettings | `Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings` | M5 | todo | |
| Profile | TimerDuration | `Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration` | M5 | todo | |
| Profile | SmartProgressionSettings | `Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings` | M5 | todo | |
| Profile | Tutorials | `Subviews/Tutorials` | M5 | todo | |
| Sharing | ShareToFollower | `ShareToFollower` | M5 | todo | |
| Sharing | SharedItem | `SharedItem` | M5 | todo | |
| Social | Social | `Compound/Core/Social` | M5 | partial | strip, leaderboard, recap, feed, search (M5 Social 1); bell, invites, challenges in part 2 |
| Social | WeeklyGoal | `CircleGoals/WeeklyGoal` | M5 | done | M5 Social 1 |
| Social | SocialProfile | `SocialProfile` | M5 | partial | own and others, follow, block, privacy (M5 Social 1); Strava year, Share Profile, Report to come |
| Social | FollowersList | `SocialProfile/FollowersList` | M5 | done | M5 Social 1 |
| Social | WorkoutSessionRow | `WorkoutSessionRow` | M5 | partial | likes and comments (M5 Social 1); share, Save as Template, Report to come |
| Social | Comments | `WorkoutSessionRow/Comments` | M5 | partial | replies, likes, mentions, delete (M5 Social 1); Report to come |
| TabBar | TabBar | `Compound/Core/TabBar` | M1 | done | five tabs, per-tab stacks, deep-link paths (#90) |
| Today | Today | `Compound/Core/Today` | M2 | partial | checklist, streak, protein gap (#101); today's workout and macrocycle repeat (M5 Programs 1) |
| Today | WeeklyReview | `WeeklyReview` | M2 | partial | #133; share card, Strava line and Ask Coach deferred |
| Training | Training | `Compound/Core/Training` | M3 | partial | search, active mesocycle, library rows (M5 Programs 1); + menu with Start Empty Workout, New Macrocycle, New Mesocycle (M5 Programs 2) and New Workout (M5 workout editor); calendar header and New Exercise to come |
| Training | TodaysWorkoutCard | `Components/TodaysWorkoutCard` | M3 | done | M5 Programs 1 |
| Training | TrainingAccessory | `Components/TrainingAccessory` | M3 | todo | |
| Training | WorkoutStreak | `Components/WorkoutStreakCard` | M3 | todo | |
| Training | CreateExercise | `Exercises/CreateExercise` | M3 | todo | |
| Training | EquipmentPicker | `Exercises/CreateExercise/EquipmentPicker` | M3 | todo | |
| Training | ExerciseEquipment | `Exercises/CreateExercise/ExerciseEquipment` | M3 | todo | |
| Training | ExerciseSave | `Exercises/CreateExercise/ExerciseSave` | M3 | todo | |
| Training | FinalExerciseDetails | `Exercises/CreateExercise/FinalExerciseDetails` | M3 | todo | |
| Training | MuscleGroupPicker | `Exercises/CreateExercise/MuscleGroupPicker` | M3 | todo | |
| Training | ExerciseListBuilder | `Exercises/ExerciseListBuilder` | M3 | todo | |
| Training | ExerciseModelDetail | `Exercises/ExerciseModelDetail` | M3 | partial | read-only library (#120) |
| Training | Exercises | `Exercises/Exercises` | M3 | partial | read-only library (#120) |
| Training | ActiveMesocycle | `Programs/ActiveMesocycle` | M3 | partial | schedule, microcycle picker, skip, rest days, delete (M5 Programs 1); Info opens the editor (M5 Programs 2); Ask Coach to come |
| Training | CreateMesocycle | `Programs/CreateMesocycle` | M3 | done | onboarding's chooser is the program step (#116), with Build My Own (M5 workout editor); from the library the flow opens on the name, as in Swift (M5 Programs 2) |
| Training | EditDayOrder | `Programs/CreateMesocycle/EditDayOrder` | M3 | done | M5 Programs 2 |
| Training | EditDeload | `Programs/CreateMesocycle/EditDeload` | M3 | done | M5 Programs 2 |
| Training | EditMesocycleColourIcon | `Programs/CreateMesocycle/EditMesocycleColourIcon` | M3 | done | M5 Programs 2 |
| Training | MesocycleDesign | `Programs/CreateMesocycle/MesocycleDesign` | M3 | partial | days, add, remove, rename, settings, activate, save, delete (M5 Programs 2); each day's exercises in the workout editor (M5 workout editor); Share to come |
| Training | MesocycleIcon | `Programs/CreateMesocycle/MesocycleIcon` | M3 | done | M5 Programs 2 |
| Training | MesocycleSettings | `Programs/CreateMesocycle/MesocycleSettings` | M3 | done | M5 Programs 2 |
| Training | NameMesocycle | `Programs/CreateMesocycle/NameMesocycle` | M3 | done | M5 Programs 2 |
| Training | RenameWorkoutTemplateModel | `Programs/CreateMesocycle/RenameWorkoutTemplateModel` | M3 | done | M5 Programs 2 |
| Training | ImportProgram | `Programs/ImportProgram` | M3 | done | M5 Programs 2: xlsx, csv and the app's JSON |
| Training | Macrocycles | `Programs/Macrocycles` | M3 | done | M5 Programs 1 and 2 |
| Training | MacrocycleDetail | `Programs/Macrocycles/MacrocycleDetail` | M3 | done | M5 Programs 1 |
| Training | MesocycleLibrary | `Programs/MesocycleLibrary` | M3 | done | M5 Programs 1 and 2 |
| Training | InactiveMesocycle | `Programs/MesocycleLibrary/InactiveMesocycle` | M3 | done | M5 Programs 1 |
| Training | MesocycleDisclosureGroup | `Programs/MesocycleLibrary/MesocycleDisclosureGroup` | M3 | partial | M5 Programs 1; Edit in its menu (part 2); Share with Friends to come |
| Training | PrebuiltMesocycleDetail | `Programs/MesocycleLibrary/PrebuiltMesocycleDetail` | M3 | done | M5 Programs 1 |
| Training | ExerciseTracker | `Session/ExerciseTracker` | M3 | todo | |
| Training | ExerciseSettings | `Session/ExerciseTracker/ExerciseSettings` | M3 | todo | |
| Training | SetTrackerRow | `Session/ExerciseTracker/SetTrackerRow` | M3 | todo | |
| Training | PlateCalculator | `Session/ExerciseTracker/SetTrackerRow/PlateCalculator` | M3 | todo | |
| Training | SetKeyboard | `Session/ExerciseTracker/SetTrackerRow/SetKeyboard` | M3 | todo | |
| Training | SwapExercisePicker | `Session/ExerciseTracker/SwapExercisePicker` | M3 | todo | |
| Training | WorkoutExerciseEquipmentSheet | `Session/ExerciseTracker/WorkoutExerciseEquipmentSheet` | M3 | todo | |
| Training | WorkoutHistory | `Session/WorkoutHistory` | M3 | partial | read-only (#93) |
| Training | WorkoutNotes | `Session/WorkoutNotes` | M3 | todo | |
| Training | WorkoutSessionDetail | `Session/WorkoutSessionDetail` | M3 | partial | read-only (#93) |
| Training | WorkoutTracker | `Session/WorkoutTracker` | M3 | todo | |
| Training | ChooseGymProfile | `Workouts/CreateWorkout/ChooseGymProfile` | M3 | partial | M5 workout editor; Create Gym Profile waits for the gym editor |
| Training | DefineWorkout | `Workouts/CreateWorkout/DefineWorkout` | M3 | done | M5 workout editor |
| Training | DefineWorkoutWrapper | `Workouts/CreateWorkout/DefineWorkoutWrapper` | M3 | done | M5 workout editor |
| Training | ExercisesPicker | `Workouts/CreateWorkout/ExercisesPicker` | M3 | done | #120's picker, for exercises and substitutions (M5 workout editor) |
| Training | NameWorkout | `Workouts/CreateWorkout/NameWorkout` | M3 | done | M5 workout editor |
| Training | SetTarget | `Workouts/CreateWorkout/SetTarget` | M3 | done | targets, set plan sheet and the exercise's plan (M5 workout editor); the tracker's session scope comes with the tracker editor |
| Training | WeeklyTargets | `Workouts/CreateWorkout/SetTarget/WeeklyTargets` | M3 | done | M5 workout editor |
| Training | WorkoutTemplateDetail | `Workouts/WorkoutTemplateDetail` | M3 | partial | read-only library (#120); Start, a program day's week and deload (M5 Programs 1); a mesocycle day's Edit Mesocycle and Save a Copy (M5 Programs 2); a library workout's Edit and Delete (M5 workout editor); Share to come |
| Training | Workouts | `Workouts/Workouts` | M3 | partial | read-only library (#120) |

198 modules.

## Platform features (not screen modules)

| Feature | Swift | Milestone | Status | Flutter |
|---|---|---|---|---|
| Sign in: Apple, Google, anonymous, account linking | SwiftfulAuthenticating | M1 | done | `auth_repository` (#86) |
| Offline data and sync | Sync engines | M1–M3 | done | Firestore cache + `writeLocally` (#111) |
| Analytics events (Mixpanel, Firebase, Crashlytics) | `LogManager` | M3 | done | `analytics_repository` (#96) |
| Push notifications and deep links | `PushManager`, `DeepLink.swift` | M4 | partial | `notifications_repository` (#117); app wiring pending |
| Purchases and paywall (RevenueCat) | `PurchaseManager` | M4 | partial | `purchases_repository` (#114); RevenueCat setup is the owner's |
| A/B tests (Remote Config) | `ABTestManager` | M5 | todo | |
| HealthKit (iOS) and Health Connect (Android): steps, weight, workouts, meal import | `HealthKitManager`, `HKWorkoutManager` | M5 | partial | `health_repository` (#121); native setup pending |
| Live Activity and Dynamic Island (iOS); ongoing notification (Android) | `LiveActivityManager`, `WorkoutSessionActivity/` | M3 (Android), M6 (iOS) | todo | |
| Home screen widgets | `WorkoutSessionActivity/HomeWidgets.swift` | M6 | todo | |
| Siri and Shortcuts (App Intents) | `Managers/AppIntents` | M6 | todo | |
| Strava upload and import | `StravaManager` | M5 | partial | `strava_repository` (#122) |
| AI: food photo, meal description, nutrition label, image generation | `AIManager` | M5 | partial | `ai_repository` (#118) |
| AI coach (streaming) | `CoachManager` | M5 | partial | `coach_repository` (#118) |
| Image upload and progress photos | `ImageUploadManager` | M5 | todo | |
| Reporting and moderation | `ReportManager` | M5 | todo | |
| Haptics and sound effects | `HapticManager`, `SoundEffectManager` | M3 | todo | |
| Spanish localisation, 100% | `Localizable.xcstrings` | M1 | done | `scripts/arb-spanish.py`, CI check |
| iPad and wide layouts | `ContentWidth`, `Dashboard` | M6 | todo | |
| Mac (Catalyst) | Catalyst | M6 | todo | Decided at M6 |
| Methods & Sources (citations) | `Components/Science` | M4 | todo | |
