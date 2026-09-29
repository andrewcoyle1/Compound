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
                CustomLabelButtonView(symbolName: "pages", title: String(localized: "Copy Day")) { EmptyView() }
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onCopyDayPressed(delegate: delegate)
                    }
                CustomLabelButtonView(symbolName: "trash", title: String(localized: "Clear Day")) { EmptyView() }
                    .tappableBackground()
                    .anyButton(.highlight) {
                        presenter.onClearDayPressed(delegate: delegate)
                    }
                CustomToggleView(
                    symbolName: "chevron.up",
                    title: String(localized: "Hide Food Details"),
                    bool: Binding(
                        get: { presenter.hideFoodDetails },
                        set: { presenter.hideFoodDetails = $0 }
                    )
                )
                CustomToggleView(
                    symbolName: "hourglass",
                    title: String(localized: "Hide Empty Hours"),
                    bool: Binding(
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
            .safeAreaInset(edge: .bottom) {
                CallToActionButton {
                    presenter.onCopyDayConfirmed(delegate: delegate)
                } label: {
                    Text("Copy")
                }
                .padding(.bottom)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        presenter.isChoosingCopyDestination = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
        router.showScreen(.sheetConfig(config: ResizableSheetConfig(detents: [.fraction(0.4)]))) { router in
            builder.timelineActionsView(router: router, delegate: delegate)
        }
    }

}
