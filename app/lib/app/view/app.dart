import 'dart:async';

import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/bloc/app_bloc.dart';
import 'package:compound/challenges/challenges.dart';
import 'package:compound/check_in/check_in.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/expenditure_metric/expenditure_metric.dart';
import 'package:compound/goal_editing/goal_editing_routes.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/launch/launch.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/notifications/notifications.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/nutrition/nutrition_routes.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:compound/onboarding/onboarding.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/progress_photos/progress_photos.dart';
import 'package:compound/settings/settings.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound/sharing/sharing_routes.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:compound/social/invite/invite_cubit.dart';
import 'package:compound/social/profile/social_profile_page.dart';
import 'package:compound/social/social.dart';
import 'package:compound/today/today.dart';
import 'package:compound/training/training.dart';
import 'package:compound/training_analytics/training_analytics_routes.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound/weekly_review/weekly_review.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_editor/workout_editor_routes.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_maths/compound_maths.dart' show checkInWeekStart;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:health_repository/health_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class const App({
  required final AuthRepository authRepository,
  required final UserRepository userRepository,
  required final WorkoutSessionRepository workoutSessionRepository,
  required final NutritionRepository nutritionRepository,
  required final BodyRepository bodyRepository,
  required final ProgramRepository programRepository,
  required final TrainingLibraryRepository trainingLibraryRepository,

  /// Subscriptions: whether the user is premium. Required, with no
  /// fallback, so an entry point can never grant premium by leaving it out.
  required final PurchasesRepository purchasesRepository,
  final AnalyticsRepository analyticsRepository = const AnalyticsRepository(),
  // Empty and offline when left out, for tests that never log food.
  final FoodRepository? foodRepository,
  final OpenFoodFacts? openFoodFacts,
  // The check-in's data, empty in memory when left out.
  final CheckInRepository? checkInRepository,

  /// The target proposals waved away; in memory when left out.
  final ProposalDismissals? proposalDismissals,

  /// Where the workout under way is kept between launches; in memory when
  /// left out.
  final ActiveSessionStore? activeSessionStore,

  /// Push and local notifications; the fake (nothing reaches the platform)
  /// when left out.
  final NotificationsRepository? notificationsRepository,

  /// Follows, the feed, likes and comments; an empty in-memory world when
  /// left out, for tests that never open Social.
  final SocialRepository? socialRepository,

  /// Where photos are uploaded; in memory when left out.
  final ImageRepository? imageRepository,

  /// The camera and photo library; the bundled sample photo when left out.
  final PhotoPicker? photoPicker,

  /// The AI food scanners' callables; staging's canned answers when left
  /// out.
  final AiRepository? aiRepository,

  /// The AI coach; one that answers nothing when left out, for tests that
  /// never open it.
  final CoachRepository? coachRepository,

  /// Apple Health or Health Connect; one that is never available when
  /// left out.
  final HealthRepository? healthRepository,

  /// Strava; unavailable when left out (no client id in this build).
  final StravaRepository? stravaRepository,

  /// Strava's consent page; the platform's web authentication session
  /// unless a test or staging passes another.
  final StravaAuthorizer stravaAuthorizer = const WebStravaAuthorizer(),

  /// Opens web links; tests pass one that records them.
  final LinkOpener linkOpener = const LinkOpener(),

  /// The system share sheet; tests pass one that records what is shared.
  final ShareSheet shareSheet = const ShareSheet(),
  final TrackerClock trackerClock = const TrackerClock(),
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: workoutSessionRepository),
        RepositoryProvider.value(value: nutritionRepository),
        RepositoryProvider.value(value: bodyRepository),
        RepositoryProvider.value(value: programRepository),
        RepositoryProvider.value(value: trainingLibraryRepository),
        RepositoryProvider.value(value: analyticsRepository),
        RepositoryProvider.value(value: purchasesRepository),
        RepositoryProvider<CoachRepository>(
          create: (_) =>
              coachRepository ??
              CoachRepository(
                firestore: FakeFirebaseFirestore(),
                users: userRepository,
                coachChat: (_, {chatId, context}) => Stream.error(
                  const CoachException(CoachFailure.unavailable),
                ),
              ),
        ),
        RepositoryProvider<FoodRepository>(
          create: (_) => foodRepository ?? InMemoryFoodRepository(),
        ),
        RepositoryProvider<OpenFoodFacts>(
          create: (_) => openFoodFacts ?? FakeOpenFoodFacts(),
        ),
        RepositoryProvider<CheckInRepository>(
          create: (_) => checkInRepository ?? InMemoryCheckInRepository(),
        ),
        RepositoryProvider<ImageRepository>(
          create: (_) => imageRepository ?? InMemoryImageRepository(),
        ),
        RepositoryProvider<PhotoPicker>(
          create: (_) => photoPicker ?? samplePhotoPicker(),
        ),
        RepositoryProvider<AiRepository>(
          create: (_) =>
              aiRepository ?? AiRepository(callFunction: stagingAiCall),
        ),
        RepositoryProvider.value(value: trackerClock),
        RepositoryProvider.value(value: shareSheet),
        RepositoryProvider.value(value: linkOpener),
        RepositoryProvider<StravaRepository?>.value(value: stravaRepository),
        RepositoryProvider<HealthRepository>(
          create: (_) =>
              healthRepository ??
              HealthRepository(
                platform: FakeHealthPlatform(available: false),
                body: bodyRepository,
                nutrition: nutritionRepository,
              ),
        ),
        RepositoryProvider<ProposalDismissals>(
          create: (_) => proposalDismissals ?? ProposalDismissals(),
        ),
        RepositoryProvider<NotificationsRepository>(
          create: (_) =>
              notificationsRepository ?? FakeNotificationsRepository(),
        ),
        RepositoryProvider<SocialRepository>(
          create: (_) =>
              socialRepository ??
              SocialRepository(
                firestore: FakeFirebaseFirestore(),
                callFunction: (_, _) async => null,
                users: userRepository,
              ),
        ),
        RepositoryProvider(
          create: (_) => TrainingSetupService(
            programs: programRepository,
            library: trainingLibraryRepository,
            users: userRepository,
          ),
        ),
        RepositoryProvider(
          create: (_) => ProgramService(
            programs: programRepository,
            users: userRepository,
            sessions: workoutSessionRepository,
            onEvent: analyticsRepository.analytic,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppBloc(
              authRepository: authRepository,
              userRepository: userRepository,
              analyticsRepository: analyticsRepository,
            )..add(const AppUserSubscriptionRequested()),
          ),
          BlocProvider(create: (_) => MealDraftCubit()),
          BlocProvider(
            create: (context) => NotificationsCubit(
              notifications: context.read(),
              users: userRepository,
            ),
          ),
          BlocProvider(
            create: (context) => StravaCubit(
              strava: stravaRepository,
              authorizer: stravaAuthorizer,
              analytics: analyticsRepository,
            ),
          ),
          BlocProvider(
            create: (context) => HealthCubit(
              health: context.read(),
              analytics: analyticsRepository,
            ),
          ),
          BlocProvider(
            create: (context) => ActiveWorkoutCubit(
              notifications: context.read(),
              sessions: workoutSessionRepository,
              users: userRepository,
              library: trainingLibraryRepository,
              analytics: analyticsRepository,
              store: activeSessionStore ?? InMemoryActiveSessionStore(),
              clock: trackerClock.now,
              programs: context.read(),
              health: context.read(),
              strava: stravaRepository,
            ),
          ),
          BlocProvider(
            create: (context) => ProgramsCubit(
              programs: programRepository,
              users: userRepository,
              sessions: workoutSessionRepository,
              service: context.read<ProgramService>(),
              setup: context.read<TrainingSetupService>(),
              analytics: analyticsRepository,
            ),
          ),
          BlocProvider(
            create: (context) => InboxBloc(
              social: context.read(),
              analytics: analyticsRepository,
            ),
          ),
          BlocProvider(
            create: (context) => ChallengesCubit(
              social: context.read(),
              analytics: analyticsRepository,
            ),
          ),
          BlocProvider(
            create: (context) => InviteCubit(
              social: context.read(),
              analytics: analyticsRepository,
            ),
          ),
          BlocProvider(
            create: (context) => CircleBloc(
              social: context.read(),
              sessions: workoutSessionRepository,
              analytics: analyticsRepository,
            ),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const new({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final GoRouter _router = GoRouter(
    // A debug hook for screenshots and manual checks, e.g.
    // `--dart-define=INITIAL_LOCATION=/profile`.
    initialLocation: const String.fromEnvironment(
      'INITIAL_LOCATION',
      defaultValue: '/today',
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                switch (tab) {
                  AppTab.today => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const TodayPage(),
                    routes: [
                      GoRoute(
                        path: WeeklyReviewPage.path,
                        name: WeeklyReviewPage.name,
                        builder: (_, _) => const WeeklyReviewPage(),
                      ),
                    ],
                  ),
                  AppTab.training => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const TrainingPage(),
                    routes: [
                      ...programRoutes,
                      ...workoutEditorRoutes,
                      GoRoute(
                        path: WorkoutsPage.path,
                        name: WorkoutsPage.name,
                        builder: (_, _) => const WorkoutsPage(),
                        routes: [
                          GoRoute(
                            path: WorkoutTemplateDetailPage.path,
                            name: WorkoutTemplateDetailPage.name,
                            builder: (_, state) =>
                                WorkoutTemplateDetailPage.fromRoute(state),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: ExercisesPage.path,
                        name: ExercisesPage.name,
                        builder: (_, _) => const ExercisesPage(),
                        routes: [
                          GoRoute(
                            path: ExerciseDetailPage.path,
                            name: ExerciseDetailPage.name,
                            builder: (_, state) => ExerciseDetailPage(
                              exerciseId:
                                  state.pathParameters[ExerciseDetailPage
                                      .idParameter]!,
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: WorkoutHistoryPage.path,
                        name: WorkoutHistoryPage.name,
                        builder: (_, _) => const WorkoutHistoryPage(),
                        routes: [
                          GoRoute(
                            path: WorkoutSessionDetailPage.path,
                            name: WorkoutSessionDetailPage.name,
                            builder: (_, state) => WorkoutSessionDetailPage(
                              sessionId:
                                  state.pathParameters[WorkoutSessionDetailPage
                                      .sessionIdParameter]!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppTab.nutrition => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const NutritionPage(),
                    routes: [
                      ...nutritionRoutes,
                      GoRoute(
                        path: NutritionOverviewPage.path,
                        name: NutritionOverviewPage.name,
                        builder: (_, state) => NutritionOverviewPage(
                          dayKey:
                              state.uri.queryParameters[NutritionOverviewPage
                                  .dayParameter] ??
                              localDayKey(DateTime.now()),
                        ),
                      ),
                    ],
                  ),
                  AppTab.progress => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const ProgressPage(),
                    routes: [
                      for (final metric in WeightMetric.values)
                        GoRoute(
                          path: metric.path,
                          name: metric.name,
                          builder: (_, _) => WeightMetricPage(metric: metric),
                          routes: [
                            GoRoute(
                              path: 'data',
                              name: metric.dataRouteName,
                              builder: (_, _) => WeightMetricPage(
                                metric: metric,
                                allData: true,
                              ),
                            ),
                          ],
                        ),
                      ...trainingAnalyticsRoutes,
                      ...progressRoutes,
                      for (final metric in ExpenditureMetric.values)
                        GoRoute(
                          path: metric.path,
                          name: metric.name,
                          builder: (_, _) =>
                              ExpenditureMetricPage(metric: metric),
                          routes: [
                            GoRoute(
                              path: 'data',
                              name: metric.dataRouteName,
                              builder: (_, _) => ExpenditureMetricPage(
                                metric: metric,
                                allData: true,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  AppTab.social => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const SocialPage(),
                    routes: [
                      GoRoute(
                        path: NotificationsPage.path,
                        name: NotificationsPage.name,
                        builder: (_, _) => const NotificationsPage(),
                      ),
                    ],
                  ),
                },
              ],
            ),
        ],
      ),
      // Over the tabs, as the Swift app's full-screen cover.
      GoRoute(
        path: ProfilePage.path,
        name: ProfilePage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const ProfilePage(),
        ),
        routes: profileRoutes,
      ),
      // Profiles, someone's workout and its comments, and the username:
      // over the tabs, from Social and from the profile cover alike.
      ...socialRoutes,
      ...challengeRoutes,
      ...sharingRoutes,
      ...progressRootRoutes,
      ...coachRoutes,
      ...goalEditingRoutes,
      // Over the tabs, as the Swift app's sheet.
      GoRoute(
        path: LogWeightPage.path,
        name: LogWeightPage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const LogWeightPage(),
        ),
      ),
      // Over the tabs, as the Swift app's sheet; the week reviewed is the
      // query's, this week's without one.
      GoRoute(
        path: CheckInPage.path,
        name: CheckInPage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: CheckInPage(
            weekStart: localMidnight(
              state.uri.queryParameters[CheckInPage.weekParameter] ??
                  checkInWeekStart(localDayKey(DateTime.now())),
            ),
          ),
        ),
      ),
      // Over the tabs, as the Swift app's full-screen cover; the meal to
      // build is the route's extra.
      GoRoute(
        path: AddMealPage.path,
        name: AddMealPage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: AddMealPage(
            meal: switch (state.extra) {
              final MealLogModel meal => meal,
              _ => null,
            },
          ),
        ),
      ),
      createFoodRoute,
      createRecipeRoute,
      // Over the tabs, as the Swift app's sheet. Pops with the exercises
      // picked (`ExercisePickerPage.show`).
      GoRoute(
        path: ExercisePickerPage.path,
        name: ExercisePickerPage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: ExercisePickerPage(
            request: switch (state.extra) {
              final ExercisePickerRequest request => request,
              _ => const ExercisePickerRequest(),
            },
          ),
        ),
      ),
      // Over the tabs, as the Swift app's full-screen cover, from Training's
      // + menu and the exercise list (the library and the picker).
      GoRoute(
        path: CreateExercisePage.path,
        name: CreateExercisePage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const CreateExercisePage(),
        ),
      ),
      // Over the tabs, as the Swift app's full-screen cover; minimised, the
      // workout carries on under the tabs' bar.
      GoRoute(
        path: WorkoutTrackerPage.path,
        name: WorkoutTrackerPage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: WorkoutTrackerPage(
            opensKeypad:
                state.uri.queryParameters[WorkoutTrackerPage.keypadParameter] ==
                '1',
          ),
        ),
      ),
      // The tracker's last page: the workout just finished.
      GoRoute(
        path: WorkoutSessionDetailPage.summaryPath,
        name: WorkoutSessionDetailPage.summaryName,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: WorkoutSessionDetailPage(
            sessionId: state
                .pathParameters[WorkoutSessionDetailPage.sessionIdParameter]!,
            session: switch (state.extra) {
              final WorkoutSessionModel session => session,
              _ => null,
            },
            isWorkoutSummary: true,
          ),
        ),
      ),
      GoRoute(
        path: SignInPage.path,
        name: SignInPage.name,
        builder: (_, _) => const SignInPage(),
      ),
      GoRoute(
        path: LaunchPage.path,
        name: LaunchPage.name,
        builder: (_, _) => const LaunchPage(),
      ),
      for (final route in OnboardingRoute.values)
        GoRoute(
          path: route.path,
          name: route.routeName,
          builder: (_, _) => switch (route) {
            OnboardingRoute.accountSetup => const AccountSetupPage(),
            OnboardingRoute.healthDisclaimer => const HealthDisclaimerPage(),
            OnboardingRoute.goal => const GoalSetupPage(),
            OnboardingRoute.gymProfile => const GymSetupPage(),
            OnboardingRoute.program => const ProgramSetupPage(),
            OnboardingRoute.diet => const DietSetupPage(),
          },
        ),
    ],
    redirect: (context, state) {
      // A `compound://` URL from the platform (its own deep-link handling,
      // which passes the whole URL): held until it can be routed, from
      // Today meanwhile. The app's own locations never have a scheme.
      if (state.uri.hasScheme) {
        context.read<NotificationsCubit>().linkOpened(state.uri);
        return AppTab.today.path;
      }
      return appRedirect(context.read<AppBloc>().state, state.uri);
    },
  );

  /// The app coming back to the front moves the come-back reminders out.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(context.read<NotificationsCubit>().resumed()),
    );
    _followUser(context.read<AppBloc>().state);
  }

  /// The workout under way and the notifications follow the signed-in user;
  /// links are routed once they are past onboarding.
  void _followUser(AppState state) {
    final uid = state is AppAuthenticated ? state.user.uid : null;
    final profile = state is AppAuthenticated ? state.profile : null;
    context.read<CircleBloc>().add(CircleViewerChanged(profile));
    context.read<InboxBloc>().add(InboxViewerChanged(profile));
    context.read<ChallengesCubit>().viewerChanged(profile?.userId);
    unawaited(context.read<ActiveWorkoutCubit>().userChanged(uid));
    unawaited(context.read<StravaCubit>().userChanged(uid));
    // Once the profile is read, so steps and food before the account's
    // creation are left out, as Swift's sign-in imports do.
    if (uid == null || profile != null) {
      context.read<HealthCubit>().userChanged(
        uid,
        since: profile?.creationDate,
      );
    }
    context.read<ProgramsCubit>().userChanged(uid);
    unawaited(
      context.read<NotificationsCubit>().userChanged(
        uid,
        ready:
            state is AppAuthenticated &&
            state.profileStatus == AppProfileStatus.ready &&
            state.onboardingStep == null,
      ),
    );
  }

  void _routeLink(BuildContext context, NotificationsState state) {
    final link = state.link;
    if (link == null) return;
    final appState = context.read<AppBloc>().state;
    _router.go(
      deepLinkLocation(
        link,
        currentUserId: appState is AppAuthenticated ? appState.user.uid : null,
        workoutActive: context.read<ActiveWorkoutCubit>().state.isActive,
      ),
    );
    // An invite link lands on Social, which accepts it
    // (`SocialPresenter.onAcceptInviteNotificationReceived`).
    final viewer = appState is AppAuthenticated ? appState.profile : null;
    if (link is JoinLink && viewer != null) {
      unawaited(context.read<InviteCubit>().accept(link.code, viewer: viewer));
    }
  }

  /// Shares the invite link, or opens the inviter's profile and says what
  /// accepting did, or says why either failed (`InviteShareFlow`,
  /// `InviteAcceptFlow`).
  void _onInvite(BuildContext context, InviteState state) {
    final l10n = context.l10n;
    void tell(String message) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    switch (state.result) {
      case null:
        return;
      case InviteShareReady(:final link):
        unawaited(
          context.read<ShareSheet>().shareText(
            context,
            l10n.inviteShareMessage(link),
          ),
        );
      case InviteShareFailed():
        tell('${l10n.inviteCreateFailed}. ${l10n.socialTryAgain}');
      case InviteAccepted(:final inviter, :final acceptance):
        if (acceptance.youFollow == InviteOutcome.requested) {
          context.read<CircleBloc>().add(
            CircleFollowRequestSent(inviter.userId),
          );
        }
        unawaited(
          _router.pushNamed(
            SocialProfilePage.name,
            pathParameters: {SocialProfilePage.userIdParameter: inviter.userId},
            extra: inviter,
          ),
        );
        final name = firstNameOf(inviter) ?? l10n.inviteYourFriend;
        tell(switch ((acceptance.youFollow, acceptance.theyFollow)) {
          (InviteOutcome.following, InviteOutcome.following) =>
            l10n.inviteBothFollowing,
          (InviteOutcome.following, InviteOutcome.requested) =>
            l10n.inviteYouFollowTheyRequested(name),
          (InviteOutcome.requested, InviteOutcome.following) =>
            l10n.inviteTheyFollowYouRequested(name),
          (InviteOutcome.requested, InviteOutcome.requested) =>
            l10n.inviteBothRequested,
        });
      case InviteAcceptFailed(:final failure):
        tell(
          '${l10n.inviteAcceptFailed}. ${switch (failure) {
            InviteFailure.invalidCode => l10n.inviteInvalidCode,
            InviteFailure.notFound => l10n.inviteNotFound,
            InviteFailure.ownInvite => l10n.inviteOwn,
            InviteFailure.exhausted => l10n.inviteExhausted,
            InviteFailure.unavailable => l10n.inviteUnavailable,
            _ => l10n.socialTryAgain,
          }}',
        );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AppBloc, AppState>(
          listener: (_, state) {
            _router.refresh();
            _followUser(state);
          },
        ),
        BlocListener<NotificationsCubit, NotificationsState>(
          listenWhen: (previous, current) => current.linkId != previous.linkId,
          listener: _routeLink,
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
        // How the finished workout's save is going, wherever the user is.
        builder: (context, child) => MultiBlocListener(
          listeners: [
            BlocListener<ActiveWorkoutCubit, ActiveWorkoutState>(
              listenWhen: (previous, current) =>
                  current.saveNoticeId != previous.saveNoticeId,
              listener: _showSaveNotice,
            ),
            // A follow or nudge that failed, from whichever screen.
            BlocListener<CircleBloc, CircleState>(
              listenWhen: (previous, current) =>
                  current.noticeId != previous.noticeId,
              listener: showCircleNotice,
            ),
            BlocListener<InviteCubit, InviteState>(
              listenWhen: (previous, current) =>
                  current.resultId != previous.resultId,
              listener: _onInvite,
            ),
          ],
          child: child!,
        ),
      ),
    );
  }

  static void _showSaveNotice(BuildContext context, ActiveWorkoutState state) {
    final l10n = context.l10n;
    final notice = state.saveNotice;
    if (notice == null) return;
    if (notice == SaveProgress.failed) {
      unawaited(HapticFeedback.errorNotification());
    } else if (notice == SaveProgress.saved) {
      unawaited(HapticFeedback.successNotification());
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (notice) {
            SaveProgress.retrying => l10n.saveRetrying,
            SaveProgress.saved => l10n.saveSaved,
            SaveProgress.failed => l10n.saveFailed,
          }),
          duration: Duration(seconds: notice == SaveProgress.failed ? 8 : 6),
        ),
      );
  }
}

