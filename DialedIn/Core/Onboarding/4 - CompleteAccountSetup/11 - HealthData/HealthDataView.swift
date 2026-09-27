//
//  OnboardingHealthData.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

struct OnboardingHealthDataView: View {

    @State var presenter: OnboardingHealthDataPresenter

    var body: some View {
        List {
            yourHealthYourDataSection
            whatYouGetSection
            yourControlSection
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Health Data")
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        #if DEBUG || MOCK
        .toolbar {
            toolbarContent
        }
        #endif
        .safeAreaInset(edge: .bottom) {
            VStack {
                CallToActionButton {
                    presenter.onAllowAccessPressed()
                } label: {
                    Text("Allow access to health data")
                }
                .accessibilityIdentifier("AllowAccessToHealthData")

                CallToActionButton(isPrimaryAction: false) {
                    presenter.onSkipForNowPressed()
                } label: {
                    Text("Skip for now")
                }
                .accessibilityIdentifier("SkipForNow")
            }
            .padding(.bottom)
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

    private var yourHealthYourDataSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scalemass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Why We Request Health Data Access")
                        .font(.headline)
                    Text("Compound needs permission to read and write your weight data in Apple Health. This allows us to automatically track your progress, update your weight logs, and provide you with accurate charts and insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Your Health, Your Data")
        }
    }
    
    private var whatYouGetSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Sync your weight entries seamlessly between Compound and Apple Health.", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("See all your progress in one place, even if you use other health apps.", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("Let Compound update your Health data when you log new weights.", systemImage: "plus.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("What You Get")
        }
    }
    
    private var yourControlSection: some View {
        Section {
            Label("Maintain full control: you can revoke access or limit permissions at any time in the Health app.", systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Your Control")
        }
    }
}

extension CoreBuilder {
    func onboardingHealthDataView(router: AnyRouter) -> some View {
        OnboardingHealthDataView(
            presenter: OnboardingHealthDataPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showOnboardingHealthDataView() {
        router.showScreen(.push) { router in
            builder.onboardingHealthDataView(router: router)
        }
    }
}

#Preview("Proceed to Notifications") {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.onboardingHealthDataView(router: router)
    }
    
}
