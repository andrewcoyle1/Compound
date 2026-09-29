import SwiftUI

struct TimeSelectionDelegate { }

struct TimeSelectionView: View {

    @State var presenter: TimeSelectionPresenter
    let delegate: TimeSelectionDelegate

    var body: some View {
        List {
            Section {
                CustomToggleView(
                    title: String(localized: "Auto-set Current Time"),
                    subtitle: String(localized: "Automatically set the time to now when logging a meal"),
                    bool: $presenter.autoSetCurrentTime
                )
            }
        }
        .navigationTitle("Time Selection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
    }
}

extension CoreBuilder {

    func timeSelectionView(router: AnyRouter, delegate: TimeSelectionDelegate) -> some View {
        TimeSelectionView(
            presenter: TimeSelectionPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = TimeSelectionDelegate()

    return RouterView { router in
        builder.timeSelectionView(router: router, delegate: delegate)
    }
}
