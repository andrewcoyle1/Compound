//
//  ProfileRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ProfileRouter: GlobalRouter, ShareSheetRouter {
    func showAccountView(delegate: AccountDelegate)
    func showNotificationsView()
    func showExercisesView()
    func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate)
    func showGymProfilesView()
    func showTutorialsView(delegate: TutorialsDelegate)
    func showAboutView(delegate: AboutDelegate)
    func showAppIconView(delegate: AppIconDelegate)
    func showUnitsView(delegate: UnitsDelegate)
    func showIntegrationsView(delegate: IntegrationsDelegate)
    func showSiriView(delegate: SiriDelegate)
    func showLegalView(delegate: LegalDelegate)
    func showPaywall()
    func showShortcutsView(delegate: ShortcutsDelegate)
    func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate)
    func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate)
    func showExpenditureSettingsView(delegate: ExpenditureSettingsDelegate)
    func showStrategySettingsView(delegate: StrategySettingsDelegate)
    func showPreferredDietView(isFromSettings: Bool)
    func showRatingsModal(onYesPressed: @escaping () -> Void, onNoPressed: @escaping () -> Void)
}

extension CoreRouter: ProfileRouter { }
