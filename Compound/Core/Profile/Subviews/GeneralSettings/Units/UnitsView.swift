import SwiftUI

struct UnitsDelegate {
    
}

struct UnitsView: View {
    
    @State var presenter: UnitsPresenter
    let delegate: UnitsDelegate
        
    var body: some View {
        List {
            weightSection
            heightSection
            distanceSection
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    private var weightSection: some View {
        Picker(selection: $presenter.weightUnit) {
            Section {
                Text(WeightUnitPreference.kilograms.displayName)
                    .tag(WeightUnitPreference.kilograms)
                Text(WeightUnitPreference.pounds.displayName)
                    .tag(WeightUnitPreference.pounds)
            }
        } label: {
            Text("Weight Units")
        }
        .pickerStyle(.inline)
    }

    /// Labelled for height, but `LengthUnitPreference` also governs every body measurement, so the
    /// footer says so rather than letting the title imply a narrower scope.
    private var heightSection: some View {
        Picker(selection: $presenter.heightUnit) {
            Section {
                Text(LengthUnitPreference.centimeters.displayName)
                    .tag(LengthUnitPreference.centimeters)
                Text(LengthUnitPreference.inches.displayName)
                    .tag(LengthUnitPreference.inches)
            } footer: {
                Text("Also used for body measurements.")
            }
        } label: {
            Text("Height Units")
        }
        .pickerStyle(.inline)
    }
    
    private var distanceSection: some View {
        Picker(selection: $presenter.distanceUnit) {
            Section {
                Text(DistanceUnitPreference.kilometers.displayName)
                    .tag(DistanceUnitPreference.kilometers)
                Text(DistanceUnitPreference.miles.displayName)
                    .tag(DistanceUnitPreference.miles)
            }
        } label: {
            Text("Distance Units")
        }
        .pickerStyle(.inline)
    }

}

extension CoreBuilder {
    
    func unitsView(router: AnyRouter, delegate: UnitsDelegate) -> some View {
        UnitsView(
            presenter: UnitsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showUnitsView(delegate: UnitsDelegate) {
        router.showScreen(.push) { router in
            builder.unitsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = UnitsDelegate()
    
    return RouterView { router in
        builder.unitsView(router: router, delegate: delegate)
    }
    
}
