//
//  WorkoutSessionDetailView.swift
//  Compound
//
//  Created by Andrew Coyle
//

import SwiftUI

struct WorkoutSessionDetailDelegate {
    let initialSession: WorkoutSessionModel
    /// Pushed inside the tracker's cover once the workout is finished. There is nothing to go
    /// Back to, so Back is hidden and Done closes the cover.
    let isWorkoutSummary: Bool

    init(workoutSession: WorkoutSessionModel, isWorkoutSummary: Bool = false) {
        self.initialSession = workoutSession
        self.isWorkoutSummary = isWorkoutSummary
    }
}

struct WorkoutSessionDetailView<AuthorHeader: View, ExerciseEditor: View>: View {

    @State var presenter: WorkoutSessionDetailPresenter
    @State private var session: WorkoutSessionModel
    /// Every exercise opens expanded for editing; these are the ones the user folded away.
    @State private var collapsedExerciseIds: Set<String> = []

    let delegate: WorkoutSessionDetailDelegate

    @ViewBuilder var authorHeader: (AuthorHeaderDelegate) -> AuthorHeader
    /// The workout tracker's exercise rows, shown while editing.
    @ViewBuilder var exerciseEditor: (ExerciseTrackerDelegate) -> ExerciseEditor

    init(
        presenter: WorkoutSessionDetailPresenter,
        delegate: WorkoutSessionDetailDelegate,
        authorHeader: @escaping (AuthorHeaderDelegate) -> AuthorHeader,
        exerciseEditor: @escaping (ExerciseTrackerDelegate) -> ExerciseEditor
    ) {
        self._presenter = State(initialValue: presenter)
        self._session = State(initialValue: delegate.initialSession)
        self.delegate = delegate
        self.authorHeader = authorHeader
        self.exerciseEditor = exerciseEditor
    }
    
