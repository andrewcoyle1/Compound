//
//  MesocycleLibraryView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 18/10/2025.
//

import SwiftUI

struct MesocycleLibraryView<MesocycleDisclosure: View, InactiveSection: View>: View {

    @State var presenter: MesocycleLibraryPresenter

    @ViewBuilder var mesocycleDisclosueGroup: (MesocycleDisclosureGroupDelegate) -> MesocycleDisclosure
    @ViewBuilder var inactiveMesocycleSection: (InactiveMesocycleDelegate) -> InactiveSection
    
    var body: some View {
        List {
            if let activeMesocycle = presenter.activeMesocycle {
                activeMesocycleSection(activeMesocycle: activeMesocycle)
            }
            if !presenter.nonActiveMesocycles.isEmpty {
                savedMesocyclesSection
            }
            if presenter.savedMesocycles.isEmpty && presenter.activeMesocycle == nil {
                emptyState
            }
            if !presenter.prebuiltMesocycles.isEmpty {
                templatesSection
            }
        }
        .navigationTitle("Programs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }
    
    private func activeMesocycleSection(activeMesocycle: Mesocycle) -> some View {
        Section {
            mesocycleDisclosueGroup(MesocycleDisclosureGroupDelegate(mesocycle: activeMesocycle))
        } header: {
            Text("Active Training Program")
        }
    }

    private var savedMesocyclesSection: some View {
        Section {
            inactiveMesocycleSection(
                InactiveMesocycleDelegate(
                    inactiveMesocycles: presenter.nonActiveMesocycles,
                    onDelete: { presenter.showDeleteAlert(mesocycle: $0) }
                )
            )
        } header: {
            Text("Saved Programs")
        } footer: {
            Text("These are saved program designs. Start a program from a template to generate a scheduled plan.")
        }
    }
    
    private var templatesSection: some View {
        Section {
            ForEach(presenter.prebuiltMesocycles) { mesocycle in
                HStack {
                    MesocycleHeader(mesocycle: mesocycle)
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.rowDetail.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .anyButton {
                    presenter.onPrebuiltMesocyclePressed(mesocycle)
                }
            }
        } header: {
            Text("Templates")
        } footer: {
            Text("Starting a template saves your own copy and makes it your active program.")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Programs", systemImage: Symbol.mesocycle)
        } description: {
            Text("Create your first training program to get started.")
        } actions: {
            Button {
                presenter.onCreateMesocyclePressed()
            } label: {
                Text("Create Program")
                    .foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("New Program", systemImage: Symbol.mesocycle) {
                    presenter.onCreateMesocyclePressed()
                }
                Button("New Plan", systemImage: Symbol.calendar) {
                    presenter.onCreateMacrocyclePressed()
                }
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Create program or plan")
        }
    }
}

extension CoreBuilder {
    func mesocycleLibraryView(router: AnyRouter) -> some View {
        MesocycleLibraryView(
            presenter: MesocycleLibraryPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            mesocycleDisclosueGroup: { delegate in
                self.mesocycleDisclosureGroupView(router: router, delegate: delegate)
            },
            inactiveMesocycleSection: { delegate in
                self.inactiveMesocycleView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    /// Browsing, so a push on the Training tab's stack; the system Back button closes it.
    func showMesocycleLibraryView() {
        router.showScreen(.push) { router in
            builder.mesocycleLibraryView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.mesocycleLibraryView(router: router)
    }
    
}
