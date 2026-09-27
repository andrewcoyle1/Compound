//
//  ProfileView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2025.
//

import SwiftUI

struct ProfileView: View {
    
    @State var presenter: ProfilePresenter
    @ScaledMetric(relativeTo: .title3) private var avatarSide: CGFloat = 80

    var body: some View {
        List {
            if let user = presenter.currentUser,
               let firstName = user.firstNameCalculated,
                !firstName.isEmpty {
                profileHeaderSection
                    .listSectionMargins(.top, 0)
                
                generalSection
                nutritionSettingsSection
                trainingSettingsSection
                
                communityAndSupportSection
                
                otherSection
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
    }
    
    private var profileHeaderSection: some View {
        Section {
            if let user = presenter.currentUser {
                Button {
                    presenter.onProfileEditPressed()
                } label: {
                    HStack(spacing: Spacing.l) {
                        ZStack {
                            Image(systemName: Symbol.profile)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                            if let urlString = user.profileImageNameCalculated {
                                ImageLoaderView(urlString: urlString, clipShape: AnyShape(Circle()))
                            }
                        }
                        .frame(width: avatarSide, height: avatarSide)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(presenter.fullName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if let email = user.emailCalculated {
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
            ListRowButton(title: String(localized: "Shortcuts"), systemImage: "square.2.layers.3d") {
                presenter.onShortcutsPressed()
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
            ListRowButton(title: String(localized: "Exercises"), systemImage: Symbol.exercise) {
                presenter.onExerciseLibraryPressed()
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
            ListRowButton(title: String(localized: "Knowledge Base"), systemImage: Symbol.knowledgeBase) {
                presenter.onKnowledgeBasePressed()
            }
            ListRowButton(title: String(localized: "Roadmap"), systemImage: Symbol.roadmap) {
                presenter.onRoadmapPressed()
            }
            ListRowButton(title: String(localized: "Support"), systemImage: "questionmark.circle") {
                presenter.onSupportPressed()
            }
            ListRowButton(title: String(localized: "Rate us on the app store"), systemImage: "star") {
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
            ListRowButton(title: String(localized: "App Icon"), systemImage: "app.grid") {
                presenter.onAppIconPressed()
            }
            ListRowButton(title: String(localized: "Tutorials"), systemImage: Symbol.tutorials) {
                presenter.onTutorialPressed()
            }
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
            .sheet,
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
