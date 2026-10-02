//
//  ImageDescriptionBuilder.swift
//  Compound
//
//  Created by Andrew Coyle on 09/28/2025.
//

import Foundation

/// Builds a well-structured prompt for generating an image across app subjects.
struct ImageDescriptionBuilder {
    enum SubjectKind: String {
        case exercise
        case ingredient
        case recipe
        case workout
    }

    let subject: SubjectKind
    let name: String
    let description: String?

    // Common visual controls
    var contextNotes: String?
    var desiredStyle: String?
    var backgroundPreference: String?
    var lightingPreference: String?
    var framingNotes: String?
    var negativePrompts: [String] = []

    // Subject-specific optional fields
    // Exercise
    var muscleGroups: [String]? // e.g., ["Chest", "Triceps"]
    var equipment: [String]? // e.g., ["Barbell", "Bench"]

    // Ingredient
    var ingredientForm: String? // e.g., "whole", "sliced", "diced"
    var ingredientQuantity: String? // textual quantity if helpful

    // Recipe
    var servingStyle: String? // e.g., "in bowl", "on plate", "stacked"
    var garnishNotes: String? // e.g., "parsley garnish", "lemon wedge"

    // Workout
    var intensityNotes: String? // e.g., "high intensity circuit", "calm yoga flow"
    var environmentNotes: String? // e.g., "home gym", "outdoor track"

    init(
        subject: SubjectKind,
        mode: Mode,
        name: String,
        description: String?,
        contextNotes: String? = nil,
        desiredStyle: String? = "Minimal, clean app icon style",
        backgroundPreference: String? = "Plain, light neutral background",
        lightingPreference: String? = "Soft, even lighting",
        framingNotes: String? = "Centered subject, no cropping"
    ) {
        self.subject = subject
        self.mode = mode
        self.name = name
        self.description = description
        self.contextNotes = contextNotes
        self.desiredStyle = desiredStyle
        self.backgroundPreference = backgroundPreference
        self.lightingPreference = lightingPreference
        self.framingNotes = framingNotes
    }

    enum Mode {
        case detailed
        case marketingConcise
    }

    var mode: Mode

    private var detailedOrDefault: Mode { .detailed }

    /// Returns the final prompt string.
    func build() -> String {
        switch mode {
        case .marketingConcise:
            return buildMarketingConcise()
        case .detailed:
            return buildDetailed()
        }
    }

    private func buildMarketingConcise() -> String {
        // A short, marketing-suitable directive similar to the user-provided example.
        // Example output: "Please generate an image of a man doing seated leg extension suitable for marketing purposes"
        var subjectLine = name.isEmpty ? subject.rawValue : name
        if subject == .exercise, let description, !description.isEmpty {
            subjectLine = description
        }
        return "Please generate an image of \(subjectLine) suitable for marketing purposes"
    }

    private func buildDetailed() -> String {
        var sections: [String] = []

        sections.append(contentsOf: buildBasicSections())
        
        sections.append(contentsOf: buildSubjectSpecificSections())
        
        sections.append(contentsOf: buildVisualDirectives())
        
        sections.append(contentsOf: buildNegativePrompts())

        return sections.joined(separator: "\n")
    }
    
    private func buildBasicSections() -> [String] {
        var sections: [String] = []
        
        sections.append("Generate a single illustrative image for a \(subject.rawValue). This will be included in a fitness and nutrition app.")
        sections.append("Name: \(name)")
        
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Description: \(description)")
        }
        
        if let contextNotes, !contextNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Context: \(contextNotes)")
        }
        
        return sections
    }
    
    private func buildSubjectSpecificSections() -> [String] {
        switch subject {
        case .exercise:
            return buildExerciseSections()
        case .ingredient:
            return buildIngredientSections()
        case .recipe:
            return buildRecipeSections()
        case .workout:
            return buildWorkoutSections()
        }
    }
    
    private func buildExerciseSections() -> [String] {
        var sections: [String] = []
        
        if let muscleGroups, !muscleGroups.isEmpty {
            sections.append("Muscle groups: \(muscleGroups.joined(separator: ", "))")
        }
        
        if let equipment, !equipment.isEmpty {
            sections.append("Equipment: \(equipment.joined(separator: ", "))")
        }
        
        return sections
    }
    
    private func buildIngredientSections() -> [String] {
        var sections: [String] = []
        
        if let ingredientForm, !ingredientForm.isEmpty {
            sections.append("Form: \(ingredientForm)")
        }
        
        if let ingredientQuantity, !ingredientQuantity.isEmpty {
            sections.append("Quantity: \(ingredientQuantity)")
        }
        
        return sections
    }
    
    private func buildRecipeSections() -> [String] {
        var sections: [String] = []
        
        if let servingStyle, !servingStyle.isEmpty {
            sections.append("Serving: \(servingStyle)")
        }
        
        if let garnishNotes, !garnishNotes.isEmpty {
            sections.append("Garnish: \(garnishNotes)")
        }
        
        return sections
    }
    
    private func buildWorkoutSections() -> [String] {
        var sections: [String] = []
        
        if let intensityNotes, !intensityNotes.isEmpty {
            sections.append("Intensity: \(intensityNotes)")
        }
        
        if let environmentNotes, !environmentNotes.isEmpty {
            sections.append("Environment: \(environmentNotes)")
        }
        
        return sections
    }
    
    private func buildVisualDirectives() -> [String] {
        var sections: [String] = []
        
        if let desiredStyle, !desiredStyle.isEmpty {
            sections.append("Style: \(desiredStyle)")
        }
        
        if let backgroundPreference, !backgroundPreference.isEmpty {
            sections.append("Background: \(backgroundPreference)")
        }
        
        if let lightingPreference, !lightingPreference.isEmpty {
            sections.append("Lighting: \(lightingPreference)")
        }
        
        if let framingNotes, !framingNotes.isEmpty {
            sections.append("Framing: \(framingNotes)")
        }
        
        return sections
    }
    
    private func buildNegativePrompts() -> [String] {
        guard !negativePrompts.isEmpty else { return [] }
        
        let negatives = negativePrompts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !negatives.isEmpty else { return [] }
        
        return ["Avoid: \(negatives.joined(separator: ", "))"]
    }
}
