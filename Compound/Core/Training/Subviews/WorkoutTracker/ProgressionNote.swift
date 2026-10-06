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
        // The whole row is the button: a tap anywhere on it says it has been read.
        Button {
            onAcknowledge()
        } label: {
            VStack(spacing: Spacing.xs) {
                Label("Smart Progression", systemImage: Symbol.smartProgression)
                    .font(.label.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.rowTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tap to dismiss")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(Color.tintedSurface(.accentColor), in: .rect(cornerRadius: Radius.m, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Smart Progression. \(text)"))
        .accessibilityHint("Dismisses the note")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("WorkoutTracker.progressionNote.acknowledge")
    }
}

#Preview {
    List {
        ProgressionNote(text: "+2.5 kg today. You hit 5 reps on every working set last time.") { }
    }
}
