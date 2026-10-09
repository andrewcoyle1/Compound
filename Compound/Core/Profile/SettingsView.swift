//
//  SettingsView.swift
//  Compound
//
//  Created by Andrew Coyle on 25/09/2025.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    
    @State var presenter: SettingsPresenter

    var body: some View {
        List {
            generalSection
            nutritionSettingsSection
            trainingSettingsSection

            communityAndSupportSection

            otherSection

            securitySection
        }
        .manageSubscriptionsSheet(isPresented: $presenter.isManageSubscriptionsPresented)
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }
    
    private var generalSection: some View {
        Section {
            ListRowButton(title: String(localized: "Subscription"), systemImage: "tag", accessory: .value(presenter.subscriptionStatus)) {
                presenter.onSubscriptionPressed()
            }
            ListRowButton(title: String(localized: "Notification Settings"), systemImage: Symbol.notifications) {
                presenter.onNotificationSettingsPressed()
            }
            ListRowButton(title: String(localized: "Integrations"), systemImage: "app.connected.to.app.below.fill") {
                presenter.onIntegrationsPressed()
            }
            ListRowButton(title: String(localized: "Coach"), systemImage: Symbol.coach) {
                presenter.onCoachPressed()
            }
            ListRowButton(title: String(localized: "Units"), systemImage: "base.unit") {
                presenter.onUnitsPressed()
            }
            ListRowButton(title: String(localized: "Analytics"), systemImage: Symbol.analytics) {
                presenter.onCustomiseAnalyticsPressed()
            }
            ListRowButton(title: String(localized: "Siri"), systemImage: "siri") {
                presenter.onSiriPressed()
            }
        } header: {
            Text("General")
        }
    }

    private var nutritionSettingsSection: some View {
        Section {
            ListRowButton(title: String(localized: "Weight Goal"), systemImage: Symbol.goal, accessory: .value(presenter.weightGoalStatus)) {
                presenter.onWeightGoalPressed()
            }
            ListRowButton(title: String(localized: "Food Log"), systemImage: Symbol.food) {
                presenter.onFoodLogSettingsPressed()
            }
            ListRowButton(title: String(localized: "Expenditure"), systemImage: Symbol.expenditure) {
                presenter.onExpenditureSettingsPressed()
            }
            ListRowButton(title: String(localized: "Strategy"), systemImage: Symbol.strategy) {
                presenter.onStrategySettingsPressed()
            }
            ListRowButton(title: String(localized: "Nutrition Plan"), systemImage: Symbol.meal) {
                presenter.onNutritionPlanPressed()
            }
        } header: {
            Text("Nutrition Settings")
        }
    }

    private var trainingSettingsSection: some View {
        Section {
            ListRowButton(title: String(localized: "Gym Profiles"), systemImage: Symbol.gym) {
                presenter.onGymProfilesPressed()
            }
            ListRowButton(title: String(localized: "Workout Settings"), systemImage: Symbol.workout) {
                presenter.onWorkoutSettingsPressed()
            }
        } header: {
            Text("Training Settings")
        }
    }

    private var communityAndSupportSection: some View {
        Section {
            ListRowButton(title: String(localized: "Invite a friend"), systemImage: "person.badge.plus") {
                Task { await presenter.onInviteFriendPressed() }
            }
            
            // Pending: Knowledge Base is hidden: there is no help site. Add a row calling `presenter.onKnowledgeBasePressed()` here once one is published, and point that at its URL in `Constants`.
            
            // Pending: Roadmap is hidden: there is no public roadmap. Add a row calling `presenter.onRoadmapPressed()` here once one is published, and point that at its URL in `Constants`.
            ListRowButton(title: String(localized: "Support"), systemImage: "questionmark.circle") {
                presenter.onSupportPressed()
            }
            ListRowButton(title: String(localized: "Rate Compound"), systemImage: "star") {
                presenter.onRatingsButtonPressed()
            }
        } header: {
            Text("Community & Support")
        }
    }

    private var otherSection: some View {
        Section {
            ListRowButton(title: String(localized: "Legal"), systemImage: Symbol.legal) {
                presenter.onLegalPressed()
            }
            ListRowButton(title: String(localized: "Methods & Sources"), systemImage: Symbol.knowledgeBase) {
                presenter.onMethodsAndSourcesPressed()
            }
            
            // Pending: App Icon is hidden: the asset catalog has one icon. Add a row calling `presenter.onAppIconPressed()` here once alternate icons ship and `AppIconView` offers them.
            
            // Pending: Tutorials is hidden: there are no tutorials. Add a row calling `presenter.onTutorialPressed()` here once `TutorialsView` has content.
            ListRowButton(title: String(localized: "About"), systemImage: Symbol.info) {
                presenter.onAboutPressed()
            }
        } header: {
            Text("Other")
        }
    }

    private var securitySection: some View {
        Section {
            // Read-only, not an editor. Sign-in is Apple, Google or anonymous, so the address is the
            // identity provider's and cannot be changed from here. A "Password ********" row used to
            // sit below this one — removed, because there is no password to change: `SignInOption`
            // has no email case anywhere in the app.
            ListRow(title: String(localized: "Sign-In Method"), accessory: .value(presenter.signInMethod))
            ListRow(title: String(localized: "Email"), accessory: .value(presenter.email ?? String(localized: "Not provided")))

            // Signing an anonymous account out locks it away for good, so that account is offered
            // the upgrade in place of Sign Out rather than alongside it.
            if presenter.isAnonymousUser {
                ListRowButton(title: String(localized: "Save Account"), accessory: .none) {
                    presenter.onSaveAccountPressed()
                }
            } else {
                ListRowButton(title: String(localized: "Sign Out"), accessory: .none) {
                    presenter.onSignOutPressed()
                }
            }
            Button(role: .destructive) {
                presenter.onDeleteAccountPressed()
            } label: {
                Text("Delete Account")
            }
        } header: {
            Text("Security")
        }
    }
}

extension CoreBuilder {
    func settingsView(router: AnyRouter) -> some View {
        SettingsView(
            presenter: SettingsPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {

    func showSettingsView() {
        router.showScreen(.push) { router in
            builder.settingsView(router: router)
        }
    }
}

// MARK: - Previews
#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.settingsView(router: router)
    }
}
