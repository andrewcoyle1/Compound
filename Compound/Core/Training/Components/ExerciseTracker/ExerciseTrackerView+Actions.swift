//
//  ExerciseTrackerView+Actions.swift
//  Compound
//
//  The exercise's actions: the card's overflow menu, a superset member's submenu, and the
//  editor's bar of chips.
//

import SwiftUI

extension ExerciseTrackerView {

    /// The actions as chips over the table, where there is no card header to hold a menu: a
    /// finished workout's editor.
    var actionBar: some View {
        ScrollView(.horizontal) {
            HStack {
                Group {
                    actionButtons()
                    Menu {
                        settingsAndDelete
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

    /// The card's overflow menu, in its title row.
    var actionsMenu: some View {
        Menu {
            menuItems(isMember: false)
        } label: {
            MoreMenuLabel()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Exercise options")
    }

    /// A superset member's actions, as a submenu of the superset's menu (`SupersetBlockView`),
    /// which holds Do Later and Remove Superset for the whole block.
    var memberActionsMenu: some View {
        Menu {
            menuItems(isMember: true)
        } label: {
            Text([delegate.card?.memberLabel, delegate.exercise.wrappedValue.name].compactMap { $0 }.joined(separator: " "))
        }
    }

    @ViewBuilder
    private func menuItems(isMember: Bool) -> some View {
        Button {
            openNotes(on: .session)
        } label: {
            Label("Notes", systemImage: Symbol.note)
        }
        if !isMember, let onDoLater = delegate.card?.onDoLater {
            Button {
                onDoLater()
            } label: {
                Label("Do Later", systemImage: Symbol.doLater)
            }
        }
        if let onWatch = watchAction {
            Button {
                onWatch()
            } label: {
                Label("Watch", systemImage: Symbol.video)
            }
        }
        Divider()
        if isMember {
            Button {
                presenter.addSet(exercise: delegate.exercise)
            } label: {
                Label("Add Set", systemImage: Symbol.add)
            }
        }
        actionButtons(includesSuperset: !isMember)
        Divider()
        settingsAndDelete
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
    private var settingsAndDelete: some View {
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

/// The overflow menu's "…", in a real 44 pt frame: the accessibility audit measures the frame, not
/// the hit area `tapTarget()` pads out behind it.
struct MoreMenuLabel: View {
    var body: some View {
        Image(systemName: Symbol.more)
            .imageScale(.large)
            .frame(width: ControlSize.row, height: ControlSize.row)
            .contentShape(.rect)
    }
}
