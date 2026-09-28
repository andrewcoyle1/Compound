import SwiftUI

struct ProgramDesignDelegate {
    let onComplete: (@Sendable () -> Void)?
    var id: String
    var authorId: String
    var name: String
    var colour: Color
    var icon: String
    
    init(
        onComplete: (@Sendable () -> Void)? = nil,
        id: String,
        authorId: String,
        name: String,
        colour: Color,
        icon: String
    ) {
        self.onComplete = onComplete
        self.id = id
        self.authorId = authorId
        self.name = name
        self.colour = colour
        self.icon = icon
    }
}

struct EditTrainingProgramDelegate {
    var program: TrainingProgram
}

struct ProgramDesignView<DefineWorkout: View>: View {
    
    @State var presenter: ProgramDesignPresenter
    let delegate: ProgramDesignDelegate
    
    @ViewBuilder var workoutDefinitionView: (DefineWorkoutDelegate) -> DefineWorkout
    
    init(presenter: ProgramDesignPresenter, delegate: ProgramDesignDelegate, workoutDefinitionView: @escaping (DefineWorkoutDelegate) -> DefineWorkout) {
        self.presenter = presenter
        self.delegate = delegate
        self.workoutDefinitionView = workoutDefinitionView
    }
    
    init(presenter: ProgramDesignPresenter, delegate: EditTrainingProgramDelegate, workoutDefinitionView: @escaping (DefineWorkoutDelegate) -> DefineWorkout) {
        self.presenter = presenter
        self.delegate = ProgramDesignDelegate(id: delegate.program.id, authorId: delegate.program.authorId, name: delegate.program.name, colour: Color(hex: delegate.program.colour), icon: delegate.program.icon)
        self.workoutDefinitionView = workoutDefinitionView
    }
    
    var body: some View {
        workoutDefinitionSection(dayPlan: presenter.selectedWorkoutTemplateModel)
            .navigationTitle("Create Program")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .onAppear {
                presenter.onViewAppear()
            }
            .onDisappear {
                presenter.onViewDisappear()
            }
            .toolbar {
                toolbarContent
            }
            .safeAreaInset(edge: .top) {
                topSafeAreaSection
            }
            .bottomCTA {
                bottomActions
            }
    }
    
    private func workoutDefinitionSection(dayPlan: WorkoutTemplateModel) -> some View {
        
        let gymProfile = presenter.favouriteGymProfile ?? GymProfileModel(
            authorId: presenter.userId,
            freeWeights: [],
            loadableBars: [],
            fixedWeightBars: [],
            bands: [],
            bodyWeights: [],
            supportEquipment: [],
            accessoryEquipment: [],
            loadableAccessoryEquipment: [],
            cableMachines: [],
            plateLoadedMachines: [],
            pinLoadedMachines: []
        )
        let delegate = DefineWorkoutDelegate(
            name: dayPlan.name,
            gymProfile: gymProfile,
            exercises: presenter.selectedWorkoutTemplateModelExercises,
            topSectionStyle: .programDay
        )
        return workoutDefinitionView(delegate)
            .navigationTitle(dayPlan.name)
            // Ensure switching selected day plan rebuilds DefineWorkoutView state.
            .id(dayPlan.id)
    }
    
    private var daySelectionSection: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(presenter.dayPlans) { dayPlan in
                    dayPlanCell(dayPlan)
                }
                Button {
                    presenter.onAddDayPressed()
                } label: {
                    Label("Add Day", systemImage: Symbol.add)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }
    
    private func dayPlanCell(_ dayPlan: WorkoutTemplateModel) -> some View {
        Group {
            if presenter.selectedWorkoutTemplateModel.id == dayPlan.id {
                Button {
                    presenter.onWorkoutTemplateModelSelected(dayPlan)
                } label: {
                    Text(dayPlan.name)
                        .foregroundStyle(.onAccent)
                        .fontWeight(.bold)
                }
                .buttonStyle(.glassProminent)
                .accessibilityAddTraits(.isSelected)
            } else {
                Button {
                    presenter.onWorkoutTemplateModelSelected(dayPlan)
                } label: {
                    Text(dayPlan.name)
                        .fontWeight(.regular)
                }
                .buttonStyle(.glass)
            }
        }
    }
    
    private var topSafeAreaSection: some View {
        VStack {
            daySelectionSection
            dayOptionBar
        }
    }
    
    @ViewBuilder
    private var bottomActions: some View {
        if !presenter.isProgramActive {
            CallToActionButton {
                presenter.onActivatePressed(delegate: delegate)
            } label: {
                Text("Activate Program")
            }
            .accessibilityIdentifier("ProgramDesign.activate")
            .disabled(!presenter.canSave)
        }

        if delegate.onComplete == nil {
            CallToActionButton(isPrimaryAction: false) {
                presenter.onSavePressed(delegate: delegate)
            } label: {
                Text("Save Program")
            }
            .accessibilityIdentifier("ProgramDesign.save")
            .disabled(!presenter.canSave)
        }
    }
    
    private var dayOptionBar: some View {
        Section {
            ScrollView(.horizontal) {
                HStack {
                    Button {
                        presenter.onRemoveWorkoutTemplateModelPressed()
                    } label: {
                        Label("Remove", systemImage: Symbol.delete)
                    }
                    .buttonStyle(.glass)
                    .disabled(!presenter.canRemoveWorkoutTemplateModel)
                        .padding(.leading)
                    
                    Button {
                        presenter.onRenameWorkoutTemplateModelPressed()
                    } label: {
                        Label("Rename", systemImage: Symbol.edit)
                    }
                    .buttonStyle(.glass)
                    .padding(.trailing)
                }
            }
            .scrollIndicators(.hidden)
            .removeListRowFormatting()
        }
        .listSectionMargins(.vertical, 0)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDismissPressed(delegate: delegate)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Back")
            .accessibilityIdentifier("ProgramDesign.back")
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onProgramSettingsPressed(program: $presenter.program)
            } label: {
                Image(systemName: Symbol.settings)
            }
            .accessibilityLabel("Program settings")
        }
    }
}

extension CoreBuilder {
    
    func programDesignView(router: AnyRouter, delegate: ProgramDesignDelegate) -> some View {
        let program = TrainingProgram(
            id: delegate.id,
            authorId: delegate.authorId,
            name: delegate.name,
            icon: delegate.icon,
            colour: delegate.colour.asHex()
        )
        return ProgramDesignView(
            presenter: ProgramDesignPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                program: program
            ),
            delegate: delegate,
            workoutDefinitionView: { delegate in
                self.defineWorkoutView(router: router, delegate: delegate)
            }
        )
    }

    func editTrainingProgramView(router: AnyRouter, delegate: EditTrainingProgramDelegate) -> some View {
        ProgramDesignView(
            presenter: ProgramDesignPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                ),
                program: delegate.program
            ),
            delegate: delegate,
            workoutDefinitionView: { delegate in
                self.defineWorkoutView(router: router, delegate: delegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showProgramDesignView(delegate: ProgramDesignDelegate) {
        router.showScreen(.push) { router in
            builder.programDesignView(router: router, delegate: delegate)
        }
    }
    
    func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate) {
        router.showScreen(.sheet) { router in
            builder.editTrainingProgramView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ProgramDesignDelegate(
        id: UUID().uuidString,
        authorId: "user123",
        name: "Preview Program",
        colour: .blue,
        icon: "pencil"
    )
    
    return RouterView { router in
        builder.programDesignView(router: router, delegate: delegate)
    }
    
}
