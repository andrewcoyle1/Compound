import SwiftUI

struct GymProfilesView: View {
    
    @State var presenter: GymProfilesPresenter
    
    var body: some View {
        List {
            if let favouriteGymProfile = presenter.favouriteGymProfile {
                favouriteGymProfileSection(gymProfile: favouriteGymProfile)
            }
            if !presenter.nonFavouriteGymProfiles.isEmpty {
                otherGymProfilesSection
            }
        }
        .overlay {
            if presenter.gymProfiles.isEmpty {
                ContentUnavailableView {
                    Label("No Gym Profiles", systemImage: "dumbbell")
                } description: {
                    Text("Add the gyms you train at and the equipment each one has.")
                } actions: {
                    Button("Add a Gym Profile") { presenter.onAddGymProfilePressed() }
                }
            }
        }
        .navigationTitle("Gym Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
        }
    }
    
    private func favouriteGymProfileSection(gymProfile: GymProfileModel) -> some View {
        Section {
            CustomListCellView(
                imageName: gymProfile.imageUrl,
                title: gymProfile.name,
                subtitle: equipmentSubtitle(for: gymProfile)
            )
            .anyButton {
                presenter.onGymProfilePressed(gymProfile: gymProfile)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    presenter.deleteGymProfile(profile: gymProfile)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .removeListRowFormatting()

        } header: {
            Text("Favourite Gym Profile")
        }
    }

    private var otherGymProfilesSection: some View {
        Section {
            ForEach(presenter.nonFavouriteGymProfiles) { profile in
                CustomListCellView(
                    imageName: profile.imageUrl,
                    title: profile.name,
                    subtitle: equipmentSubtitle(for: profile)
                )
                .anyButton {
                    presenter.onGymProfilePressed(gymProfile: profile)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        presenter.deleteGymProfile(profile: profile)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        presenter.favouriteGymProfile(profile: profile)
                    } label: {
                        Label("Favourite", systemImage: "star")
                    }
                    .tint(.accent)
                }
            }
            .removeListRowFormatting()

        } header: {
            Text(String.countCaption(count: presenter.nonFavouriteGymProfiles.count, unit: "Gym"))
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onAddGymProfilePressed()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add gym profile")
        }
    }

    private func equipmentSubtitle(for profile: GymProfileModel) -> String {
        let count = profile.activeEquipmentCount
        let pieceLabel = count == 1 ? String(localized: "piece") : String(localized: "pieces")
        return String(localized: "\(String(describing: count)) active \(pieceLabel) of equipment")
    }
}

extension CoreBuilder {
    
    func gymProfilesView(router: AnyRouter) -> some View {
        GymProfilesView(
            presenter: GymProfilesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
    
}

extension CoreRouter {
    
    func showGymProfilesView() {
        router.showScreen(.push) { router in
            builder.gymProfilesView(router: router)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    
    return RouterView { router in
        builder.gymProfilesView(router: router)
    }
    
}
