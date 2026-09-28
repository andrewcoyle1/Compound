//
//  NotificationsPermissionsView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/08/2025.
//

import SwiftUI

struct NotificationsPermissionsView: View {

    @State var presenter: NotificationsPermissionsPresenter

    var body: some View {
        OnboardingStepScaffold(
            title: "Turn On Notifications?",
            progress: OnboardingStep.notifications.progress,
            primary: .init(title: "Enable notifications", identifier: "EnableNotifications") { presenter.onEnableNotificationsPressed() },
            secondary: .init(title: "Skip for now", identifier: "SkipForNow") { presenter.onSkipForNowPressed() },
            onDevSettingsPressed: onDevSettingsPressed
        ) {
            Section {
                OnboardingFeatureRow(
                    title: "Stay Informed & Motivated",
                    detail: "Enable notifications to receive reminders for workouts, nutrition tracking, and important updates. Stay on track and never miss a beat in your fitness journey.",
                    systemImage: Symbol.notifications
                )
            } header: {
                Text("Why Enable Notifications?")
            }
            Section {
                Label("You can change your notification preferences at any time in Settings.", systemImage: Symbol.settings)
                Label("We respect your privacy. Notifications are only used to help you reach your goals and are never shared.", systemImage: "lock.shield")
            } header: {
                Text("Good to Know")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private var onDevSettingsPressed: (() -> Void)? {
        #if DEV || MOCK
        presenter.onDevSettingsPressed
        #else
        nil
        #endif
    }
}

extension CoreBuilder {
    func onboardingNotificationsView(router: AnyRouter) -> some View {
        NotificationsPermissionsView(
            presenter: NotificationsPermissionsPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showNotificationsPermissionsView() {
        router.showScreen(.push) { router in
            builder.onboardingNotificationsView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.onboardingNotificationsView(router: router)
    }
    
}
