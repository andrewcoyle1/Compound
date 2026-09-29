//
//  CoreBuilder.swift
//  DialedIn
//
//  Created by Andrew Coyle on 10/11/2025.
//

import SwiftUI

private struct WorkoutStartMiddleContent: View {
    let template: WorkoutTemplateModel
    
    var body: some View {
        let minutes = template.exercises.count * 4
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        let exerciseCount: String = hours > 0
            ? "\(hours)h \(remainingMinutes)m"
            : "\(remainingMinutes)m"
        
        let categories = template.exercises.map { $0.exercise.type }
        let categoryFrequency = Dictionary(grouping: categories, by: { $0 })
            .mapValues { $0.count }
        
        let mostCommon = categoryFrequency.max(by: { $0.value < $1.value })?.key?.name ?? "Mixed"
        
        HStack(alignment: .firstTextBaseline) {
            StatCard(
                value: "\(template.exercises.count)",
                label: "Exercises"
            )
            StatCard(
                value: exerciseCount,
                label: "Est. Time"
            )
            StatCard(
                value: mostCommon,
                label: "Focus"
            )
        }
    }
}

@MainActor
struct CoreBuilder: Builder {
    
    let interactor: CoreInteractor
    
    func build() -> AnyView {
        appView().any()
    }
}

extension CoreBuilder {

    func ratingsModal(onYesPressed: @escaping () -> Void, onNoPressed: @escaping () -> Void) -> some View {
        CustomModalView(
            title: String(localized: "Are you enjoying AIChat?"),
            subtitle: String(localized: "We'd love to hear your feedback!"),
            primaryButtonTitle: "Yes",
            primaryButtonAction: {
                onYesPressed()
            },
            secondaryButtonTitle: "No",
            secondaryButtonAction: {
                onNoPressed()
            }
        )
    }
}
