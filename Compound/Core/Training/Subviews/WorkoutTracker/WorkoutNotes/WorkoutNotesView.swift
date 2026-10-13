//
//  WorkoutNotesView.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

import SwiftUI

/// One note the sheet edits. An exercise's sheet has three, one per tab.
struct NoteTab: Identifiable {
    enum Kind: Hashable {
        /// The only note, as on the finish screen: no tabs.
        case single
        /// This exercise in this workout, saved to its history.
        case session
        /// The exercise's own note, shown every time it is done.
        case exercise
        /// One slot of one mesocycle day plan, shown every week of that day.
        case mesocycle
    }

    let kind: Kind
    var title: String = ""
    var text: Binding<String>
    /// Shown greyed above the editor, e.g. the note left on this exercise last session.
    var hint: String?
    /// Under the editor: where the note is kept and when it shows.
    var footer: String?

    var id: Kind { kind }
}

struct WorkoutNotesDelegate {
    var tabs: [NoteTab]
    /// The tab the sheet opens on.
    var selectedTab: NoteTab.Kind = .single
    let onSave: () -> Void
    var title: String = "Workout Notes"
    var saveTitle: String = "Save"
    /// Runs once the sheet is fully gone, whichever button closed it. The finish screen uses it
    /// to end the workout only after its own sheet is out of the way.
    var onDidDismiss: (() -> Void)?

    /// A sheet with one note and no tabs.
    init(
        notes: Binding<String>,
        onSave: @escaping () -> Void,
        title: String = "Workout Notes",
        hint: String? = nil,
        saveTitle: String = "Save",
        onDidDismiss: (() -> Void)? = nil
    ) {
        self.tabs = [NoteTab(kind: .single, text: notes, hint: hint)]
        self.onSave = onSave
        self.title = title
        self.saveTitle = saveTitle
        self.onDidDismiss = onDidDismiss
    }

    init(tabs: [NoteTab], selectedTab: NoteTab.Kind, onSave: @escaping () -> Void, title: String) {
        self.tabs = tabs
        self.selectedTab = selectedTab
        self.onSave = onSave
        self.title = title
    }

    /// The first tab's note and hint: the only ones on a sheet without tabs.
    var notes: Binding<String> { tabs[0].text }
    var hint: String? { tabs[0].hint }
}

struct WorkoutNotesView: View {

    @State var presenter: WorkoutNotesPresenter
    
    var delegate: WorkoutNotesDelegate

    private var tab: NoteTab {
        delegate.tabs.first { $0.kind == presenter.selectedTab } ?? delegate.tabs[0]
    }

    var body: some View {
        VStack(alignment: .leading) {
            if delegate.tabs.count > 1 {
                Picker("Note", selection: $presenter.selectedTab) {
                    ForEach(delegate.tabs) { tab in
                        Text(tab.title).tag(tab.kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
            }
            if let hint = tab.hint {
                Text("Last time: \(hint)")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top)
            }
            TextEditor(text: tab.text)
                .scrollContentBackground(.hidden)
                .padding()
                .cardSurface()
                .padding([.horizontal, .top])
                // One editor per tab, so switching does not carry the cursor or undo across.
                .id(tab.kind)
            if let footer = tab.footer {
                Text(footer)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .navigationTitle(delegate.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(delegate.saveTitle, role: .confirm) {
                delegate.onSave()
                presenter.onDismissPressed()
            }
        }
    }
}

extension CoreBuilder {
    func workoutNotesView(router: AnyRouter, delegate: WorkoutNotesDelegate) -> some View {
        WorkoutNotesView(
            presenter: WorkoutNotesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                selectedTab: delegate.selectedTab
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate) {
        router.showScreen(.sheet, onDidDismiss: delegate.onDidDismiss) { router in
            builder.workoutNotesView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    List {
        Text("Hello")
    }
    .sheet(isPresented: .constant(true)) {
        RouterView { router in
            builder.workoutNotesView(
                router: router,
                delegate: WorkoutNotesDelegate(
                    notes: Binding.constant(""),
                    onSave: {
                        
                    }
                )
            )
        }
    }
}
