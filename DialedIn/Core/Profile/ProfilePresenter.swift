//
//  ProfilePresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 21/10/2025.
//

import SwiftUI

@Observable
@MainActor
class ProfilePresenter {
    private let interactor: ProfileInteractor
    private let router: ProfileRouter

    private(set) var activeGoal: WeightGoal?

    var currentUser: UserModel? {
        interactor.currentUser
    }

    var fullName: String {
        guard let user = currentUser else { return "" }
        let first = user.firstNameCalculated ?? ""
        let last = user.lastNameCalculated ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }

    var currentGoal: WeightGoal? {
        interactor.currentGoal
    }
    
    var currentDietPlan: DietPlan? {
        interactor.currentDietPlan
    }
    
    init(
        interactor: ProfileInteractor,
        router: ProfileRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func onGymProfilesPressed() {
        router.showGymProfilesView()
    }

    func onWorkoutSettingsPressed() {
        router.showWorkoutSettingsView(delegate: WorkoutSettingsDelegate())
    }
    
    func onUnitsPressed() {
        router.showUnitsView(delegate: UnitsDelegate())
    }

    func onIntegrationsPressed() {
        router.showIntegrationsView(delegate: IntegrationsDelegate())
    }
    
    func onSiriPressed() {
        router.showSiriView(delegate: SiriDelegate())
    }
    
    func onProfileEditPressed() {
        router.showAccountView(delegate: AccountDelegate())
    }

    func onNotificationsPressed() {
        router.showNotificationsView()
    }
    
    /// What the user is paying for, shown on the Subscription row.
    ///
    /// The screen that used to state this read a stored property nothing ever assigned, so it said
    /// FREE to everyone, premium subscribers included. This reads the entitlement directly.
    var subscriptionStatus: String {
        interactor.isPremium ? String(localized: "Premium") : String(localized: "Free")
    }

    /// Apple's Manage Subscriptions sheet: plan, price, renewal date, cancel. Bound by the view.
    var isManageSubscriptionsPresented: Bool = false

    /// A subscriber is shown their subscription, not sold one: the paywall made an active
    /// subscription look lapsed and offered no way to cancel.
    func onSubscriptionPressed() {
        interactor.trackEvent(eventName: "ProfileView_Subscription_Press", parameters: nil, type: .analytic)
        if interactor.isPremium {
            isManageSubscriptionsPresented = true
        } else {
            router.showPaywall()
        }
    }

    func onExerciseLibraryPressed() {
        router.showExercisesView()
    }

    // MARK: - Community & Support

    /// Support was an empty closure, and email is support that exists today — no hosted help desk
    /// needed. This is now the app's only way to contact us: the "Contact us" row that opened the
    /// same mailto: sat on a screen nothing navigated to.
    func onSupportPressed() {
        interactor.trackEvent(eventName: "ProfileView_Support_Press", parameters: nil, type: .analytic)
        let emailString = "mailto:\(Constants.supportEmail)"
        guard let url = URL(string: emailString), UIApplication.shared.canOpenURL(url) else {
            router.showSimpleAlert(
                title: String(localized: "Unable to Open Mail"),
                subtitle: String(localized: "Email \(Constants.supportEmail) and we will get back to you.")
            )
            return
        }
        UIApplication.shared.open(url)
    }

    /// Knowledge Base and Roadmap have nowhere to go yet — neither site exists, and
    /// `Constants` has no URL for either. They say so rather than doing nothing: a row that
    /// swallows a tap reads as a bug, and the rows are worth keeping as the plan they represent.
    func onKnowledgeBasePressed() {
        interactor.trackEvent(eventName: "ProfileView_KnowledgeBase_Press", parameters: nil, type: .analytic)
        router.showSimpleAlert(
            title: String(localized: "Knowledge Base"),
            subtitle: String(localized: "There is no help site yet. In the meantime, Support emails us directly and we will answer you there.")
        )
    }

    func onRoadmapPressed() {
        interactor.trackEvent(eventName: "ProfileView_Roadmap_Press", parameters: nil, type: .analytic)
        router.showSimpleAlert(
            title: String(localized: "Roadmap"),
            subtitle: String(localized: "The public roadmap is not published yet. Send feature requests through Support and they will go on the list.")
        )
    }

    /// Creates the user's invite the first time, then hands the link to the share sheet.
    func onInviteFriendPressed() async {
        guard interactor.ensureOnline(or: router) else { return }
        interactor.trackEvent(eventName: "ProfileView_InviteFriend_Press", parameters: nil, type: .analytic)
        await InviteShareFlow(interactor: interactor, router: router).share()
    }

    func onShortcutsPressed() {
        router.showShortcutsView(delegate: ShortcutsDelegate())
    }
    
    func onCustomiseAnalyticsPressed() {
        router.showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate())
    }

    func onLegalPressed() {
        router.showLegalView(delegate: LegalDelegate())
    }
    
    /// Straight to the system review prompt. The row used to open a "Are you enjoying AIChat?"
    /// modal first and only asked the App Store after a "Yes".
    func onRatingsButtonPressed() {
        interactor.trackEvent(event: Event.ratingsPressed)
        AppStoreRatingsHelper.requestRatingsReview()
    }
    
    func onFoodLogSettingsPressed() {
        router.showFoodLogSettingsView(delegate: FoodLogSettingsDelegate())
    }

    func onExpenditureSettingsPressed() {
        router.showExpenditureSettingsView(delegate: ExpenditureSettingsDelegate())
    }
    
    func onStrategySettingsPressed() {
        router.showStrategySettingsView(delegate: StrategySettingsDelegate())
    }

    /// `isFromSettings` tells the diet flow it was entered from settings rather than onboarding, so
    /// it saves the chosen plan and returns instead of advancing to the next onboarding step.
    func onNutritionPlanPressed() {
        interactor.trackEvent(eventName: "ProfileView_NutritionPlan_Press", parameters: nil, type: .analytic)
        router.showPreferredDietView(isFromSettings: true)
    }

    func onAppIconPressed() {
        router.showAppIconView(delegate: AppIconDelegate())
    }

    func onTutorialPressed() {
        router.showTutorialsView(delegate: TutorialsDelegate())
    }

    func onAboutPressed() {
        router.showAboutView(delegate: AboutDelegate())
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
    
    enum Event: LoggableEvent {
        case ratingsPressed

        var eventName: String {
            switch self {
            case .ratingsPressed:               return "ProfileView_Ratings_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .ratingsPressed:
                return .analytic
            }
        }
    }
}
