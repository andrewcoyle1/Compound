//
//  ProfileView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2025.
//

import SwiftUI

struct ProfileView: View {
    
    @State var presenter: ProfilePresenter
    
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
        .toolbarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
    }
    
    private var profileHeaderSection: some View {
        Section {
            if let user = presenter.currentUser {
                HStack(spacing: 16) {
                    // Profile Image
                    ZStack {
                        Image(systemName: "person.circle")
                            .resizable()
                            .font(.system(size: 24))
                        if let urlString = user.profileImageNameCalculated {
                            ImageLoaderView(urlString: urlString, clipShape: AnyShape(Circle()))
                                .contentShape(Circle())
                        }
                    }
                    .frame(width: 80, height: 80)

                    // User Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(presenter.fullName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if let email = user.emailCalculated {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                    }
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                }
                .tappableBackground()
                .anyButton {
                    presenter.onProfileEditPressed()
                }
            }
        } header: {
            Text("Profile")
        }
    }
    
    private var generalSection: some View {
        Section {
            Group {
                HStack(spacing: 8) {
                    Label("Subscription", systemImage: "tag")
                    Spacer(minLength: 0)
                    Text(presenter.subscriptionStatus)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .tappableBackground()
                .anyButton(.highlight) {
                    presenter.onSubscriptionPressed()
                }
                Label("Integrations", systemImage: "app.connected.to.app.below.fill")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onIntegrationsPressed()
                    }
                Label("Units", systemImage: "base.unit")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onUnitsPressed()
                    }
                Label("Analytics", systemImage: "chart.bar.xaxis")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onCustomiseAnalyticsPressed()
                    }
                Label("Siri", systemImage: "siri")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onSiriPressed()
                    }
                Label("Shortcuts", systemImage: "bolt")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onShortcutsPressed()
                    }
                
            }
            .foregroundStyle(.primary)

        } header: {
            Text("General")
        }
    }
    
    private var nutritionSettingsSection: some View {
        Section {
            Group {
                Label("Food Log", systemImage: "carrot")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onFoodLogSettingsPressed()
                    }
                Label("Expenditure", systemImage: "flame")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onExpenditureSettingsPressed()
                    }
                Label("Strategy", systemImage: "map")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onStrategySettingsPressed()
                    }
                Label("Nutrition Plan", systemImage: "fork.knife")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onNutritionPlanPressed()
                    }
            }
            .foregroundStyle(.primary)
            //            .removeListRowFormatting()
        } header: {
            Text("Nutrition Settings")
        }
    }
    
    private var trainingSettingsSection: some View {
        Section {
            Group {
                Label("Gym Profiles", systemImage: "building")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onGymProfilesPressed()
                    }
                Label("Exercises", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onExerciseLibraryPressed()
                    }
                Label("Workout Settings", systemImage: "dumbbell")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onWorkoutSettingsPressed()
                    }
            }
            .foregroundStyle(.primary)
            //            .removeListRowFormatting()
        } header: {
            Text("Training Settings")
        }
    }
    
    private var communityAndSupportSection: some View {
        Section {
            Group {
                Label("Invite a friend", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        Task { await presenter.onInviteFriendPressed() }
                    }
                Label("Knowledge Base", systemImage: "book.closed")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onKnowledgeBasePressed()
                    }
                Label("Roadmap", systemImage: "map")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onRoadmapPressed()
                    }
                Label("Support", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onSupportPressed()
                    }
                Label("Rate us on the app store", systemImage: "star")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton {
                        presenter.onRatingsButtonPressed()
                    }
            }
            .foregroundStyle(.primary)

        } header: {
            Text("Community & Support")
        }
    }
    
    private var otherSection: some View {
        Section {
            Group {
                Label("Legal", systemImage: "book")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onLegalPressed()
                    }
                Label("App Icon", systemImage: "app.grid")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onAppIconPressed()
                    }
                Label("Tutorials", systemImage: "book")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onTutorialPressed()
                    }
                Label("About", systemImage: "info.circle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onAboutPressed()
                    }
            }
            .foregroundStyle(.primary)
            //            .removeListRowFormatting()
        } header: {
            Text("Other")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onDismissPressed()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close")
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
