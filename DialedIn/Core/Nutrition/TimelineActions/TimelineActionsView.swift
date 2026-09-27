import SwiftUI

struct TimelineActionsDelegate {
    /// The day the timeline is showing. Copy and Clear both act on it.
    var date: Date = Date()

    var eventParameters: [String: Any]? {
        nil
    }
}

struct TimelineActionsView: View {

    @State var presenter: TimelineActionsPresenter
    let delegate: TimelineActionsDelegate

    var body: some View {
        List {
            Section {
                ListRowButton(title: String(localized: "Copy Day"), systemImage: "doc.on.doc", accessory: .none) {
                    presenter.onCopyDayPressed(delegate: delegate)
                }
                ListRowButton(title: String(localized: "Clear Day"), systemImage: Symbol.delete, tint: .danger, accessory: .none) {
                    presenter.onClearDayPressed(delegate: delegate)
                }
                ListRowToggle(
                    title: String(localized: "Hide Food Details"),
                    systemImage: "eye.slash",
                    isOn: Binding(
                        get: { presenter.hideFoodDetails },
                        set: { presenter.hideFoodDetails = $0 }
                    )
                )
                ListRowToggle(
                    title: String(localized: "Hide Empty Hours"),
                    systemImage: "hourglass",
                    isOn: Binding(
                        get: { presenter.hideEmptyHours },
                        set: { presenter.hideEmptyHours = $0 }
                    )
                )
            }
            .listSectionMargins(.vertical, 0)
        }
        .navigationTitle("Timeline Actions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presenter.isChoosingCopyDestination) {
            copyDestinationSheet
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var copyDestinationSheet: some View {
        NavigationStack {
            DatePicker(
                "Copy to",
                selection: $presenter.copyDestination,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .navigationTitle("Copy Day")
            .navigationBarTitleDisplayMode(.inline)
            .bottomCTA {
                CallToActionButton {
                    presenter.onCopyDayConfirmed(delegate: delegate)
                } label: {
                    Text("Copy")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        presenter.isChoosingCopyDestination = false
                    }
                }
            }
        }
        // A native sheet: the date picker binds the presenter's copy destination.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = TimelineActionsDelegate()

    return RouterView { router in
        builder.timelineActionsView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func timelineActionsView(router: AnyRouter, delegate: TimelineActionsDelegate) -> some View {
        TimelineActionsView(
            presenter: TimelineActionsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showTimelineActionsView(delegate: TimelineActionsDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.timelineActionsView(router: router, delegate: delegate)
        }
    }

}
