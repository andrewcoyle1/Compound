# Feature parity checklist

Every presenter-backed Swift screen module in `docs/codebase-map.md` (generated from it on
14 Oct 2026). Parity means each row is **done** in the Flutter app, or deliberately **dropped** with a
reason recorded in `decisions.md`. The milestone column is the plan's first estimate; slices may move rows.

Status: `todo`, `partial` (the gap is named), `done`, `dropped`. Flutter paths are under `app/lib/`.

**Swept 16 Oct 2026, through #172** (every slice merged into `feature/flutter`; nothing is open).
Each `partial` and `todo` row was checked against the Swift presenter's actions and router
destinations, the Flutter code and routes, and the Decisions, Deferred and gaps sections of #152,
#154–#159, #161–#168 and #170–#172. A sample of `done` rows was re-checked; that found one gap no PR
had listed, Swift's `ReminderOfferFlow`, which reopens Today, Nutrition and Local reminders.

| | done | partial | todo | dropped | total |
|---|---|---|---|---|---|
| Screen modules | 191 | 3 | 1 | 3 | 198 |
| Platform features | 20 | 4 | 0 | 1 | 25 |

The open work is grouped under [Remaining work](#remaining-work) at the end: follow-up slices, what waits on the owner, and M6.

| Area | Swift module | Folder | Milestone | Status | Flutter |
|---|---|---|---|---|---|
| Components | CalendarHeader | `Views/CalendarHeader` | M2 | done | #164, `widgets/calendar/`: one header for Training and Nutrition, with markers and Return to Today; week-paged by decision (#95, #164) |
| Components | Calendar | `Views/CalendarHeader/Calendar` | M2 | done | #164, the month picker from both tabs' toolbars (18 months back, 6 ahead) |
| Components | AuthorHeader | `Views/User` | M2 | done | #131, social feed and profile |
| Analytics | Analytics | `Compound/Core/Analytics` | M4 | done | #103, #130, #133, #137 (`progress/`) |
| Analytics | BodyMetrics | `Subviews/BodyMetrics` | M4 | done | #137; Photos row (#150); Sync from Apple Health on Visual Body Fat (#151) |
| Analytics | LogMeasurement | `Subviews/BodyMetrics/LogMeasurement` | M4 | done | #137, `/log-measurement/:kind`; half sheet (#195) |
| Analytics | LogWeight | `Subviews/BodyMetrics/LogMeasurement/LogWeightView` | M4 | done | #106; export to Health first (#151); half sheet (#195) |
| Analytics | ProgressPhotos | `Subviews/BodyMetrics/ProgressPhotos` | M4 | done | #150, `/progress/body-metrics/photos` and compare |
| Analytics | ScaleWeight | `Subviews/BodyMetrics/ScaleWeight` | M4 | done | #98, #106, #137; Health import on appear (#151) |
| Analytics | ExerciseAnalytics | `Subviews/ExerciseAnalytics` | M4 | done | #133; each exercise's own unit (#163) |
| Analytics | ExerciseDetail | `Subviews/ExerciseAnalytics/ExerciseDetail` | M4 | done | #133; Ask Coach (#147) |
| Analytics | FoodLoggingConsistency | `Subviews/FoodLoggingConsistency` | M4 | done | #137 |
| Analytics | Habits | `Subviews/Habits` | M4 | done | #137 |
| Analytics | InsightsAndAnalytics | `Subviews/InsightsAndAnalytics` | M4 | done | #137 |
| Analytics | EnergyBalance | `Subviews/InsightsAndAnalytics/EnergyBalance` | M4 | done | #130; intake as bars under the expenditure line, paging and readout (#168); Ask Coach (#147) |
| Analytics | ExpenditureDetail | `Subviews/InsightsAndAnalytics/ExpenditureDetail` | M4 | done | #130, with Edit Profile; Ask Coach (#147) |
| Analytics | GoalProgress | `Subviews/InsightsAndAnalytics/GoalProgress` | M4 | done | #137; Set Goal and Change Goal (#154) |
| Analytics | MuscleGroupDetail | `Subviews/InsightsAndAnalytics/MuscleGroupDetail` | M4 | done | #133; Ask Coach (#147) |
| Analytics | Steps | `Subviews/InsightsAndAnalytics/Steps` | M4 | done | #137; access ask and Sync from Apple Health (#151) |
| Analytics | WeightTrend | `Subviews/InsightsAndAnalytics/WeightTrend` | M4 | done | #98, #137; Ask Coach (#147) |
| Analytics | Workout | `Subviews/InsightsAndAnalytics/Workouts` | M4 | done | #133 |
| Analytics | MuscleBalance | `Subviews/MuscleBalance` | M4 | done | #133 |
| Analytics | MuscleGroups | `Subviews/MuscleGroups` | M4 | done | #133 |
| Analytics | NutritionAnalytics | `Subviews/NutritionAnalytics` | M4 | done | #137 |
| Analytics | NutritionMetricDetail | `Subviews/NutritionAnalytics/NutritionMetricDetail` | M4 | done | #137 |
| Analytics | NutritionTargetChart | `Subviews/NutritionTargetChart` | M4 | done | #137; Create Diet Plan (#154) |
| Analytics | ProgressCarousel | `Subviews/ProgressCarousel` | M4 | done | #137; Weekly Workouts' program targets and Active Program toggle (#176) |
| Analytics | WeighInConsistency | `Subviews/WeighInConsistency` | M4 | done | #137 |
| Analytics | WorkoutConsistency | `Subviews/WorkoutConsistency` | M4 | done | #133; month labels, weekday initials and press-and-hold readout (#168), in Swift's floating callout (#194) |
| AppView | App | `Compound/Core/AppView` | M1 | partial | redirect and shell (#86, #90), profile gate and launch retry (#116), push token, reminders and held links (#127), first-page inbox read (#144), subscription gate (#155), in-app activity banner (#172); widget snapshot on backgrounding and Live Activity buttons (#184) |
| Challenges | ChallengeDetail | `ChallengeDetail` | M5 | done | #146, `/challenges/:challengeId` |
| Challenges | CreateChallenge | `CreateChallenge` | M5 | done | #146, `/challenges/new` |
| Coach | Coach | `Compound/Core/Coach` | M5 | done | #147, `/coach` and `/coach-chats`; See Plans opens the paywall (#155); relative chat times, swipe to delete (#195) |
| DevSettings | DevSettings | `Compound/Core/DevSettings` | M5 | done | #166, a Settings row outside production; A/B overrides, kept on the device (#186); seeding resets not needed (#166); share-card export through the share sheet (#177) |
| Notifications | Notifications | `Compound/Core/Notifications` | M5 | done | #144, `/social/notifications`; share and challenge rows open (#146, #148); delivered pushes cleared on opening (#172); swipe actions (#195) |
| Notifications | NotificationSettings | `NotificationSettings` | M5 | done | #128; permission prompt (#144); reminders applied by #127 |
| Nutrition | Nutrition | `Compound/Core/Nutrition` | M3 | done | #95, #126, #130, #142, #145, #147, #151; calendar header (#164); Customize Food Log row (#167); meal-reminder offer on the first visit (#176); swipe actions: Log Again, Meal, Delete (#195) |
| Nutrition | CheckIn | `CheckIn` | M3 | done | #130, `/check-in`; Ask Coach (#147) |
| Nutrition | IngredientListBuilder | `Components/IngredientListBuilder` | M3 | done | #142, #145 |
| Nutrition | MealAccessory | `Components/MealAccessory` | M3 | done | #126; over every tab, hidden during a workout (#167); draft kept on the device per account (#170) |
| Nutrition | MealHourHeader | `Components/MealHourHeader` | M3 | done | #126, + per hour |
| Nutrition | RecipeListBuilder | `Components/RecipeListBuilder` | M3 | done | #145 |
| Nutrition | Foods | `Foods` | M3 | done | #142, `/nutrition/foods` |
| Nutrition | CreateFood | `Foods/CreateFood` | M3 | done | #142, `/create-food`; food photo (#161) |
| Nutrition | FoodDefinition | `Foods/CreateFood/FoodDefinition` | M3 | done | #142 |
| Nutrition | FoodPackaging | `Foods/CreateFood/FoodPackaging` | M3 | todo | deferred by #142: unreachable in Swift (public contribution switched off), photos only |
| Nutrition | PortionDefinition | `Foods/CreateFood/PortionDefinition` | M3 | done | #142 (the serving option, the only one Swift offers) |
| Nutrition | FoodDetail | `Foods/FoodDetail` | M3 | done | #142, `/nutrition/foods/:foodId`; picture (#161) |
| Nutrition | AddMeal | `MealLog/AddMeal` | M3 | done | #126, `/log-meal`; Show all nutrients (#167); draft on the device (#170); swipe Delete and Edit (#195) |
| Nutrition | IngredientAmount | `MealLog/IngredientAmount` | M3 | done | #126 (amount sheet) |
| Nutrition | MealDetail | `MealLog/MealDetail` | M3 | done | #142, `/nutrition/meal/:mealId` |
| Nutrition | MealItemAmountView | `MealLog/MealItemAmountView` | M3 | done | #126 (plate); #142 (timeline) |
| Nutrition | NutritionLibraryPicker | `MealLog/NutritionLibraryPicker` | M3 | done | #126, #145, #152: Swift's six tabs in order |
| Nutrition | BarcodeScanner | `MealLog/NutritionLibraryPicker/BarcodeScanner` | M3 | done | #126 barcode mode; label mode (#152); torch (#180); on-device label OCR from a photo (#185): Vision on iOS, ML Kit on Android, not Swift's live scanner; Swift's offline pre-check (`ensureOnline`, #196) |
| Nutrition | FoodItemQuickAdd | `MealLog/NutritionLibraryPicker/FoodItemQuickAdd` | M3 | done | #126 |
| Nutrition | FoodItemSearch | `MealLog/NutritionLibraryPicker/FoodItemSearch` | M3 | done | #126; recipes (#145) |
| Nutrition | FoodLibrary | `MealLog/NutritionLibraryPicker/FoodLibrary` | M3 | done | #126; Recipes / Foods / Favorites (#145) |
| Nutrition | FoodPhotoScanner | `MealLog/NutritionLibraryPicker/FoodPhotoScanner` | M3 | done | #152, the AI tab (system camera from Take Photo, no live preview, by decision); Swift's offline pre-check (`ensureOnline`, #196) |
| Nutrition | MealDescribe | `MealLog/NutritionLibraryPicker/MealDescribe` | M3 | done | #152, the Describe tab; Swift's offline pre-check (`ensureOnline`, #196) |
| Nutrition | RecipeAmount | `MealLog/RecipeAmount` | M3 | done | #145 |
| Nutrition | NutritionOverview | `NutritionOverview` | M3 | done | #130, `/nutrition/overview` |
| Nutrition | Recipes | `Recipes` | M3 | done | #145, `/nutrition/recipes` |
| Nutrition | CreateRecipe | `Recipes/CreateRecipe` | M3 | done | #145, `/create-recipe`; swipe to delete ingredients (#195) |
| Nutrition | RecipeIngredientAmount | `Recipes/CreateRecipe/RecipeIngredientAmount` | M3 | done | #145 |
| Nutrition | RecipePreparation | `Recipes/CreateRecipe/RecipePreparation` | M3 | done | #145; photo (#161) |
| Nutrition | RecipeDetail | `Recipes/RecipeDetail` | M3 | done | #145, `/nutrition/recipes/:id`; picture (#161) |
| Nutrition | RecipeStart | `Recipes/RecipeStart` | M3 | done | #145 |
| Nutrition | TimelineActions | `TimelineActions` | M3 | done | #142 |
| Onboarding | Welcome | `0 - WelcomeView` | M3 | done | the sign-in page stands in (#86, #116); a non-premium user is held at `/subscribe` (#155) |
| Onboarding | Auth | `2 - AuthView` | M3 | done | `sign_in/` (#86): Apple, Google and anonymous; Apple on Android through Firebase's web flow (#191); Apple's button on both (#194); Google's branded button, matched to Apple's (#197) |
| Onboarding | Subscription | `3 - Subscription` | M3 | done | #155, `/subscribe` (Why Subscribe) and `/subscribe/plans` |
| Onboarding | NamePhoto | `4 - CompleteAccountSetup/1 - NamePhoto` | M3 | done | #116; photo (#161) |
| Onboarding | Gender | `4 - CompleteAccountSetup/2 - Gender` | M3 | done | #116; Fill from Apple Health on iOS (#151) |
| Onboarding | DateOfBirth | `4 - CompleteAccountSetup/3 - DateOfBirth` | M3 | done | #116; Fill from Apple Health on iOS (#151) |
| Onboarding | Height | `4 - CompleteAccountSetup/4 - Height` | M3 | done | #116; Fill from Health (#151) |
| Onboarding | Weight | `4 - CompleteAccountSetup/5 - Weight` | M3 | done | #116; Fill from Health (#151) |
| Onboarding | ExerciseFrequency | `4 - CompleteAccountSetup/6 - ExerciseFrequency` | M3 | done | #116 |
| Onboarding | Activity | `4 - CompleteAccountSetup/7 - Activity` | M3 | done | #116 |
| Onboarding | Expenditure | `4 - CompleteAccountSetup/9 - Expenditure` | M3 | done | #116; method ⓘ headers (#166) |
| Onboarding | HealthDisclaimer | `5 - HealthDisclaimer` | M3 | done | #116 (document links are placeholders in Swift too) |
| Onboarding | OverarchingObjective | `6 - GoalSetting/1 - OverarchingObjective` | M3 | done | #116 |
| Onboarding | TargetWeight | `6 - GoalSetting/2 - TargetWeight` | M3 | done | #116 |
| Onboarding | WeightRate | `6 - GoalSetting/3 - WeightRate` | M3 | done | #116 |
| Onboarding | GoalSummary | `6 - GoalSetting/4 - GoalSummary` | M3 | done | #116; standalone from Settings and Progress (#154) |
| Onboarding | CustomisingDietProgram | `8 - OnboardingDiet` | M3 | done | #116 |
| Onboarding | PreferredDiet | `8 - OnboardingDiet/1 - PreferredDiet` | M3 | done | #116; from Settings' Nutrition Plan and Create Diet Plan (#154) |
| Onboarding | CalorieFloor | `8 - OnboardingDiet/2 - CalorieFloor` | M3 | done | #116 |
| Onboarding | CalorieDistribution | `8 - OnboardingDiet/4 - CalorieDistribution` | M3 | done | #116 |
| Onboarding | ProteinIntake | `8 - OnboardingDiet/5 - ProteinIntake` | M3 | done | #116 |
| Onboarding | DietPlan | `8 - OnboardingDiet/6 - DietPlan` | M3 | done | #116 |
| Onboarding | OnboardingCompleted | `9 - OnboardingCompleted` | M3 | dropped | decisions.md (#116): unreachable, because `.complete` only arises once onboarding is done |
| Paywalls | Paywall | `Paywall` | M4 | partial | #155, `/paywall`: the `paywallTest` arm (#186): `custom`; `revenueCat` is RevenueCat's paywall (`purchases_ui_flutter`), `custom` while RevenueCat isn't running; `storeKit` is a Flutter drawing of StoreKit's layout (no free Flutter equivalent, none on Play); real purchases and the RevenueCat paywall wait for the owner's RevenueCat setup |
| Profile | Settings | `Compound/Core/Profile` | M5 | done | #128, `/profile/settings`; Weight Goal and Nutrition Plan (#154), Subscription (#155), Save Account, Rate and Developer Settings (#166); Siri row, iOS only (#187) |
| Profile | About | `Subviews/About` | M5 | done | #128; version and build (#166) |
| Profile | Licences | `Subviews/About/Licences` | M5 | done | #128 (`LicensePage`) |
| Profile | AppIcon | `Subviews/AppIcon` | M6 | done | #181: Compound's icon on iOS (light and dark) and Android (adaptive); no alternate-icon row, as Swift hides it (one icon); Android 13+ themed (monochrome) layer (#194) |
| Profile | EditProfile | `Subviews/EditProfile` | M5 | done | #128; photo (#150); Swift's offline pre-check (`ensureOnline`, #196) |
| Profile | DeleteAccount | `Subviews/EditProfile/DeleteAccount` | M5 | done | #128 ("Account Deleted" is a snack bar) |
| Profile | EditUsername | `Subviews/EditProfile/EditUsername` | M5 | done | #131, `/username`; Swift's offline pre-check (`ensureOnline`, #196) |
| Profile | CustomiseAnalytics | `Subviews/GeneralSettings/CustomiseAnalytics` | M5 | done | #128 |
| Profile | Integrations | `Subviews/GeneralSettings/Integrations` | M5 | done | #151, `/profile/settings/integrations` |
| Profile | Siri | `Subviews/GeneralSettings/Siri` | M6 | done | #187, `/profile/settings/siri`: the five App Shortcuts and what to say, Open Shortcuts (`shortcuts://`) for Swift's `ShortcutsLink`; iOS only |
| Profile | Units | `Subviews/GeneralSettings/Units` | M5 | done | #128 |
| Profile | Legal | `Subviews/Legal` | M5 | done | #128 (titles "not published yet"; Swift's links are placeholders) |
| Profile | MethodsAndSources | `Subviews/MethodsAndSources` | M5 | done | #128, #130, #133, #137, #154, #166: all 31 of Swift's methods, in Swift's order |
| Profile | ExpenditureSettings | `Subviews/NutritionSettings/ExpenditureSettings` | M5 | done | #128; ⓘ headers (#166) |
| Profile | FoodLogSettings | `Subviews/NutritionSettings/FoodLogSettings` | M5 | done | #128 |
| Profile | FavouriteMeasurements | `Subviews/NutritionSettings/FoodLogSettings/FavouriteMeasurements` | M5 | done | #128 |
| Profile | LoggerBanner | `Subviews/NutritionSettings/FoodLogSettings/LoggerBanner` | M5 | done | #128 |
| Profile | LoggerFoodTiles | `Subviews/NutritionSettings/FoodLogSettings/LoggerFoodTiles` | M5 | done | #128 |
| Profile | TimelineFoodTiles | `Subviews/NutritionSettings/FoodLogSettings/TimelineFoodTiles` | M5 | done | #128 |
| Profile | StrategySettings | `Subviews/NutritionSettings/StrategySettings` | M5 | done | #128 |
| Profile | ExerciseAssessment | `Subviews/TrainingSettings/ExerciseAssessment` | M5 | dropped | decisions.md (#144): Swift hides the row; the assessment unlocks nothing |
| Profile | GymProfiles | `Subviews/TrainingSettings/GymProfiles` | M5 | done | #140, `/profile/settings/gym-profiles`; swipe Delete and Favorite (#195) |
| Profile | GymProfile | `Subviews/TrainingSettings/GymProfiles/GymProfile` | M5 | done | #140; gym photo and equipment thumbnails (#161); machine swipe actions (#195) |
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
| Profile | TimerDuration | `Subviews/TrainingSettings/WorkoutSettings/RestTimerSettings/TimerDuration` | M5 | done | #128; rest ⓘ (#166); swipe to remove (#195) |
| Profile | SmartProgressionSettings | `Subviews/TrainingSettings/WorkoutSettings/SmartProgressionSettings` | M5 | done | #128; ⓘ (#166) |
| Profile | Tutorials | `Subviews/Tutorials` | M5 | dropped | decisions.md (#144): Swift hides the row; no tutorials exist |
| Sharing | ShareToFollower | `ShareToFollower` | M5 | done | #148 (pushed dialog); Swift's offline pre-check (`ensureOnline`, #196) |
| Sharing | SharedItem | `SharedItem` | M5 | done | #148, `/shares/:shareId` |
| Social | Social | `Compound/Core/Social` | M5 | done | #131; bell and badges (#144); challenges and invites (#146); Swift's offline pre-check (`ensureOnline`, #196) |
| Social | WeeklyGoal | `CircleGoals/WeeklyGoal` | M5 | done | #131 |
| Social | SocialProfile | `SocialProfile` | M5 | done | #131; Share Profile (#146); Strava This Year (#151); Report and the Following line (#159) |
| Social | FollowersList | `SocialProfile/FollowersList` | M5 | done | #131; swipe to remove (#195); Swift's offline pre-check (`ensureOnline`, #196) |
| Social | WorkoutSessionRow | `WorkoutSessionRow` | M5 | done | #131; Share Image and Share with Friends (#148); Save as Template and Report (#159); text Share with the web link (#179) |
| Social | Comments | `WorkoutSessionRow/Comments` | M5 | done | #131; Report (#159); relative times, swipe actions (#195) |
| TabBar | TabBar | `Compound/Core/TabBar` | M1 | done | #90, five tabs, per-tab stacks, deep-link paths |
| Today | Today | `Compound/Core/Today` | M2 | done | #101, #133, #134, #147, #151; planned and rest-day checklist states, step goal and social pulse (#164); streak-reminder offer at a two-week streak, step goal saved by field (#176) |
| Today | WeeklyReview | `WeeklyReview` | M2 | done | #133, `/today/weekly-review`; share card (#148), From Strava (#151), Ask Coach (#147) |
| Training | Training | `Compound/Core/Training` | M3 | done | #120, #134, #136, #138, #141; calendar header, day taps and month picker (#164) |
| Training | TodaysWorkoutCard | `Components/TodaysWorkoutCard` | M3 | done | #134 |
| Training | TrainingAccessory | `Components/TrainingAccessory` | M3 | done | `ActiveWorkoutBar` (#125); set ring, rest countdown and Skip Rest (#165) |
| Training | WorkoutStreak | `Components/WorkoutStreakCard` | M3 | done | #101, Today's `StreakCard` |
| Training | CreateExercise | `Exercises/CreateExercise` | M3 | done | #141, `/create-exercise` |
| Training | EquipmentPicker | `Exercises/CreateExercise/EquipmentPicker` | M3 | done | #141 |
| Training | ExerciseEquipment | `Exercises/CreateExercise/ExerciseEquipment` | M3 | done | #141 |
| Training | ExerciseSave | `Exercises/CreateExercise/ExerciseSave` | M3 | done | #141; a new exercise comes back ticked in the picker (#195) |
| Training | FinalExerciseDetails | `Exercises/CreateExercise/FinalExerciseDetails` | M3 | done | #141 |
| Training | MuscleGroupPicker | `Exercises/CreateExercise/MuscleGroupPicker` | M3 | done | #141 |
| Training | ExerciseListBuilder | `Exercises/ExerciseListBuilder` | M3 | done | #120 (filters); Create Exercise row (#141) |
| Training | ExerciseModelDetail | `Exercises/ExerciseModelDetail` | M3 | done | #120 About and History; Delete (#141); Ask Coach (#147); Charts and Records (#167) |
| Training | Exercises | `Exercises/Exercises` | M3 | done | #120, `/training/exercises`; Create Exercise (#141) |
| Training | ActiveMesocycle | `Programs/ActiveMesocycle` | M3 | done | #134, #136; Ask Coach (#147); swipe actions (#195) |
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
| Training | MacrocycleDetail | `Programs/Macrocycles/MacrocycleDetail` | M3 | done | #134; swipe to delete (#195) |
| Training | MesocycleLibrary | `Programs/MesocycleLibrary` | M3 | done | #134, #136 |
| Training | InactiveMesocycle | `Programs/MesocycleLibrary/InactiveMesocycle` | M3 | done | #134; swipe to delete (#195) |
| Training | MesocycleDisclosureGroup | `Programs/MesocycleLibrary/MesocycleDisclosureGroup` | M3 | done | #134; Edit (#136); Share with Friends (#148) |
| Training | PrebuiltMesocycleDetail | `Programs/MesocycleLibrary/PrebuiltMesocycleDetail` | M3 | done | #134 |
| Training | ExerciseTracker | `Session/ExerciseTracker` | M3 | done | #125; Swap (#163); Do Next/Do Later, reordering, progression note, Last tap-to-fill, previous-note hint (#165) |
| Training | ExerciseSettings | `Session/ExerciseTracker/ExerciseSettings` | M3 | done | #163: units, rest timer, side-set rest, note, Edit Duplicate; the copy is named "(Copy)" (#195) |
| Training | SetTrackerRow | `Session/ExerciseTracker/SetTrackerRow` | M3 | done | #125; set types, sub-sets, Split L/R, per-row rest (#158); unit menus (#163); swipe actions (#195) |
| Training | PlateCalculator | `Session/ExerciseTracker/SetTrackerRow/PlateCalculator` | M3 | done | #156 |
| Training | SetKeyboard | `Session/ExerciseTracker/SetTrackerRow/SetKeyboard` | M3 | done | #125; bands, ± and the loading bar (#156); stopwatch (#158) |
| Training | SwapExercisePicker | `Session/ExerciseTracker/SwapExercisePicker` | M3 | done | #163 |
| Training | WorkoutExerciseEquipmentSheet | `Session/ExerciseTracker/WorkoutExerciseEquipmentSheet` | M3 | done | #156, with #140's scoped gym editor |
| Training | WorkoutHistory | `Session/WorkoutHistory` | M3 | done | #93, `/training/history` |
| Training | WorkoutNotes | `Session/WorkoutNotes` | M3 | done | #125 notes sheet |
| Training | WorkoutSessionDetail | `Session/WorkoutSessionDetail` | M3 | partial | #93, #125, #147, #148, #151; editing, start time, duration and Delete (#162), Swift's full edit mode (#171); Copy Link (#179) |
| Training | WorkoutTracker | `Session/WorkoutTracker` | M3 | done | #125, #127 (`/workout`, Finish at); Gym Settings (#140); Workout Settings (#165); rest-complete sound (#172); iPad toolbar: pause, finish and notes on the bar from `AppContentWidth.twoColumns` (#181); a finished workout stays on the device until the server confirms it, unlike Swift (#196) |
| Training | ChooseGymProfile | `Workouts/CreateWorkout/ChooseGymProfile` | M3 | done | #138; Create Gym Profile (#140) |
| Training | DefineWorkout | `Workouts/CreateWorkout/DefineWorkout` | M3 | done | #138; swipe Delete and Remove from superset (#195) |
| Training | DefineWorkoutWrapper | `Workouts/CreateWorkout/DefineWorkoutWrapper` | M3 | done | #138 |
| Training | ExercisesPicker | `Workouts/CreateWorkout/ExercisesPicker` | M3 | done | #120 `/exercise-picker`; substitutions (#138) |
| Training | NameWorkout | `Workouts/CreateWorkout/NameWorkout` | M3 | done | #138, `create-workout`, `edit-workout/:id` |
| Training | SetTarget | `Workouts/CreateWorkout/SetTarget` | M3 | done | #138; session scope (#163); swipe to delete sets and substitutions (#195) |
| Training | WeeklyTargets | `Workouts/CreateWorkout/SetTarget/WeeklyTargets` | M3 | done | #138; swipe to delete (#195) |
| Training | WorkoutTemplateDetail | `Workouts/WorkoutTemplateDetail` | M3 | done | #120, #134, #136, #138, #148; per-set targets and Watch link (#167) |
| Training | Workouts | `Workouts/Workouts` | M3 | done | #120, `/training/workouts`; New Workout (#138) |

198 modules.

## Platform features (not screen modules)

| Feature | Swift | Milestone | Status | Flutter |
|---|---|---|---|---|
| Sign in: Apple, Google, anonymous, account linking | SwiftfulAuthenticating | M1 | done | `auth_repository` (#86); Save Account links an anonymous account (#166); Apple on Android through Firebase's web flow (#191); Apple's button on both (#194); Google's branded button, matched to Apple's (#197) |
| App Check | `AppCheckProviderFactory` | M1 | done | `main_development.dart`, debug token registered in M1; production: App Attest with a DeviceCheck fallback (#200) |
| Offline data and sync | Sync engines | M1–M3 | done | Firestore cache + `writeLocally` (#111); Swift's `ensureOnline` pre-checks, at the same actions (`connectivity_repository`, #196); a finished workout stays on the device until the server confirms it (#196) |
| Device-local preferences | `UserDefaults` | M5 | done | `device_store` on shared_preferences under Swift's keys (#170); review date and the editor's plates switch (#172) |
| Per-exercise unit preferences | `ExerciseUnitPreferenceManager` | M3 | done | #163, on the device store (#170) |
| Analytics events (Mixpanel, Firebase, Crashlytics) | `LogManager` | M3 | done | `analytics_repository` (#96) |
| Push notifications and deep links | `PushManager`, `DeepLink.swift` | M4 | partial | `notifications_repository` (#117), wiring (#127), inbox (#144), join links (#146), activity banner and clearing delivered pushes (#172); iOS pushes the system displayed cleared by identifier (#187); https workout pages routed in Dart, others' sessions opened over Social (#179; no Associated Domains or App Links, as Swift) |
| Local reminders | `PushManager` (local) | M4 | done | come-back and meal reminders, rest-over, "Still training?" (#127, last asked on the device #170); permission prompt (#144); in-app reminder offers (`ReminderOfferFlow`, #176) |
| Purchases and paywall (RevenueCat) | `PurchaseManager` | M4 | partial | `purchases_repository` (#114); paywall, gate, RevenueCat logIn/logOut (#155); development runs the fake until the owner's keys; production uses the prod key and never the fake (#200); logIn sends the email and the Mixpanel and Firebase Analytics ids (#177) |
| A/B tests (Remote Config) | `ABTestManager` | M5 | done | `ab_test_repository` (#186): `notificationsTest` and `paywallTest` under Swift's keys and defaults, sent as Swift's user properties; development draws locally as Swift's dev, staging in memory, Remote Config for production (#200); `notificationsTest` drives nothing, as in Swift |
| App rating prompt | `ReviewMoment` | M5 | done | `ReviewMoment`, Rate row and food moments (#166); workout-finish moment and stored date (#172) |
| HealthKit (iOS) and Health Connect (Android): steps, weight, workouts, meal import | `HealthKitManager`, `HKWorkoutManager` | M5 | partial | `health_repository` (#121), UI and native setup (#151); no live workout session (heart rate, active energy; iOS, M6); HealthKit capability is an owner TODO |
| Live Activity and Dynamic Island (iOS); ongoing notification (Android) | `LiveActivityManager`, `WorkoutSessionActivity/` | M3 (Android), M6 (iOS) | done | Android ongoing notification (#127); no foreground service, by decision (#172); iOS (#184): `WorkoutSessionActivity` copied into `app/ios`, driven over `com.andrewcoyle.compound/live_activity`, buttons answered by `ActiveWorkoutCubit`; a button tapped after iOS has killed the app waits 10 s for Dart, then only clears its loading state |
| Home screen widgets | `WorkoutSessionActivity/HomeWidgets.swift` | M6 | done | #184: Today's Workout, Streak, Weekly Goal; snapshot in the flavor's App Group, written on backgrounding and after Finish on the Live Activity, cleared on sign-out |
| Siri and Shortcuts (App Intents) | `Managers/AppIntents` | M6 | done | #187: Start Workout, Log Weight, Workouts This Week, Today's Workout, and Recipes (the `browse_recipes` quick action, #145) via `compound://recipes`; answered in Dart (`AppIntents`) over `com.andrewcoyle.compound/app_intents`. App Shortcuts need a team-signed build to run |
| Strava upload and import | `StravaManager` | M5 | partial | `strava_repository` (#122), UI (#151), `pushEdit` (#162); needs the owner's `STRAVA_CLIENT_ID`; Keychain-token migration is M6 |
| AI: food photo, meal description, nutrition label, image generation | `AIManager` | M5 | done | `ai_repository` (#118), scanners (#152); on-device label OCR (#185); image generation has no caller in Swift's screens |
| AI coach (streaming) | `CoachManager` | M5 | done | `coach_repository` (#118), UI (#147) |
| Image upload and progress photos | `ImageUploadManager` | M5 | done | `image_repository` (#150): progress and profile photos; food, recipe, gym, equipment and NamePhoto (#161) |
| Reporting and moderation | `ReportManager` | M5 | done | #159: comments, feed cards and profiles |
| Haptics and sound effects | `HapticManager`, `SoundEffectManager` | M3 | done | haptics across slices; check-in weigh-in (#172); rest-complete sound over a method channel (#172) |
| Spanish localisation, 100% | `Localizable.xcstrings` | M1 | done | `scripts/arb-spanish.py`, CI check |
| iPad and wide layouts | `ContentWidth`, `Dashboard` | M6 | done | #181: Today an `AppDashboard` (two columns from 740 pt), Today and Progress 1,100 pt (#103's grids kept); #194: every screen an `AppScaffold`, its app bar across the window and its body and bottom CTA in a 700 pt column |
| Mac (Catalyst) | Catalyst | M6 | dropped | the owner dropped Mac for now (16 Oct 2026); a Flutter macOS build can be revisited later. The macOS folder was removed (#82) |
| Methods & Sources (citations) | `Components/Science` | M4 | done | `science/method_info.dart`: all 31 (#154, #166) |

## Remaining work

Every gap left in the tables above, with the deferrals from `decisions.md` and the PR bodies, in three
groups. The proposed slices from the #151 sweep are finished, apart from what is carried here.

### (a) Follow-up slices an agent can build without the owner
Ordered by user value. Each is meant to be one PR into `feature/flutter`.

None left: label OCR (#185) and A/B tests (#186) closed the last two.

### (b) Waiting on the owner
- **RevenueCat:** iOS development is done: it shares the Swift dev app's bundle id and so its
  RevenueCat app and products, with `REVENUECAT_APPLE_API_KEY` in `app/dart_defines.json`. Android
  still needs a Play app `com.andrewcoyle.compound.dev`, its subscriptions on the same entitlement, a
  Play service-account credential and `REVENUECAT_GOOGLE_API_KEY`; until then Android development
  runs the premium fake (#114, #155).
- **APNs and push:** done for development on 16 Oct 2026: a sandbox APNs key on both dev iOS apps in
  `compound-development`, a production key on `com.andrewcoyle.compound` in prod, and Push, Time
  Sensitive, HealthKit and App Groups on the dev App IDs, with the entitlements in #188. Optionally the
  remote-notifications background mode (#117, #127). `compound://` is shared with the Swift app on one
  device (#127).
- **HealthKit and Health Connect:** the HealthKit capability on the production App ID (the
  entitlement is in #200; development is done, #188); the Play Console Health Connect declaration; a privacy policy page for the
  rationale screen (#121, #151).
- **RevenueCat paywall:** a paywall designed in RevenueCat's dashboard on the current offering, for
  the `revenueCat` arm of `paywallTest` (#186); without one RevenueCat shows its default template, and
  while RevenueCat isn't running (no keys) that arm shows the custom paywall.
- **Storage rules (dev):** any signed-in user can write and delete another user's photos (#150); food
  and recipe photos sit at the Storage root (`ingredient_templates/{id}`, `recipe_templates/{id}`),
  Swift's paths, so per-user rules can't cover them (#161); one leftover anonymous account in
  `compound-development` Auth (#150).
- **Firestore rules:** user exercises in `exercise_templates` are readable by every signed-in user
  (`swift-findings.md`).
- **Share links opening the app:** links are built and routed (#179), but neither app claims the
  host, as Swift doesn't: an App Links intent filter, the Associated Domains capability and
  entitlement, and for prod the association files on `dialed-c3cb5` Hosting (#179 lists the steps).
- **Legal URLs and store ids:** publish the Terms of Service and Privacy Policy (the stores need
  working links on the paywall, #155) and the disclaimer's links (#116, #128); store ids for Rate to
  open the listing (#166).
- **Production flavor:** iOS is wired to `dialed-c3cb5` with the App Store app's ids, at the owner's
  request on 18 Oct 2026 (#200). Before the first TestFlight upload, on the prod App IDs
  (`com.andrewcoyle.compound` and `…WorkoutSessionActivity`): the App Group `group.com.compound.app`
  on the extension's App ID as well as the app's, App Attest, Push, Time Sensitive, HealthKit and Sign
  in with Apple on the app's (the Swift app already uses them, so this is likely a check, not a
  change). App Check enforcement in prod accepts App Attest already. Prod's Apple provider has its
  OAuth code flow (Services ID `com.andrewcoyle.compound.signin`), so Sign in with Apple on Android
  needs nothing more there (#191). Android production is not configured: a prod Android app,
  Play Console account and closed test before Android 1.0 (plan, M3).
- **Translations and wording to review:**
  - Spanish written by hand: the label error and hint, "Describe your meal", "per 100ml" (#152);
    "{first} o {second}" (#156); the plural set confirmations (#158); "Siguiendo {name}" and the
    per-kind report wording (#159); "Acciones de la serie", "Hora" (#162); the plan note's lists
    (#165); the label scan hint, Scan Label, "Reading label…" and the two camera messages (#185).
  - Native strings: the camera usage text and its Spanish `InfoPlist.strings`, and a try of the
    barcode scanner on a device (#126); `NSPhotoLibraryUsageDescription` is English only (#150).
  - Spanish by hand: the relative times' plurals and "(copia)" (#195).
- **Design calls logged for review:** week paging instead of Swift's year-long calendar scroller
  (#164); rolling chart windows instead of calendar periods, and touch-only readouts with no
  per-bucket screen-reader values (#168; the readout is Swift's floating callout since #194); strip
  reordering by menu, not drag (#165); Developer Settings as a Settings row, not Today's toolbar
  (#166); the paywall gate not applied at every launch (#155).
- **Brand assets** for `app_ui`: the share cards show the app icon (`AppImages.appIcon`, #194); the
  gym editor still shows no header without a photo (#161).
- **FoodPackaging** stays `todo` until the public food database is switched on (#142).
- **Swift `GoalManager` objective-merge bug** (#154): `updateGoal` merge-saves the whole goal, so
  changing a goal's objective in Swift stores two objective keys and the goal stops decoding in both
  apps. Fix in Swift before Android 1.0 shares accounts. The other findings in `swift-findings.md`
  each need a decision too.

### (c) M6: iOS only (go-ahead given 16 Oct 2026)
- Live Activity and Dynamic Island: keep `WorkoutSessionActivity`, driven over a platform channel and
  an App Group; the Lock Screen set receipt in the progression note's slot (#165).
- Home screen widgets, and the widget snapshot on backgrounding (App).
- Siri and Shortcuts (App Intents): the Siri settings row and the `browse_recipes` shortcut (#145).
- HealthKit's live workout session (heart rate, active energy).
- Clearing pushes iOS displayed while the app was in the background, by identifier (#172).
- iOS flavors under the existing bundle ids; the Strava Keychain-token migration (#122, #151); the
  final Swift release that flushes pending writes. At the switch, Swift's Monday-recap week id and its
  `Date` review stamp don't carry over: a dismissed recap may show once more and the review cooldown
  restarts (#170, #172).
