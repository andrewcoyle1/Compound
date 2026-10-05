import SwiftUI

struct FavouriteMeasurementsDelegate { }

struct FavouriteMeasurementsView: View {

    @State var presenter: FavouriteMeasurementsPresenter
    let delegate: FavouriteMeasurementsDelegate

    var body: some View {
        List {
            Section {
                ForEach(presenter.allMeasurements, id: \.self) { measurement in
                    SelectableRow(title: measurement, isSelected: presenter.isSelected(measurement)) {
                        presenter.toggleMeasurement(measurement)
                    }
                }
            } header: {
                Text("Favorites")
            }
        }
        .navigationTitle("Favorite Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
}

extension CoreBuilder {

    func favouriteMeasurementsView(router: AnyRouter, delegate: FavouriteMeasurementsDelegate) -> some View {
        FavouriteMeasurementsView(
            presenter: FavouriteMeasurementsPresenter(
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
    let delegate = FavouriteMeasurementsDelegate()

    return RouterView { router in
        builder.favouriteMeasurementsView(router: router, delegate: delegate)
    }
}
