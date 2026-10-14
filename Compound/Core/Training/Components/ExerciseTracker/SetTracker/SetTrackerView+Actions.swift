//
//  SetTrackerView+Actions.swift
//  Compound
//
//  The exercise's actions: the card's overflow menu and the editor's equipment button.
//

import SwiftUI

extension SetTrackerView {

    /// The chips over the table where the exercise has no card header, as when a finished
    /// workout is being corrected.
    var equipmentButton: some View {
        ScrollView(.horizontal) {
            HStack {
                Group {
                    actionButtons()
                    Menu {
                        moreButtons
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
    }

    /// The same actions as one overflow menu, for the card's title row.
    var actionsMenu: some View {
        Menu {
            if let card = delegate.card {
                Button {
                    card.onNotePressed()
                } label: {
                    Label("Notes", systemImage: Symbol.note)
                }
                if let onDoLater = card.exerciseCard.onDoLater {
                    Button {
                        onDoLater()
                    } label: {
                        Label("Do Later", systemImage: Symbol.doLater)
                    }
                }
                if let onWatch = card.onWatch {
                    Button {
                        onWatch()
                    } label: {
                        Label("Watch", systemImage: Symbol.video)
                    }
                }
                Divider()
            }
            actionButtons()
            Divider()
            moreButtons
        } label: {
            // A real 44 pt frame: the accessibility audit measures the frame, not the hit area
            // `tapTarget()` pads out behind it.
            Image(systemName: Symbol.more)
                .imageScale(.large)
                .frame(width: ControlSize.row, height: ControlSize.row)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Exercise options")
    }

    /// One superset member's actions, as a submenu of the superset's menu
    /// (`SupersetBlockView`). Do Later and Remove Superset are the block's, so its menu holds them.
    var memberActionsMenu: some View {
        Menu {
            if let card = delegate.card {
                Button {
                    card.onNotePressed()
                } label: {
                    Label("Notes", systemImage: Symbol.note)
                }
                if let onWatch = card.onWatch {
                    Button {
                        onWatch()
                    } label: {
                        Label("Watch", systemImage: Symbol.video)
                    }
                }
                Divider()
            }
            Button {
                presenter.addSet(exercise: delegate.exercise)
            } label: {
                Label("Add Set", systemImage: Symbol.add)
            }
            actionButtons(includesSuperset: false)
            Divider()
            moreButtons
        } label: {
            Text([delegate.card?.exerciseCard.memberLetter, delegate.exercise.wrappedValue.name].compactMap { $0 }.joined(separator: " "))
        }
    }

    @ViewBuilder
    private func actionButtons(includesSuperset: Bool = true) -> some View {
        if !delegate.exercise.wrappedValue.equipmentVariations.isEmpty {
            Button {
                presenter.onExerciseEquipmentPressed(delegate.exercise)
            } label: {
                Label("Equipment…", systemImage: Symbol.equipment)
                    .tapTarget()
            }
        }

        if delegate.exercise.wrappedValue.isPerSide {
            // A toggle, so the menu draws a checkmark beside it while the sides are split; a tint
            // is not drawn inside a menu.
            let exercise = delegate.exercise
            Toggle(isOn: Binding(
                get: { exercise.wrappedValue.isSplit },
                set: { _ in presenter.onSplitSidesPressed(exercise) }
            )) {
                Label("Split L/R", systemImage: Symbol.splitSides)
                    .tapTarget()
            }
            .accessibilityLabel("Split left and right")
            .accessibilityHint("Logs each side as its own set")
        }

        Button {
            presenter.onTargetsPressed(delegate.exercise)
        } label: {
            Label("Targets…", systemImage: Symbol.goal)
                .tapTarget()
        }

        Button {
            presenter.onSwapPressed(delegate.exercise, onSwap: delegate.onSwap)
        } label: {
            Label("Swap…", systemImage: Symbol.swap)
                .tapTarget()
        }

        if includesSuperset {
            supersetButton
        }
    }

    private var supersetButton: some View {
        Button {
            presenter.onSupersetPressed(
                exercise: delegate.exercise,
                allWorkoutExercises: delegate.allWorkoutExercises,
                onSetSupersetGroup: delegate.onSetSupersetGroup
            )
        } label: {
            let groupLabel: String = {
                guard let groupId = delegate.exercise.wrappedValue.supersetGroupId else { return String(localized: "Superset…") }
                let count = delegate.allWorkoutExercises.filter { $0.supersetGroupId == groupId }.count
                return count > 2 ? String(localized: "Remove Circuit") : String(localized: "Remove Superset")
            }()
            Label(groupLabel, systemImage: Symbol.superset)
                .tapTarget()
        }
    }

    @ViewBuilder
    private var moreButtons: some View {
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
    }
}
