//
//  NotificationSettingsView.swift
//  Compound
//
//  Created by Andrew Coyle on 29/09/2026.
//

import SwiftUI

struct NotificationSettingsDelegate {

}

struct NotificationSettingsView: View {

    let delegate: NotificationSettingsDelegate
    @State var presenter: NotificationSettingsPresenter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            switch presenter.permissionPrompt {
            case .askFirst: askFirstSection
            case .denied: deniedSection
            case nil: EmptyView()
            }
            Group {
                socialSection
                remindersSection
            }
            .disabled(!presenter.canChangeSwitches)
        }
        .navigationTitle("Notification Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { presenter.onViewAppear() }
        .task { await presenter.checkPermissions() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presenter.onSceneBecameActive() }
        }
    }

    private var askFirstSection: some View {
        Section {
            InlineMessage(.info, "Notifications are off. Turn them on to get the alerts below.")
            ListRowButton(title: "Turn On Notifications", systemImage: Symbol.notifications, accessory: .none) {
                presenter.onRequestNotificationsPressed()
            }
        }
    }

    private var deniedSection: some View {
        Section {
            InlineMessage(.warning, "Notifications for Compound are turned off in Settings. Allow them there to use these switches.")
            ListRowButton(title: "Open Settings", systemImage: Symbol.settings, accessory: .none) {
                presenter.onOpenSettingsPressed()
            }
        }
    }

    private var socialSection: some View {
        Section {
            ListRowToggle(title: "Likes", isOn: $presenter.isLikesPushEnabled)
            ListRowToggle(title: "Comments", isOn: $presenter.isCommentsPushEnabled)
            ListRowToggle(title: "Mentions", isOn: $presenter.isMentionsPushEnabled)
            ListRowToggle(title: "New followers", isOn: $presenter.isFollowsPushEnabled)
            ListRowToggle(title: "Nudges", isOn: $presenter.isNudgesPushEnabled)
            ListRowToggle(title: "Shares", isOn: $presenter.isSharesPushEnabled)
            ListRowToggle(title: "Challenges", isOn: $presenter.isChallengesPushEnabled)
        } header: {
            Text("Social")
        } footer: {
            Text("Get a push when someone in your circle interacts with you, even when Compound is closed.")
        }
    }

    private var remindersSection: some View {
        Section {
            ListRowToggle(title: "Streak reminder", isOn: $presenter.isStreakReminderEnabled)
            if presenter.isStreakReminderEnabled {
                Picker("Remind me at", selection: $presenter.streakReminderHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now, format: .dateTime.hour())
                            .tag(hour)
                    }
                }
            }
            ListRowToggle(title: "Weekly digest", isOn: $presenter.isWeeklyDigestEnabled)
            ListRowToggle(title: "Workout reminders", isOn: $presenter.isComeBackRemindersEnabled)
            ListRowToggle(title: "Meal reminders", isOn: $presenter.isMealRemindersEnabled)
        } header: {
            Text("Reminders")
        } footer: {
            Text("The streak reminder comes only on a day your streak would end. The weekly digest arrives on Sunday evening. Workout reminders come one, three and five days after you last open Compound. Meal reminders come at breakfast, lunch and dinner.")
        }
    }
}

extension CoreBuilder {

    func notificationSettingsView(delegate: NotificationSettingsDelegate, router: AnyRouter) -> some View {
        NotificationSettingsView(
            delegate: delegate,
            presenter: NotificationSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            )
        )
    }
}

extension CoreRouter {

    func showNotificationSettingsView(delegate: NotificationSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.notificationSettingsView(delegate: delegate, router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = NotificationSettingsDelegate()
    RouterView { router in
        builder.notificationSettingsView(delegate: delegate, router: router)
    }
}
