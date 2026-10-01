//
//  ImageDescriptionBuilderTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The prompt sent to the image generator.
///
/// Nothing downstream validates this string — a malformed prompt produces a plausible-looking but
/// wrong picture, and the only way to notice is to look at the artwork. That is what let
/// `equipment.joined` ship uncalled, printing "Equipment: (Function)" into every exercise prompt.
@MainActor
struct ImageDescriptionBuilderTests {

    private func builder(
        subject: ImageDescriptionBuilder.SubjectKind = .exercise,
        mode: ImageDescriptionBuilder.Mode = .detailed,
        name: String = "Bench Press",
        description: String? = nil
    ) -> ImageDescriptionBuilder {
        ImageDescriptionBuilder(subject: subject, mode: mode, name: name, description: description)
    }

    // MARK: - The basics

    @Test("Test A Detailed Prompt Names Its Subject")
    func testADetailedPromptNamesItsSubject() {
        let prompt = builder().build()

        #expect(prompt.contains("exercise"))
        #expect(prompt.contains("Name: Bench Press"))
        #expect(prompt.contains("fitness and nutrition app"))
    }

    @Test("Test A Description Is Included When There Is One")
    func testADescriptionIsIncludedWhenThereIsOne() {
        #expect(builder(description: "A horizontal press").build().contains("Description: A horizontal press"))
        #expect(!builder(description: nil).build().contains("Description:"))
    }

    /// A description of nothing but spaces is not a description.
    @Test("Test A Blank Description Is Left Out")
    func testABlankDescriptionIsLeftOut() {
        #expect(!builder(description: "   ").build().contains("Description:"))
        #expect(!builder(description: "").build().contains("Description:"))
    }

    @Test("Test Each Subject Names Itself")
    func testEachSubjectNamesItself() {
        for subject in [ImageDescriptionBuilder.SubjectKind.exercise, .ingredient, .recipe, .workout] {
            #expect(builder(subject: subject).build().contains(subject.rawValue))
        }
    }

    // MARK: - Exercise details

    /// The bug this file was written for: the equipment list must read as a list, not as a
    /// description of the method that would have joined it.
    @Test("Test Equipment Is Listed, Not Described")
    func testEquipmentIsListedNotDescribed() {
        var builder = builder()
        builder.equipment = ["Barbell", "Bench"]

        let prompt = builder.build()

        #expect(prompt.contains("Equipment: Barbell, Bench"))
        #expect(!prompt.contains("Function"))
        #expect(!prompt.contains("("))
    }

    @Test("Test Muscle Groups Are Listed")
    func testMuscleGroupsAreListed() {
        var builder = builder()
        builder.muscleGroups = ["Chest", "Triceps"]

        #expect(builder.build().contains("Muscle groups: Chest, Triceps"))
    }

    @Test("Test An Empty List Is Left Out Entirely")
    func testAnEmptyListIsLeftOutEntirely() {
        var builder = builder()
        builder.equipment = []
        builder.muscleGroups = []

        let prompt = builder.build()

        #expect(!prompt.contains("Equipment:"))
        #expect(!prompt.contains("Muscle groups:"))
    }

    @Test("Test A Single Item Needs No Separator")
    func testASingleItemNeedsNoSeparator() {
        var builder = builder()
        builder.equipment = ["Barbell"]

        #expect(builder.build().contains("Equipment: Barbell"))
    }

    // MARK: - The other subjects

    @Test("Test An Ingredient Describes Its Form And Quantity")
    func testAnIngredientDescribesItsFormAndQuantity() {
        var builder = builder(subject: .ingredient, name: "Carrot")
        builder.ingredientForm = "sliced"
        builder.ingredientQuantity = "two"

        let prompt = builder.build()

        #expect(prompt.contains("Form: sliced"))
        #expect(prompt.contains("Quantity: two"))
    }

