import SwiftUI

struct MesocycleSettingsView: View {
    
    @State var presenter: MesocycleSettingsPresenter
    @Binding var mesocycle: Mesocycle
    
    var body: some View {
        List {
            Section {
                editMesocycleName
                editCycleCount
                editColourAndIcon
                editDayOrder
                editDeload
                editPeriodisation
            }
            .listSectionMargins(.top, 0)
        }
        .navigationTitle("Program Settings")
        .navigationSubtitle(mesocycle.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .bottomCTA {
            CallToActionButton(isLoading: presenter.isSaving) {
                presenter.onActivatePressed(mesocycle: mesocycle)
            } label: {
                Text("Activate Program")
            }
            .disabled(presenter.isSaving)
        }
    }

    /// The whole row opens the editor. Only a 20 pt "Edit" chip at its end used to.
    private func editRow(title: String, subtitle: String?, systemImage: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        ListRowButton(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint, action: action)
    }

    private var editMesocycleName: some View {
        editRow(title: String(localized: "Name"), subtitle: mesocycle.name, systemImage: Symbol.mesocycle) {
            presenter.onEditNamePressed(mesocycle: $mesocycle)
        }
    }

    private var editCycleCount: some View {
        Stepper(value: $mesocycle.numMicrocycles, in: 1...16) {
            ListRow(
                title: String(localized: "Number of Cycles"),
                subtitle: String(AttributedString(localized: "^[\(mesocycle.numMicrocycles) cycle](inflect: true)").characters),
                systemImage: "arrow.trianglehead.2.clockwise"
            )
        }
    }

    private var editColourAndIcon: some View {
        editRow(
            // The row's own glyph shows both; the hex string and symbol name were no help as text.
            title: String(localized: "Color & Icon"),
            subtitle: nil,
            systemImage: mesocycle.icon,
            tint: Color(hex: mesocycle.colour)
        ) {
            presenter.onEditColourIconPressed(mesocycle: $mesocycle)
        }
    }

    private var editDayOrder: some View {
        editRow(title: String(localized: "Day Order"), subtitle: presenter.dayOrderSubtitle(mesocycle: mesocycle), systemImage: Symbol.calendar) {
            presenter.onEditDayOrderPressed(mesocycle: $mesocycle)
        }
    }

    private var editDeload: some View {
        editRow(title: String(localized: "Deload"), subtitle: mesocycle.deload.title.capitalized, systemImage: "cloud.fill") {
            presenter.onEditDeloadPressed(mesocycle: $mesocycle)
        }
    }

    private var editPeriodisation: some View {
        ListRowToggle(
            title: String(localized: "Periodization"),
            subtitle: String(localized: "Organize your training into phases that vary intensity and volume to support continuous progress and effective recovery."),
            systemImage: "water.waves",
            isOn: $mesocycle.periodisation
        )
    }
}

extension CoreBuilder {
    
    func mesocycleSettingsView(router: AnyRouter, mesocycle: Binding<Mesocycle>) -> some View {
        MesocycleSettingsView(
            presenter: MesocycleSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            mesocycle: mesocycle
        )
    }
    
}

extension CoreRouter {
    
    /// A page of the mesocycle editor, so it pushes inside the editor's own stack rather than
    /// stacking a second sheet on it.
    func showMesocycleSettingsView(mesocycle: Binding<Mesocycle>) {
        router.showScreen(.push) { router in
            builder.mesocycleSettingsView(router: router, mesocycle: mesocycle)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let mesocycle = Binding.constant(
        Mesocycle(authorId: "user123", name: "Preview Program", icon: "pencil", colour: Color.blue.asHex())
    )
    
    return RouterView { router in
        builder.mesocycleSettingsView(router: router, mesocycle: mesocycle)
    }
    
}
