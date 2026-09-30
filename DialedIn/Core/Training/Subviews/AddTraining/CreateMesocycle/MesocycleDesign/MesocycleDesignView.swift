import SwiftUI

struct MesocycleDesignDelegate {
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

struct EditMesocycleDelegate {
    var mesocycle: Mesocycle
}

struct MesocycleDesignView<DefineWorkout: View>: View {
    
    @State var presenter: MesocycleDesignPresenter
    let delegate: MesocycleDesignDelegate
    /// Opened as a sheet on a saved mesocycle, rather than pushed as the create flow's last step.
    private let isEditing: Bool
    
    @ViewBuilder var workoutDefinitionView: (DefineWorkoutDelegate) -> DefineWorkout
    
    init(presenter: MesocycleDesignPresenter, delegate: MesocycleDesignDelegate, workoutDefinitionView: @escaping (DefineWorkoutDelegate) -> DefineWorkout) {
        self.presenter = presenter
        self.delegate = delegate
        self.isEditing = false
        self.workoutDefinitionView = workoutDefinitionView
    }
    
    init(presenter: MesocycleDesignPresenter, delegate: EditMesocycleDelegate, workoutDefinitionView: @escaping (DefineWorkoutDelegate) -> DefineWorkout) {
        self.presenter = presenter
        self.delegate = MesocycleDesignDelegate(id: delegate.mesocycle.id, authorId: delegate.mesocycle.authorId, name: delegate.mesocycle.name, colour: Color(hex: delegate.mesocycle.colour), icon: delegate.mesocycle.icon)
        self.isEditing = true
        self.workoutDefinitionView = workoutDefinitionView
    }
    
    var body: some View {
        workoutDefinitionSection(dayPlan: presenter.selectedWorkoutTemplateModel)
            .navigationTitle(isEditing ? String(localized: "Edit Mesocycle") : String(localized: "Create Mesocycle"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(presenter.hasUnsavedChanges)
            .onAppear {
                presenter.onViewAppear()
            }
            .onDisappear {
                presenter.onViewDisappear()
            }
            .toolbar {
                toolbarContent
            }
            .safeAreaBar(edge: .top) {
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
            topSectionStyle: .mesocycleDay
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
                .buttonStyle(.bordered)
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
                .buttonStyle(.borderedProminent)
                .accessibilityAddTraits(.isSelected)
            } else {
                Button {
                    presenter.onWorkoutTemplateModelSelected(dayPlan)
                } label: {
                    Text(dayPlan.name)
                        .fontWeight(.regular)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var topSafeAreaSection: some View {
        VStack {
            daySelectionSection
            dayOptionBar
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var bottomActions: some View {
        if !presenter.isMesocycleActive {
            CallToActionButton(isLoading: presenter.isSaving) {
                presenter.onActivatePressed(delegate: delegate)
            } label: {
                Text("Activate Mesocycle")
            }
            .accessibilityIdentifier("ProgramDesign.activate")
            .disabled(!presenter.canSave)
        }

        if delegate.onComplete == nil {
            CallToActionButton(isPrimaryAction: false, isLoading: presenter.isSaving) {
                presenter.onSavePressed(delegate: delegate)
            } label: {
                Text("Save Mesocycle")
            }
            .accessibilityIdentifier("ProgramDesign.save")
            .disabled(!presenter.canSave)
        }
    }
    
    private var dayOptionBar: some View {
        Section {
            ScrollView(.horizontal) {
                HStack {
                    Button(role: .destructive) {
                        presenter.onRemoveWorkoutTemplateModelPressed()
                    } label: {
                        Label("Remove", systemImage: Symbol.delete)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!presenter.canRemoveWorkoutTemplateModel)
                        .padding(.leading)
                    
                    Button {
                        presenter.onRenameWorkoutTemplateModelPressed()
                    } label: {
                        Label("Rename", systemImage: Symbol.edit)
                    }
                    .buttonStyle(.bordered)
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
        // The create flow keeps the system back button, and its swipe, to step back to the icon.
        if isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
                .accessibilityIdentifier("ProgramDesign.close")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.onMesocycleSettingsPressed(mesocycle: $presenter.mesocycle)
            } label: {
                Image(systemName: Symbol.settings)
            }
            .accessibilityLabel("Mesocycle settings")
        }

        // A saved mesocycle's share and delete, as workout templates have them.
        if isEditing {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Share with Friends", systemImage: Symbol.share) {
                        presenter.onSharePressed()
                    }
                    Button("Delete Mesocycle", systemImage: Symbol.delete, role: .destructive) {
                        presenter.onDeletePressed()
                    }
                } label: {
                    Label("More", systemImage: Symbol.more)
                }
            }
        }
    }
}

extension CoreBuilder {
    
    func mesocycleDesignView(router: AnyRouter, delegate: MesocycleDesignDelegate) -> some View {
        let mesocycle = Mesocycle(
            id: delegate.id,
            authorId: delegate.authorId,
            name: delegate.name,
            icon: delegate.icon,
            colour: delegate.colour.asHex()
        )
        return MesocycleDesignView(
            presenter: MesocycleDesignPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                mesocycle: mesocycle
            ),
            delegate: delegate,
            workoutDefinitionView: { delegate in
                self.defineWorkoutView(router: router, delegate: delegate)
            }
        )
    }

    func editMesocycleView(router: AnyRouter, delegate: EditMesocycleDelegate) -> some View {
        MesocycleDesignView(
            presenter: MesocycleDesignPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                ),
                mesocycle: delegate.mesocycle
            ),
            delegate: delegate,
            workoutDefinitionView: { delegate in
                self.defineWorkoutView(router: router, delegate: delegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showMesocycleDesignView(delegate: MesocycleDesignDelegate) {
        router.showScreen(.push) { router in
            builder.mesocycleDesignView(router: router, delegate: delegate)
        }
    }
    
    func showEditMesocycleView(delegate: EditMesocycleDelegate) {
        router.showScreen(.sheet) { router in
            builder.editMesocycleView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = MesocycleDesignDelegate(
        id: UUID().uuidString,
        authorId: "user123",
        name: "Preview Mesocycle",
        colour: .blue,
        icon: "pencil"
    )
    
    return RouterView { router in
        builder.mesocycleDesignView(router: router, delegate: delegate)
    }
    
}