    var body: some View {
        List {
            authorHeaderSection
            workoutDetailsSection
            exerciseDetailsSection
        }
        .navigationTitle(session.name)
        .navigationSubtitle(session.dateCreated.formatted(date: .long, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .toolbar {
            toolbarContent
        }
        // Back cannot be intercepted, so while editing it is hidden and the close button ends the
        // edit, asking first when anything changed.
        .navigationBarBackButtonHidden(delegate.isWorkoutSummary || presenter.isEditMode)
        .task {
            await presenter.loadAuthor(for: session)
        }
        .onChange(of: presenter.selectedExerciseModels) { _, newValue in
            guard !newValue.isEmpty else { return }
            presenter.addSelectedExercises(session: $session)
        }
    }

    @ViewBuilder
    private var authorHeaderSection: some View {
        if let author = presenter.author {
            Section {
                authorHeader(AuthorHeaderDelegate(author: author, date: session.dateCreated))
            }
            .listSectionMargins(.top, 0)
        }
    }
    
    private var workoutDetailsSection: some View {
        Section {
            ListRow(
                title: String(localized: "Volume"),
                systemImage: Symbol.volume,
                accessory: .value(presenter.volumeFormatted(session: session))
            )
            if presenter.isAuthor(sessionAuthorId: session.authorId) {
                ListRowButton(
                    title: String(localized: "Start Time"),
                    subtitle: session.dateCreated.formatted(date: .long, time: .shortened),
                    systemImage: Symbol.calendar
                ) {
                    presenter.onEditStartTimePressed(session: $session)
                }
                if let duration = session.activeDuration {
                    ListRowButton(
                        title: String(localized: "Duration"),
                        subtitle: Format.duration(duration),
                        systemImage: Symbol.duration
                    ) {
                        presenter.onEditDurationPressed(session: $session)
                    }
                }
                // Edits in place rather than opening a screen: no chevron.
                if !presenter.isEditMode {
                    ListRowButton(title: String(localized: "Edit Workout"), systemImage: Symbol.edit, accessory: .none) {
                        presenter.enterEditMode(session: session)
                    }
                    .accessibilityIdentifier("SessionDetail.edit")
                }
            } else {
                ListRow(
                    title: String(localized: "Start Time"),
                    subtitle: session.dateCreated.formatted(date: .long, time: .shortened),
                    systemImage: Symbol.calendar
                )
                if let duration = session.activeDuration {
                    ListRow(title: String(localized: "Duration"), subtitle: Format.duration(duration), systemImage: Symbol.duration)
                }
            }

            notesEditor()
        } header: {
            Text("Workout Details")
        }
    }

    @ViewBuilder
    private var exerciseDetailsSection: some View {
        if presenter.isEditMode {
            exerciseEditorSection
        } else {
            exerciseReadSection
        }
    }

    private var exerciseEditorSection: some View {
        Section {
            ForEach($session.exercises) { $exercise in
                let exerciseId = exercise.id
                exerciseEditor(
                    ExerciseTrackerDelegate(
                        exercise: $exercise,
                        lastExercise: nil,
                        isExpanded: Binding(
                            get: { !collapsedExerciseIds.contains(exerciseId) },
                            set: { isExpanded in
                                if isExpanded {
                                    collapsedExerciseIds.remove(exerciseId)
                                } else {
                                    collapsedExerciseIds.insert(exerciseId)
                                }
                            }
                        ),
                        allWorkoutExercises: session.exercises,
                        onSetSupersetGroup: { exerciseId, groupId in
                            presenter.setSupersetGroupId(session: $session, groupId, forExerciseId: exerciseId)
                        },
                        onDeleteExercise: {
                            presenter.deleteExercise(session: $session, id: exerciseId)
                        },
                        onUpdateNote: { note in
                            presenter.updateExerciseNotes(session: $session, note, exerciseId: exerciseId)
                        }
                    )
                )
            }
        } header: {
            HStack {
                Text("Exercise Details")
                Spacer()
                Button {
                    presenter.onAddExercisePressed()
                } label: {
                    Image(systemName: Symbol.add)
                }
                .accessibilityLabel("Add exercise")
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
    }

    private var exerciseReadSection: some View {
        Section {
            ForEach(session.exercises) { exercise in
                DisclosureGroup {
                    if let note = exercise.notes {
                        Label(note, systemImage: Symbol.note)
                            .font(.rowDetail)
                    }
                    ForEach(exercise.workingSets, id: \.id) { set in
                        SetDetailRow(
                            set: set,
                            index: exercise.workingSetNumber(for: set),
                            trackingMode: exercise.trackingMode,
                            weightUnit: presenter.weightUnit(for: exercise.templateId),
                            distanceUnit: presenter.distanceUnit(for: exercise.templateId)
                        )
                    }
                } label: {
                    ListRow(
                        title: exercise.name,
                        subtitle: presenter.exerciseSummary(exercise),
                        imageName: exercise.imageName,
                        initialsWhenMissing: true
                    )
                }
            }
        } header: {
            Text("Exercise Details")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        
        if presenter.isEditMode {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onEndEditingPressed(initialSession: delegate.initialSession, session: $session)
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(WorkoutShareCardView.Format.allCases, id: \.self) { format in
                    Button(format.title) {
                        presenter.onShareImagePressed(session: session, format: format)
                    }
                }
                if let link = presenter.webLink(session: session) {
                    // No icon, like the formats above it: a menu group has icons on all or none.
                    Button("Copy Link") {
                        presenter.onCopyLinkPressed(link, session: session)
                    }
                }
            } label: {
                Label("Share Image", systemImage: Symbol.share)
            }
        }

        if presenter.isEditMode {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    Task { await presenter.saveChanges(initialSession: delegate.initialSession, session: $session) }
                }
                .accessibilityIdentifier("SessionDetail.save")
                .disabled(presenter.isLoading || !presenter.hasUnsavedChanges(session: delegate.initialSession, editedSession: session))
            }
        } else if delegate.isWorkoutSummary {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    presenter.onDonePressed()
                }
            }
        }

        if !presenter.isEditMode, presenter.isAuthor(sessionAuthorId: session.authorId) {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        presenter.enterEditMode(session: session)
                    } label: {
                        Label("Edit Workout", systemImage: Symbol.edit)
                    }

                    Button(role: .destructive) {
                        presenter.onDeletePressed(session: session)
                    } label: {
                        Label("Delete", systemImage: Symbol.delete)
                    }
                } label: {
                    Label("More", systemImage: Symbol.more)
                }
            }
        }
    }
    
    @ViewBuilder
    private func notesEditor() -> some View {
        if presenter.isEditMode {
            TextField(
                "Workout notes",
                text: Binding(
                    get: { session.notes ?? "" },
                    set: { newValue in session.notes = newValue.isEmpty ? nil : newValue }
                ),
                prompt: Text("Add notes here..."),
                axis: .vertical
            )
            .lineLimit(3...)
            .textInputAutocapitalization(.sentences)
        } else if let notes = session.notes, !notes.isEmpty {
            Label(notes, systemImage: Symbol.note)
                .font(.rowTitle)
        }
    }
}

extension CoreBuilder {
    func workoutSessionDetailView(router: AnyRouter, delegate: WorkoutSessionDetailDelegate) -> some View {
        WorkoutSessionDetailView(
            presenter: WorkoutSessionDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                isWorkoutSummary: delegate.isWorkoutSummary
            ),
            delegate: delegate,
            authorHeader: { delegate in
                self.authorHeaderView(router: router, delegate: delegate)
            },
            exerciseEditor: { delegate in
                self.exerciseTrackerView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) {
        router.showScreen(.push) { router in
            builder.workoutSessionDetailView(router: router, delegate: delegate)
        }
    }

    /// The session with its comments already open on top, for a comment or mention notification.
    /// One `showScreens` call so the comments sheet is presented from the pushed detail's router,
    /// not from the screen that asked.
    func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) {
        router.showScreens(destinations: [
            AnyDestination(segue: .push) { router in
                builder.workoutSessionDetailView(router: router, delegate: delegate)
            },
            AnyDestination(segue: .sheet) { router in
                builder.commentsView(router: router, delegate: CommentsDelegate(session: delegate.initialSession))
            }
        ])
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = WorkoutSessionDetailDelegate(workoutSession: .mock)
    RouterView { router in
        builder.workoutSessionDetailView(router: router, delegate: delegate)
    }
    
}
