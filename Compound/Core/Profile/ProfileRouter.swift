//
//  ProfileRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ProfileRouter: GlobalRouter, ShareSheetRouter {
    func showAccountView(delegate: AccountDelegate)
    func showNotificationsView()
    func showNotificationSettingsView(delegate: NotificationSettingsDelegate)
    func showWorkoutSettingsView(delegate: WorkoutSettingsDelegate)
    func showGymProfilesView()
    func showTutorialsView(delegate: TutorialsDelegate)
    func showAboutView(delegate: AboutDelegate)
    func showAppIconView(delegate: AppIconDelegate)
    func showUnitsView(delegate: UnitsDelegate)
    func showIntegrationsView(delegate: IntegrationsDelegate)
    func showSiriView(delegate: SiriDelegate)
    func showLegalView(delegate: LegalDelegate)
    func showPaywall(isOnboarding: Bool)
    func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate)
    func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate)
    func showExpenditureSettingsView(delegate: ExpenditureSettingsDelegate)
    func showStrategySettingsView(delegate: StrategySettingsDelegate)
    func showPreferredDietView(isFromSettings: Bool)
}

extension CoreRouter: ProfileRouter { }
