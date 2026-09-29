import SwiftUI

struct ChooseGymProfileDelegate {
    let name: String
    var workoutTemplate: WorkoutTemplateModel?
}

struct ChooseGymProfileView: View {
    
    @State var presenter: ChooseGymProfilePresenter
    let delegate: ChooseGymProfileDelegate
    
    var body: some View {
        List {
            if presenter.gymProfiles.isEmpty {
                // Every workout needs a gym, so an empty list was a dead end with no way to make one.
                ContentUnavailableView {
                    Label("No Gym Profiles", systemImage: "building.2")
                } description: {
                    Text("A workout is built around the equipment at a gym. Create one to continue.")
                } actions: {
                    Button("Create Gym Profile") {
                        presenter.onCreateGymProfilePressed()
                    }
                }
                .removeListRowFormatting()
            }
            Section {
                ForEach(presenter.gymProfiles) { profile in
                    CustomListCellView(
                        imageName: profile.imageUrl,
                        title: profile.name,
                        subtitle: equipmentSubtitle(for: profile)
                    )
                    .anyButton {
                        presenter.onGymProfilePressed(name: delegate.name, profile: profile, delegate: delegate)
                    }
                    .accessibilityIdentifier("ChooseGymProfile.profile")
                }
                .removeListRowFormatting()
            } header: {
                Text("This will be associated with the workout template.")
            }
        }
        .navigationTitle("Choose Gym Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    private func equipmentSubtitle(for profile: GymProfileModel) -> String {
        let count = profile.activeEquipmentCount
        let pieceLabel = count == 1 ? String(localized: "piece") : String(localized: "pieces")
        return String(localized: "\(String(describing: count)) active \(pieceLabel) of equipment")
    }

}

extension CoreBuilder {
    
    func chooseGymProfileView(router: AnyRouter, delegate: ChooseGymProfileDelegate) -> some View {
        ChooseGymProfileView(
            presenter: ChooseGymProfilePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showChooseGymProfileView(delegate: ChooseGymProfileDelegate) {
        router.showScreen(.push) { router in
            builder.chooseGymProfileView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ChooseGymProfileDelegate(name: "Preview Workout")
    
    return RouterView { router in
        builder.chooseGymProfileView(router: router, delegate: delegate)
    }
    
}
