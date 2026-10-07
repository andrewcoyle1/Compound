//
//  ImportProgramView.swift
//  Compound
//

import SwiftUI

struct ImportProgramView: View {

    @State var presenter: ImportProgramPresenter

    var body: some View {
        List {
            if let message = presenter.errorMessage {
                Section {
                    InlineMessage(.error, message)
                }
            }
            if presenter.isLoading {
                Section {
                    ProgressView("Reading file…")
                        .frame(maxWidth: .infinity)
                }
            } else if presenter.hasFile {
                fileSection
                if !presenter.reviewNames.isEmpty {
                    unmatchedSection
                }
                if let summary = presenter.summary {
                    summarySection(summary)
                }
            }
        }
        .overlay {
            if !presenter.hasFile && !presenter.isLoading {
                emptyState
            }
        }
        .navigationTitle("Import Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.onClosePressed()
                }
            }
        }
        .fileImporter(
            isPresented: $presenter.isFileImporterPresented,
            allowedContentTypes: presenter.contentTypes,
            onCompletion: presenter.onFileImported
        )
        .bottomCTA {
            if presenter.hasFile {
                CallToActionButton(isLoading: presenter.isSaving) {
                    presenter.onSavePressed()
                } label: {
                    Text("Save Program")
                }
                .disabled(!presenter.canSave)
            }
        }
        .interactiveDismissDisabled(presenter.hasFile)
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Import Program", systemImage: Symbol.mesocycle)
        } description: {
            Text("Spreadsheet, CSV or JSON")
        } actions: {
            Button {
                presenter.onChooseFilePressed()
            } label: {
                Text("Choose a file")
                    .foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var fileSection: some View {
        Section {
            ListRowButton(title: presenter.fileName ?? "", subtitle: String(localized: "Choose a file")) {
                presenter.onChooseFilePressed()
            }
        }
    }

    private var unmatchedSection: some View {
        Section {
            ForEach(presenter.reviewNames, id: \.self) { name in
                Menu {
                    Button("Choose from library") {
                        presenter.onChooseFromLibraryPressed(name: name)
                    }
                    Button("Create \"\(name)\"") {
                        presenter.onCreatePressed(name: name)
                    }
                } label: {
                    ListRow(
                        title: name,
                        subtitle: presenter.status(of: name),
                        accessory: .checkmark(presenter.mappings[name] != nil)
                    )
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Unmatched exercises")
        } footer: {
            Text("Match each exercise to one in your library, or create it. A new exercise has no muscle groups until you add them.")
        }
    }

    private func summarySection(_ summary: ImportProgramPresenter.Summary) -> some View {
        Section {
            ListRow(title: String(localized: "\(summary.blocks) blocks"))
            ListRow(title: String(localized: "\(summary.weeks) weeks"))
            ListRow(title: String(localized: "\(summary.days) days"))
            ListRow(title: String(localized: "\(summary.exercises) exercises"))
            if !summary.techniques.isEmpty {
                ListRow(title: String(localized: "Techniques"), subtitle: summary.techniques.formatted(.list(type: .and)))
            }
            ListRow(title: "Warm-ups", accessory: .value(String(localized: "\(summary.withWarmups) of \(summary.exercises)")))
            ListRow(title: "Rest", accessory: .value(String(localized: "\(summary.withRest) of \(summary.exercises)")))
        } header: {
            Text("Summary")
        } footer: {
            Text("Saved as a program that has not started. Start it from your mesocycles.")
        }
    }
}

extension CoreBuilder {
    func importProgramView(router: AnyRouter) -> some View {
        ImportProgramView(
            presenter: ImportProgramPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }

    /// The exercise library as a one-tap picker, its search already holding the sheet's name.
    func importExercisePickerView(router: AnyRouter, name: String, onSelect: @escaping @MainActor (ExerciseModel) -> Void) -> some View {
        let presenter = ExerciseListBuilderPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        presenter.searchText = name
        return ExerciseListBuilderView(
            presenter: presenter,
            delegate: ExerciseListBuilderDelegate(onExerciseSelectionChanged: { exercise in
                onSelect(exercise)
                router.dismissScreen()
            })
        )
        .navigationTitle("Choose from library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    router.dismissScreen()
                }
            }
        }
    }
}

extension CoreRouter {
    func showImportProgramView() {
        router.showScreen(.sheet) { router in
            builder.importProgramView(router: router)
        }
    }

    func showImportExercisePickerView(name: String, onSelect: @escaping @MainActor (ExerciseModel) -> Void) {
        router.showScreen(.sheet) { router in
            builder.importExercisePickerView(router: router, name: name, onSelect: onSelect)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    RouterView { router in
        builder.importProgramView(router: router)
    }
}
