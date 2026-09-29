//
//  AppView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/08/2025.
//

import SwiftUI
import SwiftfulUI

struct AppView<Content: View>: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var presenter: AppPresenter

    @ViewBuilder var content: () -> Content

    var body: some View {
        RootView(
            delegate: RootDelegate(
                onApplicationDidAppear: nil,
                onApplicationWillEnterForeground: { _ in
                    Task {
                        await presenter.checkUserStatus()
                    }
                },
                onApplicationDidBecomeActive: nil,
                onApplicationWillResignActive: nil,
                onApplicationDidEnterBackground: nil,
                onApplicationWillTerminate: nil
            ),
            content: {
                content()
                    .task {
                        await presenter.checkUserStatus()
                    }
                    .onChange(of: presenter.auth?.uid) { _, newValue in
                        if newValue == nil || newValue?.isEmpty == true {
                            Task {
                                await presenter.checkUserStatus()
                            }
                        }
                    }
            }
        )
        .onNotificationReceived(name: .fcmToken) { notification in
            presenter.onFCMTokenRecieved(notification: notification)
        }
        .onNotificationReceived(name: .newActivityNotification) { notification in
            presenter.onNewActivityNotification(notification: notification)
        }
        .onNotificationReceived(name: .appToast) { notification in
            presenter.onAppToast(notification: notification)
        }
        // One overlay, so a toast and a banner raised together stack rather than draw over each other.
        .overlay(alignment: .top) {
            VStack(spacing: Spacing.s) {
                if let toast = presenter.toast {
                    Button {
                        presenter.onToastDismissed()
                    } label: {
                        AppToastView(toast: toast)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Dismisses the message")
                    .simultaneousGesture(swipeUp { presenter.onToastDismissed() })
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if let banner = presenter.activityBanner {
                    Button {
                        presenter.onActivityBannerPressed()
                    } label: {
                        ActivityNotificationBannerView(notification: banner)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens Notifications")
                    .simultaneousGesture(swipeUp { presenter.onActivityBannerDismissed() })
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, Spacing.s)
            .reducedMotionAnimation(.spring, value: presenter.toast?.id)
            .reducedMotionAnimation(.spring, value: presenter.activityBanner?.id)
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }

    }

    /// Flicking a toast or banner up puts it away, as a system banner does.
    private func swipeUp(_ action: @escaping () -> Void) -> some Gesture {
        DragGesture(minimumDistance: Spacing.l)
            .onEnded { value in
                if value.translation.height < -Spacing.l { action() }
            }
    }
}

#Preview("AppView - Tabbar") {
    let container = DevPreview.shared.container()
    container.register(AppState.self, service: AppState(startingModuleId: Constants.tabBarModuleId))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return builder.appView()
}

#Preview("AppView - Onboarding") {
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
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(scenario: .newAnonymous)))
    container.register(AppState.self, service: AppState(startingModuleId: Constants.onboardingModuleId))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return builder.appView()
}

extension CoreBuilder {
    func appView() -> some View {
        AppView(
            presenter: AppPresenter(
                interactor: interactor
            ),
            content: {
                switch interactor.startingModuleId {
                case Constants.tabBarModuleId:
                    // The app's only module-switching RouterView. `switchToCoreModule()` and
                    // `switchToOnboardingModule()` land here, and it records the module id that
                    // `AppState.startingModuleId` reads on the next launch.
                    RouterView(id: Constants.tabBarModuleId, addNavigationStack: false, addModuleSupport: true) { router in
                        coreModuleEntryView(router: router)
                    }
                default:
                    RouterView(id: Constants.onboardingModuleId, addNavigationStack: false, addModuleSupport: true) { _ in
                        onboardingModuleEntryView()
                    }
                }
            }
        )
    }
    
    func onboardingModuleEntryView() -> some View {
        onboardingFlow()
    }
    
    func coreModuleEntryView(router: AnyRouter) -> some View {
        tabBarView(router: router)
    }
}

extension CoreRouter {
    
    func switchToCoreModule() {
        router.showModule(.trailing, id: Constants.tabBarModuleId, onDismiss: nil) { router in
            self.builder.coreModuleEntryView(router: router)
        }
    }
    
}

extension CoreRouter {
    
    func switchToOnboardingModule() {
        router.showModule(.leading, id: Constants.onboardingModuleId, onDismiss: nil) { _ in
            self.builder.onboardingModuleEntryView()
        }
    }
}
