//
//  ExerciseEditorView.swift
//  Compound
//
//  A finished workout's exercise (`WorkoutSessionDetailView`): a row that opens onto its sets,
//  which stay editable, with the actions as chips over them. The live tracker draws the same
//  table as `ExerciseCardView`.
//

import SwiftUI

struct ExerciseEditorView<SetTrackerRow: View>: View {

    @AppStorage(ExerciseTrackerPresenter.showAutoRangesKey) private var showAutoRanges = false

    @State var presenter: ExerciseTrackerPresenter
    let delegate: ExerciseTrackerDelegate
    let isExpanded: Binding<Bool>

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            Group {
                VStack {
                    actionBar
                    ExerciseColumnHeadings(presenter: presenter, exercise: delegate.exercise)
                }
                LoggedWarmupsGroup(sets: exercise.loggedWarmups) { set in
                    row(for: set)
                }
                ForEach(exercise.unfoldedSets) { set in
                    row(for: set)
                }
                AddSetButton {
                    presenter.addSet(exercise: delegate.exercise)
                }
            }
            .setTableRow()
            .listSectionMargins(.top, 0)
        } label: {
            EditorExerciseHeader(
                exercise: exercise,
                imageName: presenter.imageName(for: exercise),
                exerciseNote: presenter.note(for: exercise),
                onNotePressed: { presenter.openNotes(for: delegate) }
            )
        }
    }
    
    private var exercise: WorkoutExerciseModel { delegate.exercise.wrappedValue }

    /// The actions as chips over the table, as there is no title row to hold a menu.
    private var actionBar: some View {
        ScrollView(.horizontal) {
            HStack {
                Group {
                    ExerciseActionButtons(presenter: presenter, delegate: delegate)
                    Menu {
                        Button {
                            presenter.onExerciseSettingsPressed(exercise: delegate.exercise.wrappedValue)
                        } label: {
                            Label("Exercise Settings", systemImage: Symbol.settings)
                        }

                        Button(role: .destructive) {
                            presenter.deleteExercise(delegate.exercise, onDelete: delegate.onDeleteExercise)
                        } label: {
                            Label("Delete", systemImage: Symbol.delete)
                        }
                    } label: {
                        Label("More", systemImage: Symbol.more)
                            .tapTarget()
                    }
                }
                .font(.label)
                .buttonStyle(.bordered)
                .toggleStyle(.button)
                .tint(.secondary)
                .buttonBorderShape(.capsule)
            }
            // Room for each chip's 44 pt hit area, which the scroll view would otherwise clip.
            .frame(minHeight: ControlSize.row)
        }
        .scrollIndicators(.hidden)
    }

    private func row(for set: WorkoutSetModel) -> some View {
        setTrackerRow(delegate.rowDelegate(for: set, showAutoRanges: showAutoRanges))
            .listRowSeparator(.visible, edges: .top)
            .listRowSeparator(.visible, edges: .bottom)
    }
}

// MARK: - Previews

#Preview("Finished workout editor") {
    @Previewable @State var exercise = WorkoutExerciseModel.mock
    @Previewable @State var isExpanded = true
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        List {
            Section {
                builder.exerciseEditorView(
                    router: router,
                    delegate: ExerciseTrackerDelegate(exercise: $exercise, lastExercise: nil),
                    isExpanded: $isExpanded
                )
            }
        }
    }
}

extension CoreBuilder {
    func exerciseEditorView(
        router: AnyRouter,
        delegate: ExerciseTrackerDelegate,
        isExpanded: Binding<Bool>
    ) -> some View {
        ExerciseEditorView(
            presenter: ExerciseTrackerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            isExpanded: isExpanded,
            setTrackerRow: { delegate in
                self.setTrackerRowView(router: router, delegate: delegate)
            }
        )
    }
}
