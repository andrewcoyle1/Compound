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
        .toolbar {
            toolbarContent
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onActivatePressed(program: program)
            } label: {
                Text("Activate Program")
            }
        }
    }

    private func editRow(title: String, subtitle: String, systemImage: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        ListRow(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            accessory: .custom(AnyView(RowChipButton(subject: title, action: action)))
        )
    }

    private var editProgramName: some View {
        editRow(title: String(localized: "Name"), subtitle: program.name, systemImage: Symbol.program) {
            presenter.onEditNamePressed(program: $program)
        }
    }

    private var editCycleCount: some View {
        Stepper(value: $program.numMicrocycles, in: 1...16) {
            ListRow(
                title: String(localized: "Number of cycles"),
                subtitle: String(AttributedString(localized: "^[\(program.numMicrocycles) cycle](inflect: true)").characters),
                systemImage: "arrow.trianglehead.2.clockwise"
            )
        }
    }

    private var editColourAndIcon: some View {
        editRow(
            title: String(localized: "Color & Icon"),
            subtitle: "\(program.colour.description.capitalized), \(program.icon.capitalized)",
            systemImage: program.icon,
            tint: Color(hex: program.colour)
        ) {
            presenter.onEditColourIconPressed(program: $program)
        }
    }

    private var editDayOrder: some View {
        editRow(title: String(localized: "Day Order"), subtitle: dayOrderSubtitle, systemImage: Symbol.calendar) {
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
            title: String(localized: "Periodisation"),
            subtitle: String(localized: "Organize your training into phases that vary intensity and volume to support continuous progress and effective recovery."),
            systemImage: "water.waves",
            isOn: $program.periodisation
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
    }

    private var dayOrderSubtitle: String {
        var subtitle = ""
        for plan in program.workoutTemplates {
            if plan.exercises.isEmpty {
                subtitle += "R "
            } else {
                subtitle += "W "
            }
        }
        return subtitle
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
    
    func showProgramSettingsView(program: Binding<TrainingProgram>) {
        router.showScreen(.sheetConfig(config: .full)) { router in
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
