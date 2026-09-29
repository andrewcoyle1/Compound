import SwiftUI
import AppIntents

struct SiriDelegate {
    
}

struct SiriView: View {
    
    @State var presenter: SiriPresenter
    let delegate: SiriDelegate
    
    var body: some View {
        // The four App Shortcuts the app really ships (`DialedInAppShortcuts`). They work in Siri,
        // Spotlight and the Shortcuts app with no setup; this screen says what to say.
        List {
            Section {
                shortcutRow(title: "Start Workout", phrase: "“Start a workout in Compound”", systemImage: "play.circle.fill")
                shortcutRow(title: "Log Weight", phrase: "“Log my weight in Compound”", systemImage: "scalemass")
                shortcutRow(title: "Workouts This Week", phrase: "“How many workouts this week in Compound”", systemImage: "calendar")
                shortcutRow(title: "Today's Workout", phrase: "“What's my workout today in Compound”", systemImage: "figure.strengthtraining.traditional")
            } header: {
                Text("Ask Siri")
            }

            Section {
                ShortcutsLink()
            } footer: {
                Text("Add these to the Shortcuts app to run them from your Home Screen or Action button.")
            }
        }
        .navigationTitle("Siri")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private func shortcutRow(title: LocalizedStringKey, phrase: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.rowTitle)
                Text(phrase)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .accessibilityElement(children: .combine)
    }
}

extension CoreBuilder {
    
    func siriView(router: AnyRouter, delegate: SiriDelegate) -> some View {
        SiriView(
            presenter: SiriPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showSiriView(delegate: SiriDelegate) {
        router.showScreen(.push) { router in
            builder.siriView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = SiriDelegate()
    
    return RouterView { router in
        builder.siriView(router: router, delegate: delegate)
    }
    
}
