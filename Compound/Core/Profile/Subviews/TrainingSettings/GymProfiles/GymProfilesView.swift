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
                    Label("No Gym Profiles", systemImage: Symbol.equipment)
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
            gymProfileRow(gymProfile)
            .rowActions(allowsFullSwipe: false) {
                Button(role: .destructive) {
                    presenter.onDeleteGymProfilePressed(profile: gymProfile)
                } label: {
                    Label("Delete", systemImage: Symbol.delete)
                }
            }
        } header: {
            Text("Favorite Gym Profile")
        }
    }

    private var otherGymProfilesSection: some View {
        Section {
            ForEach(presenter.nonFavouriteGymProfiles) { profile in
                gymProfileRow(profile)
                // One set of actions, so the swipe and the context menu offer the same two.
                .rowActions(allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        presenter.onDeleteGymProfilePressed(profile: profile)
                    } label: {
                        Label("Delete", systemImage: Symbol.delete)
                    }
                    Button {
                        presenter.favouriteGymProfile(profile: profile)
                    } label: {
                        Label("Favorite", systemImage: "star")
                    }
                    .tint(.accentColor)
                }
            }
        } header: {
            Text("\(presenter.nonFavouriteGymProfiles.count) gyms")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onAddGymProfilePressed()
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Add gym profile")
        }
    }

    private func gymProfileRow(_ profile: GymProfileModel) -> some View {
        Button {
            presenter.onGymProfilePressed(gymProfile: profile)
        } label: {
            ListRow(title: profile.name, subtitle: equipmentSubtitle(for: profile), imageName: profile.imageUrl, accessory: .chevron)
                .contentShape(.rect)
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
