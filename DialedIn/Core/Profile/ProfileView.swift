//
//  ProfileView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2025.
//

import SwiftUI
import StoreKit

struct ProfileView: View {
    
    @State var presenter: ProfilePresenter
    @ScaledMetric(relativeTo: .title3) private var avatarSide: CGFloat = 80

    var body: some View {
        // Every section shows whatever the profile holds: gating them on a first name left the
        // sheet blank, Sign Out and Delete Account included, until the user document arrived.
        List {
            profileHeaderSection
                .listSectionMargins(.top, 0)

            generalSection
            nutritionSettingsSection
            trainingSettingsSection

            communityAndSupportSection

            otherSection
        }
        .manageSubscriptionsSheet(isPresented: $presenter.isManageSubscriptionsPresented)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
    }
    
    private var profileHeaderSection: some View {
        Section {
            let user = presenter.currentUser
            Button {
                presenter.onProfileEditPressed()
            } label: {
                HStack(spacing: Spacing.l) {
                    ZStack {
                        Image(systemName: Symbol.profile)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                        if let urlString = user?.profileImageNameCalculated {
                            ImageLoaderView(urlString: urlString, clipShape: AnyShape(Circle()))
                        }
                    }
                    .frame(width: avatarSide, height: avatarSide)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(presenter.fullName.isEmpty ? String(localized: "Add your name") : presenter.fullName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(presenter.fullName.isEmpty ? .secondary : .primary)
                        if let email = user?.emailCalculated {
                            Text(email)
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.forward")
                        .font(.rowDetail.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
        } header: {
            Text("Profile")
        }
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
            // swiftlint:disable:next todo
            // TODO: Knowledge Base is hidden: there is no help site. Add a row calling `presenter.onKnowledgeBasePressed()` here once one is published, and point that at its URL in `Constants`.
            // swiftlint:disable:next todo
            // TODO: Roadmap is hidden: there is no public roadmap. Add a row calling `presenter.onRoadmapPressed()` here once one is published, and point that at its URL in `Constants`.
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
            // swiftlint:disable:next todo
            // TODO: App Icon is hidden: the asset catalog has one icon. Add a row calling `presenter.onAppIconPressed()` here once alternate icons ship and `AppIconView` offers them.
            // swiftlint:disable:next todo
            // TODO: Tutorials is hidden: there are no tutorials. Add a row calling `presenter.onTutorialPressed()` here once `TutorialsView` has content.
            ListRowButton(title: String(localized: "About"), systemImage: Symbol.info) {
                presenter.onAboutPressed()
            }
        } header: {
            Text("Other")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
    }
}

extension CoreBuilder {
    func profileView(router: AnyRouter) -> some View {
        ProfileView(
            presenter: ProfilePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    
    func showProfileView() {
        router.showScreen(.sheet) { router in
            builder.profileView(router: router)
        }
    }
    
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) {
        router.showScreenWithZoomTransition(
            .fullScreenCover,
            transitionID: transitionId,
            namespace: namespace) { router in
                builder.profileView(router: router)
            }
    }
}

// MARK: - Previews
#Preview("User Has Profile") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.profileView(router: router)
    }
    
}

#Preview("User No Profile") {
    let container = DevPreview.shared.container()
    
    let userSyncEngine = DocumentSyncEngine<UserModel>(
        remote: MockRemoteDocumentService(),
        managerKey: "user",
        enableLocalPersistence: true,
        logger: nil
    )
    let followingUsersSyncEngine = CollectionSyncEngine<UserModel>(
        remote: MockRemoteCollectionService(),
        managerKey: "followingUsers",
        enableLocalPersistence: true,
        logger: nil
    )
    let userQueryService = MockUserQueryService()
    let privateSettingsSyncEngine = DocumentSyncEngine<PrivateUserSettings>(
        remote: MockRemoteDocumentService(),
        managerKey: "private_user_settings",
        enableLocalPersistence: true,
        logger: nil
    )
    container.register(UserManager.self, service: UserManager(
        queryService: userQueryService,
        userSyncEngine: userSyncEngine,
        followingUsersSyncEngine: followingUsersSyncEngine,
        privateSettingsSyncEngine: privateSettingsSyncEngine
    ))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.profileView(router: router)
    }
    
}
