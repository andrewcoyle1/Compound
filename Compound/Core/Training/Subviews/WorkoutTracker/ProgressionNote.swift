//
//  ProgressionNote.swift
//  Compound
//
//  Why smart progression changed today's numbers, as a row above the exercise's sets as it
//  starts, until the user says they have read it.
//

import SwiftUI

struct ProgressionNote: View {

    let text: String
    let onAcknowledge: @MainActor () -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            // The method sits beside the label, outside the dismiss button, so asking how the
            // numbers were reached does not dismiss them.
            HStack(spacing: Spacing.xs) {
                Label("Smart Progression", systemImage: Symbol.smartProgression)
                    .font(.label.weight(.semibold))
                    .foregroundStyle(.secondary)
                MethodInfoButton(.smartProgression)
            }
            // The rest of the row is the button: a tap anywhere on it says it has been read.
            Button {
                onAcknowledge()
            } label: {
                VStack(spacing: Spacing.xs) {
                    Text(text)
                        .font(.rowTitle)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Tap to dismiss")
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Smart Progression. \(text)"))
            .accessibilityHint("Dismisses the note")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("WorkoutTracker.progressionNote.acknowledge")
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.tintedSurface(.accentColor), in: .rect(cornerRadius: Radius.m, style: .continuous))
    }
}

#Preview {
    List {
        ProgressionNote(text: "+2.5 kg today. You hit 5 reps on every working set last time.") { }
    }
}