    @Test("Test A Recipe Describes Its Serving And Garnish")
    func testARecipeDescribesItsServingAndGarnish() {
        var builder = builder(subject: .recipe, name: "Porridge")
        builder.servingStyle = "in bowl"
        builder.garnishNotes = "berries"

        let prompt = builder.build()

        #expect(prompt.contains("Serving: in bowl"))
        #expect(prompt.contains("Garnish: berries"))
    }

    @Test("Test A Workout Describes Its Intensity And Setting")
    func testAWorkoutDescribesItsIntensityAndSetting() {
        var builder = builder(subject: .workout, name: "Push Day")
        builder.intensityNotes = "high intensity circuit"
        builder.environmentNotes = "home gym"

        let prompt = builder.build()

        #expect(prompt.contains("Intensity: high intensity circuit"))
        #expect(prompt.contains("Environment: home gym"))
    }

    /// Each subject takes only its own fields, so an ingredient's form cannot leak into an
    /// exercise prompt.
    @Test("Test A Subject Takes Only Its Own Fields")
    func testASubjectTakesOnlyItsOwnFields() {
        var builder = builder(subject: .exercise)
        builder.ingredientForm = "sliced"
        builder.servingStyle = "in bowl"
        builder.intensityNotes = "high intensity"

        let prompt = builder.build()

        #expect(!prompt.contains("Form:"))
        #expect(!prompt.contains("Serving:"))
        #expect(!prompt.contains("Intensity:"))
    }

    // MARK: - Visual directives

    /// The defaults are what give the generated artwork a consistent look across the app.
    @Test("Test The Visual Defaults Are Applied")
    func testTheVisualDefaultsAreApplied() {
        let prompt = builder().build()

        #expect(prompt.contains("Style: Minimal, clean app icon style"))
        #expect(prompt.contains("Background: Plain, light neutral background"))
        #expect(prompt.contains("Lighting: Soft, even lighting"))
        #expect(prompt.contains("Framing: Centered subject, no cropping"))
    }

    @Test("Test The Visual Directives Can Be Overridden")
    func testTheVisualDirectivesCanBeOverridden() {
        let builder = ImageDescriptionBuilder(
            subject: .exercise,
            mode: .detailed,
            name: "Bench Press",
            description: nil,
            desiredStyle: "Photorealistic",
            backgroundPreference: "Dark gym"
        )

        let prompt = builder.build()

        #expect(prompt.contains("Style: Photorealistic"))
        #expect(prompt.contains("Background: Dark gym"))
    }

    // MARK: - The concise mode

    /// A short directive for marketing artwork rather than the structured prompt.
    @Test("Test The Concise Mode Is One Sentence")
    func testTheConciseModeIsOneSentence() {
        let prompt = builder(mode: .marketingConcise).build()

        #expect(prompt == "Please generate an image of Bench Press suitable for marketing purposes")
        #expect(!prompt.contains("\n"))
    }

    /// An exercise's description is the more picturable phrase — "a man doing a seated leg
    /// extension" beats "Leg Extension" — so it wins when there is one.
    @Test("Test A Concise Exercise Prompt Prefers The Description")
    func testAConciseExercisePromptPrefersTheDescription() {
        let prompt = builder(mode: .marketingConcise, description: "a man doing a seated leg extension").build()

        #expect(prompt.contains("a man doing a seated leg extension"))
        #expect(!prompt.contains("Bench Press"))
    }

    /// Only for exercises: a recipe's description is a method, not a picture.
    @Test("Test Other Subjects Keep Their Name In The Concise Prompt")
    func testOtherSubjectsKeepTheirNameInTheConcisePrompt() {
        let prompt = builder(subject: .recipe, mode: .marketingConcise, name: "Porridge", description: "Simmer oats in milk").build()

        #expect(prompt.contains("Porridge"))
        #expect(!prompt.contains("Simmer"))
    }

    @Test("Test A Nameless Subject Falls Back To Its Kind")
    func testANamelessSubjectFallsBackToItsKind() {
        let prompt = builder(mode: .marketingConcise, name: "").build()

        #expect(prompt.contains("exercise"))
    }
}