/// Where the router sends [location] for [state], or null to stay: signed
/// out to sign-in; while the profile loads (or can't be read) to the launch
/// screen, remembering where the user was going; during onboarding to the
/// screen of the step the profile resumes at (`OnboardingStepRouter`); and
/// once onboarded, away from sign-in, launch and onboarding to the tabs.
String? appRedirect(AppState state, Uri location) {
  final path = location.path;
  final onSignIn = path == SignInPage.path;
  final onLaunch = path == LaunchPage.path;
  if (state is! AppAuthenticated) return onSignIn ? null : SignInPage.path;
  if (state.profileStatus != AppProfileStatus.ready) {
    if (onLaunch) return null;
    return Uri(
      path: LaunchPage.path,
      queryParameters: onSignIn || path.startsWith(onboardingPath)
          ? null
          : {LaunchPage.fromParameter: location.toString()},
    ).toString();
  }
  final step = state.onboardingStep;
  if (step != null) {
    final target = onboardingRoute(step)!.path;
    // Build My Own's day editor picks exercises over the program step, and
    // can create one from the picker.
    if (path == ExercisePickerPage.path || path == CreateExercisePage.path) {
      return null;
    }
    return path == target ? null : target;
  }
  if (onLaunch) {
    return location.queryParameters[LaunchPage.fromParameter] ??
        AppTab.today.path;
  }
  return onSignIn || path.startsWith(onboardingPath) ? AppTab.today.path : null;
}
