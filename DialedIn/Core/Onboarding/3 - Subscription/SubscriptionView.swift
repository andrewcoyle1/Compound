//
//  SubscriptionView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 04/10/2025.
//

import SwiftUI

struct SubscriptionView: View {

    @State var presenter: SubscriptionPresenter

    var body: some View {
        List {
            whySubscribeSection
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden()
        #if DEBUG || MOCK
        .toolbar {
            toolbarContent
        }
        #endif
        .safeAreaInset(edge: .bottom) {
            CallToActionButton {
                presenter.onContinuePressed()
            } label: {
                Text("Continue")
            }
            .accessibilityIdentifier("Continue")
        }
    }
    
    #if DEBUG || MOCK
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
    }
#endif

    private var whySubscribeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                benefitRow(
                    title: String(localized: "Personalized plans"),
                    subtitle: String(localized: "Training and nutrition tailored to your goals and schedule."),
                    systemImage: "figure.run"
                )
                benefitRow(
                    title: String(localized: "Smart coaching"),
                    subtitle: String(localized: "Daily guidance powered by your data and AI insights."),
                    systemImage: "brain.head.profile"
                )
                benefitRow(
                    title: String(localized: "Progress tracking"),
                    subtitle: String(localized: "See trends, weekly summaries, and PRs at a glance."),
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                benefitRow(
                    title: String(localized: "HealthKit sync"),
                    subtitle: String(localized: "Automatically log workouts and recovery from Apple Health."),
                    systemImage: "heart.circle"
                )
                benefitRow(
                    title: String(localized: "Accountability"),
                    subtitle: String(localized: "Reminders and nudges to help you stay consistent."),
                    systemImage: "bell.badge"
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Why subscribe?")
        }
    }
    
    func benefitRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}

extension CoreBuilder {
    func subscriptionView(router: AnyRouter) -> some View {
        SubscriptionView(
            presenter: SubscriptionPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showSubscriptionView() {
        router.showScreen(.push) { router in
            builder.subscriptionView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.subscriptionView(router: router)
    }
    
}
