//
//  EditorExerciseHeader.swift
//  Compound
//
//  A finished workout's exercise, as the row that opens onto its sets.
//

import SwiftUI

/// The picture, name and progress, the exercise's own note and this session's, and a button for
/// the notes.
struct EditorExerciseHeader: View {

    let exercise: WorkoutExerciseModel
    let imageName: String?
    /// The note kept on the exercise itself (`ExerciseTrackerPresenter.note(for:)`).
    let exerciseNote: String?
    let onNotePressed: () -> Void

    @ScaledMetric(relativeTo: .body) private var thumbnailSide = ControlSize.thumbnail

    var body: some View {
        HStack(alignment: .center) {
            ExerciseImageView(name: exercise.name, imageName: imageName)
                .frame(width: thumbnailSide, height: thumbnailSide)
                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exercise.name)
                    .font(.sectionTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                setProgress
                if let exerciseNote {
                    Text(exerciseNote)
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                if let sessionNote = exercise.notes {
                    Label(sessionNote, systemImage: Symbol.note)
                        .font(.label)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            // Borderless so a tap opens the note sheet rather than toggling the row it sits on.
            Button(action: onNotePressed) {
                Image(systemName: exercise.notes == nil ? Symbol.addNote : Symbol.note)
                    .tapTarget()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(exercise.notes == nil ? String(localized: "Add note") : String(localized: "Edit note"))
        }
        .tappableBackground()
        .listRowInsets(.vertical, .zero)
    }

    /// Counted in sets, not rows: three sets a side reads "Set 2/3", not "Set 4/6". A finished
    /// exercise gets a check as well as the colour.
    private var setProgress: some View {
        let isDone = exercise.loggedSetCount == exercise.workingSetCount
        return HStack(spacing: Spacing.xs) {
            if isDone {
                Image(systemName: Symbol.success)
                    .accessibilityHidden(true)
            }
            Text("Set \(min(exercise.loggedSetCount + 1, exercise.workingSetCount))/\(exercise.workingSetCount)")
        }
        .font(.label)
        .foregroundStyle(isDone ? AnyShapeStyle(.success) : AnyShapeStyle(.secondary))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? String(localized: "All sets done") : "")
    }
}
