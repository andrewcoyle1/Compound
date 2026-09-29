import SwiftUI

struct ProgramSettingsView: View {
    
    @State var presenter: ProgramSettingsPresenter
    @Binding var program: TrainingProgram
    
    var body: some View {
        List {
            Section {
                editProgramName
                editCycleCount
                editColourAndIcon
                editDayOrder
                editDeload
                editPeriodisation
            }
            .listSectionMargins(.top, 0)
        }
        .navigationTitle("Program Settings")
        .navigationSubtitle(program.name)
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
                presenter.onActivatePressed(program: program)
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

    private var editProgramName: some View {
        editRow(title: String(localized: "Name"), subtitle: program.name, systemImage: Symbol.program) {
            presenter.onEditNamePressed(program: $program)
        }
    }

    private var editCycleCount: some View {
        Stepper(value: $program.numMicrocycles, in: 1...16) {
            ListRow(
                title: String(localized: "Number of Cycles"),
                subtitle: String(AttributedString(localized: "^[\(program.numMicrocycles) cycle](inflect: true)").characters),
                systemImage: "arrow.trianglehead.2.clockwise"
            )
        }
    }

    private var editColourAndIcon: some View {
        editRow(
            // The row's own glyph shows both; the hex string and symbol name were no help as text.
            title: String(localized: "Color & Icon"),
            subtitle: nil,
            systemImage: program.icon,
            tint: Color(hex: program.colour)
        ) {
            presenter.onEditColourIconPressed(program: $program)
        }
    }

    private var editDayOrder: some View {
        editRow(title: String(localized: "Day Order"), subtitle: presenter.dayOrderSubtitle(program: program), systemImage: Symbol.calendar) {
            presenter.onEditDayOrderPressed(program: $program)
        }
    }

    private var editDeload: some View {
        editRow(title: String(localized: "Deload"), subtitle: program.deload.title.capitalized, systemImage: "cloud.fill") {
            presenter.onEditDeloadPressed(program: $program)
        }
    }

    private var editPeriodisation: some View {
        ListRowToggle(
            title: String(localized: "Periodization"),
            subtitle: String(localized: "Organize your training into phases that vary intensity and volume to support continuous progress and effective recovery."),
            systemImage: "water.waves",
            isOn: $program.periodisation
        )
    }
}

extension CoreBuilder {
    
    func programSettingsView(router: AnyRouter, program: Binding<TrainingProgram>) -> some View {
        ProgramSettingsView(
            presenter: ProgramSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            program: program
        )
    }
    
}

extension CoreRouter {
    
    /// A page of the program editor, so it pushes inside the editor's own stack rather than
    /// stacking a second sheet on it.
    func showProgramSettingsView(program: Binding<TrainingProgram>) {
        router.showScreen(.push) { router in
            builder.programSettingsView(router: router, program: program)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let program = Binding.constant(
        TrainingProgram(authorId: "user123", name: "Preview Program", icon: "pencil", colour: Color.blue.asHex())
    )
    
    return RouterView { router in
        builder.programSettingsView(router: router, program: program)
    }
    
}
