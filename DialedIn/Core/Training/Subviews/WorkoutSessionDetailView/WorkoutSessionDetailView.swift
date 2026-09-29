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
        .sheet(isPresented: $presenter.isEditingStartTime) {
            startTimeSheet
        }
        .sheet(isPresented: $presenter.isEditingDuration) {
            durationSheet
        }
        .onAppear {
            presenter.loadUnitPreferences(for: session)
        }
        .task {
            await presenter.loadAuthor(for: session)
        }
    }

    private var startTimeSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Started at",
                    selection: Binding(
                        get: { session.dateCreated },
                        set: { presenter.onStartTimeChanged($0, session: $session) }
                    ),
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                Text("The workout keeps its duration; only when it started changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .navigationTitle("Start Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presenter.isEditingStartTime = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var durationSheet: some View {
        NavigationStack {
            HStack {
                Picker("Hours", selection: $presenter.durationHours) {
                    ForEach(0..<13, id: \.self) { hour in
                        Text("\(hour) hr").tag(hour)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Minutes", selection: $presenter.durationMinutes) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
            }
            .padding(.horizontal)
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presenter.isEditingDuration = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { presenter.onDurationConfirmed(session: $session) }
                }
            }
        }
        .presentationDetents([.medium])
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
            CustomLabelButtonView(symbolName: "scalemass", title: String(localized: "Volume")) {
                Text(presenter.volumeFormatted(session: session))
            }
            CustomLabelButtonView(
                symbolName: "arrow.right",
                title: String(localized: "Start Time"),
                subtitle: session.dateCreated.formatted(date: .long, time: .shortened)
            ) {
                Text("Edit")
                    .padding(.horizontal, 8)
                    .padding(8)
                    .background(Color.secondary.opacity(0.2), in: .capsule)
                    .anyButton(.press) {
                        presenter.onEditStartTimePressed()
                    }
            }
            if let duration = session.endedAt?.timeIntervalSince(session.dateCreated) {
                CustomLabelButtonView(
                    symbolName: "clock",
                    title: String(localized: "Duration"),
                    subtitle: Date.formatDuration(duration)
                ) {
                    Text("Edit")
                        .padding(.horizontal, 8)
                        .padding(8)
                        .background(Color.secondary.opacity(0.2), in: .capsule)
                        .anyButton(.press) {
                            presenter.onEditDurationPressed(session: session)
                        }
                }
            }

            CustomLabelButtonView(
                symbolName: "pencil",
                title: String(localized: "Edit Workout"),
                subtitle: "Go to the workout editor"
            ) {
                Text("Edit")
                    .padding(.horizontal, 8)
                    .padding(8)
                    .background(Color.secondary.opacity(0.2), in: .capsule)
                    .anyButton(.press) {
                        presenter.enterEditMode(session: session)
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
                        Label(note, systemImage: "note.text")
                            .font(.subheadline)
                    }
                    ForEach(exercise.workingSets, id: \.id) { set in
                        SetDetailRow(
                            set: set,
                            index: exercise.workingSetNumber(for: set),
                            trackingMode: exercise.trackingMode
                        )
                    }
                } label: {
                    let volume: Double = exercise.sets
                        .filter { !$0.isWarmup }
                        .compactMap { set -> Double? in
                            guard let weight = set.weightKg, let reps = set.reps else { return nil }
                            return weight * Double(reps)
                        }
                        .reduce(0.0, +)

                    return CustomListCellView(
                        imageName: exercise.imageName ?? Constants.randomImage,
                        title: exercise.name,
                        subtitle: "\(String.countCaption(count: session.exercises.count, unit: "set")) - \(String(format: "%g", volume)) kg volume"
                    )
                }
                .listRowInsets(.vertical, 0)
                .listRowInsets(.leading, 0)
            }
        } header: {
            Text("Exercise Details")
        }
    }

    private func headerSection(session: WorkoutSessionModel, endedAt: Date?) -> some View {
        Section {
                        
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
                StatCard(
                    value: "\(session.exercises.count)",
                    label: "Exercises",
                    icon: "list.bullet",
                    color: .blue,
                    alignment: .center
                )
                
                StatCard(
                    value: "\(presenter.totalSets(session: session))",
                    label: "Sets",
                    icon: "square.stack.3d.up",
                    color: .purple,
                    alignment: .center
                )

                StatCard(
                    value: presenter.volumeFormatted(session: session),
                    label: "Volume",
                    icon: "scalemass",
                    color: .orange,
                    alignment: .center
                )
            }

            notesEditor()

        } header: {
            HStack {
                Text("Workout Summary")
                Spacer()
                if let duration = endedAt?.timeIntervalSince(session.dateCreated) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("Duration: \(Date.formatDuration(duration))")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }

            }
        }
    }
        
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close) {
                if presenter.hasUnsavedChanges(session: delegate.initialSession, editedSession: session) {
                    presenter.showDiscardChangesAlert(session: session)
                } else {
                    presenter.onDismissPressed()
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
                    Button("Copy Link", systemImage: "link") {
                        presenter.onCopyLinkPressed(link, session: session)
                    }
                }
            } label: {
                Label("Share Image", systemImage: "square.and.arrow.up")
            }
        }

        if presenter.isAuthor(sessionAuthorId: session.authorId) {
//            ToolbarItem(placement: .topBarTrailing) {
//                if presenter.isEditMode {
//                    Button(role: .confirm) {
//                        Task { await presenter.saveChanges(initialSession: delegate.initialSession, session: $session) }
//                    }
//                    .disabled(presenter.isLoading || !presenter.hasUnsavedChanges(session: delegate.initialSession, editedSession: session))
//                    .fontWeight(.semibold)
//                } else {
//                    Button {
//                        presenter.enterEditMode(session: session)
//                    } label: {
//                        Image(systemName: "pencil")
//                    }
//                }
//            }
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
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    Button(role: .destructive) {
                        presenter.onDeletePressed(session: session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }
    
    @ViewBuilder
    private func notesEditor() -> some View {
        // Notes editor (editable in edit mode)
        if presenter.isEditMode {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ZStack(alignment: .topLeading) {
                    let notesValue = session.notes ?? ""
                    if notesValue.isEmpty {
                        Text("Add notes here...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 6)
                    }
                    TextEditor(
                        text: Binding(
                            get: { session.notes ?? "" },
                            set: { newValue in session.notes = newValue.isEmpty ? nil : newValue }
                        )
                    )
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .textInputAutocapitalization(.sentences)
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        } else if let notes = session.notes, !notes.isEmpty {
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
