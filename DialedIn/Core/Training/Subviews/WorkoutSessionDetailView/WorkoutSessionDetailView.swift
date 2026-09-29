//
//  WorkoutSessionDetailView.swift
//  DialedIn
//
//  Created by Andrew Coyle
//

import SwiftUI

struct WorkoutSessionDetailDelegate {
    let initialSession: WorkoutSessionModel

    init(workoutSession: WorkoutSessionModel) {
        self.initialSession = workoutSession
    }
}

struct WorkoutSessionDetailView<AuthorHeader: View>: View {

    @State var presenter: WorkoutSessionDetailPresenter
    @State private var session: WorkoutSessionModel

    let delegate: WorkoutSessionDetailDelegate

    @ViewBuilder var authorHeader: (AuthorHeaderDelegate) -> AuthorHeader

    init(
        presenter: WorkoutSessionDetailPresenter,
        delegate: WorkoutSessionDetailDelegate,
        authorHeader: @escaping (AuthorHeaderDelegate) -> AuthorHeader,
    ) {
        self._presenter = State(initialValue: presenter)
        self._session = State(initialValue: delegate.initialSession)
        self.delegate = delegate
        self.authorHeader = authorHeader
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
        .interactiveDismissDisabled(presenter.hasUnsavedChanges(session: delegate.initialSession, editedSession: session))
        .onAppear {
            presenter.loadUnitPreferences(for: session)
        }
        .task {
            await presenter.loadAuthor(for: session)
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
                if let duration = session.endedAt?.timeIntervalSince(session.dateCreated) {
                    ListRowButton(
                        title: String(localized: "Duration"),
                        subtitle: Format.duration(duration),
                        systemImage: Symbol.duration
                    ) {
                        presenter.onEditDurationPressed(session: $session)
                    }
                }
                ListRowButton(
                    title: String(localized: "Edit Workout"),
                    subtitle: String(localized: "Go to the workout editor"),
                    systemImage: Symbol.edit
                ) {
                    presenter.enterEditMode(session: session)
                }
            } else {
                ListRow(
                    title: String(localized: "Start Time"),
                    subtitle: session.dateCreated.formatted(date: .long, time: .shortened),
                    systemImage: Symbol.calendar
                )
                if let duration = session.endedAt?.timeIntervalSince(session.dateCreated) {
                    ListRow(title: String(localized: "Duration"), subtitle: Format.duration(duration), systemImage: Symbol.duration)
                }
            }

            notesEditor()
        } header: {
            Text("Workout Details")
        }
    }

    private var exerciseDetailsSection: some View {
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
                        imageName: exercise.imageName ?? Constants.randomImage
                    )
                }
            }
        } header: {
            Text("Exercise Details")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onClosePressed(initialSession: delegate.initialSession, session: session)
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

        if presenter.isAuthor(sessionAuthorId: session.authorId) {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if presenter.isEditMode {
                        Button(role: .confirm) {
                            Task { await presenter.saveChanges(initialSession: delegate.initialSession, session: $session) }
                        }
                        .disabled(presenter.isLoading || !presenter.hasUnsavedChanges(session: delegate.initialSession, editedSession: session))
                        .fontWeight(.semibold)
                    } else {
                        Button {
                            presenter.enterEditMode(session: session)
                        } label: {
                            Label("Edit", systemImage: Symbol.edit)
                        }
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
            presenter: WorkoutSessionDetailPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate,
            authorHeader: { delegate in
                self.authorHeaderView(router: router, delegate: delegate)
            }
        )
    }
}

extension CoreRouter {
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) {
        router.showScreen(.sheet) { router in
            builder.workoutSessionDetailView(router: router, delegate: delegate)
        }
    }

    /// The session with its comments already open on top, for a comment or mention notification.
    /// One `showScreens` call so the comments sheet is presented from the detail sheet's router,
    /// not from the screen that asked.
    func showWorkoutSessionThread(delegate: WorkoutSessionDetailDelegate) {
        router.showScreens(destinations: [
            AnyDestination(segue: .sheet) { router in
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
