//
//  FoodItemQuickAddPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Quick Add: macros typed straight in, with no food behind them.
///
/// Every other way into the log scales a stored food per 100g. This one is absolute — what is
/// typed is what is stored — and it is the only screen that accepts two different units for the
/// same figure and derives energy from the rest. That makes the arithmetic the substance: Atwater
/// factors, kilojoules, and ounces that must reach grams before anything is multiplied by four.
@MainActor
struct FoodItemQuickAddPresenterTests {

    // MARK: - Doubles

    private final class Interactor: SpyGlobalInteractor, FoodItemQuickAddInteractor { }

    /// `dismissScreen()` is a `GlobalRouter` extension and cannot be observed.
    private final class Router: FoodItemQuickAddRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// Holds whatever the picker is handed back.
    private final class PickBox {
        var picked: [MealItemModel] = []
    }

    private struct Screen {
        let presenter: FoodItemQuickAddPresenter
        let interactor: Interactor
        let router: Router
        let box: PickBox
        let delegate: FoodItemQuickAddDelegate
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        let box = PickBox()
        return Screen(
            presenter: FoodItemQuickAddPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router,
            box: box,
            delegate: FoodItemQuickAddDelegate(onPick: { box.picked.append($0) })
        )
    }

    /// A screen with a name and macros filled in, ready to submit.
    private func filledScreen(
        name: String = "Leftovers",
        protein: Double? = 10,
        carbs: Double? = 20,
        fats: Double? = 5
    ) -> Screen {
        let screen = makeScreen()
        screen.presenter.quickAddName = name
        screen.presenter.proteinValue = protein
        screen.presenter.carbsValue = carbs
        screen.presenter.fatsValue = fats
        return screen
    }

    // MARK: - Deriving the energy

    /// Atwater: four per gram of protein and carbohydrate, nine for fat.
    @Test("Test Energy Is Derived From The Macros")
    func testEnergyIsDerivedFromTheMacros() {
        let screen = filledScreen(protein: 10, carbs: 20, fats: 5)

        // (10 * 4) + (20 * 4) + (5 * 9) = 165
        #expect(screen.presenter.computedTotalEnergy == 165)
    }

    /// Alcohol is seven per gram, and has no `NutrientKey` of its own, so the only place it can
    /// show up is the derived energy.
    @Test("Test Alcohol Contributes Seven Per Gram")
    func testAlcoholContributesSevenPerGram() {
        let screen = filledScreen(protein: 0, carbs: 0, fats: 0)
        screen.presenter.alcoholValue = 10

        #expect(screen.presenter.computedTotalEnergy == 70)
    }

    /// The macro fields accept ounces, so they have to reach grams before the Atwater factors are
    /// applied — multiplying ounces by four under-reports the entry by a factor of 28.
    @Test("Test Macros In Ounces Reach Grams Before The Factors")
    func testMacrosInOuncesReachGramsBeforeTheFactors() {
        let screen = filledScreen(protein: 1, carbs: 0, fats: 0)
        screen.presenter.weightUnit = .ounces

        // 1oz is 28.35g, so 28.35 * 4 = 113 to the nearest whole calorie.
        #expect(screen.presenter.computedTotalEnergy == 113)
    }

    /// The footer shows the macro sum in the unit the energy field is set to.
    @Test("Test The Macro Sum Follows The Energy Unit")
    func testTheMacroSumFollowsTheEnergyUnit() {
        let screen = makeScreen()
        screen.presenter.proteinValue = 25

        #expect(screen.presenter.macroEnergyInSelectedUnit == 100)
        screen.presenter.unitOfEnergy = .kjoule
        #expect(screen.presenter.macroEnergyInSelectedUnit == 418)
    }

    @Test("Test Energy Is Zero With Nothing Entered")
    func testEnergyIsZeroWithNothingEntered() {
        let screen = makeScreen()

        #expect(screen.presenter.computedTotalEnergy == 0)
        #expect(screen.presenter.resolvedCalories == 0)
    }

    // MARK: - Resolving the energy actually stored

    /// A figure read off a label beats the macro sum. Rounding in the macros should not overrule
    /// someone who knows what the packet says.
    @Test("Test A Typed Energy Wins Over The Macro Sum")
    func testATypedEnergyWinsOverTheMacroSum() {
        let screen = filledScreen(protein: 10, carbs: 20, fats: 5)
        screen.presenter.energyValue = 200

        #expect(screen.presenter.computedTotalEnergy == 165)
        #expect(screen.presenter.resolvedCalories == 200)
    }

    /// The log stores kilocalories, so a figure typed in kilojoules is converted on the way in.
    @Test("Test A Typed Energy In Kilojoules Is Converted")
    func testATypedEnergyInKilojoulesIsConverted() {
        let screen = filledScreen()
        screen.presenter.energyValue = 418.4
        screen.presenter.unitOfEnergy = .kjoule

        #expect(abs(screen.presenter.resolvedCalories - 100) < 0.0001)
    }

    /// Zero is not a figure the user meant to assert, so it falls back to the macros rather than
    /// storing an entry with no energy in it.
    @Test("Test A Zero Energy Falls Back To The Macros")
    func testAZeroEnergyFallsBackToTheMacros() {
        let screen = filledScreen(protein: 10, carbs: 0, fats: 0)
        screen.presenter.energyValue = 0

        #expect(screen.presenter.resolvedCalories == 40)
    }

    /// Worth stating because it is a genuine gap rather than an oversight to fix blindly: alcohol
    /// only ever reaches the log through the derived sum, so typing an energy figure discards it.
    /// The entry still has the calories the user asserted — it is the alcohol that goes nowhere.
    @Test("Test Alcohol Is Discarded When Energy Is Typed")
    func testAlcoholIsDiscardedWhenEnergyIsTyped() {
        let screen = filledScreen(protein: 0, carbs: 0, fats: 0)
        screen.presenter.alcoholValue = 10
        screen.presenter.energyValue = 50

        #expect(screen.presenter.resolvedCalories == 50)
    }

    // MARK: - What can be submitted

    @Test("Test Nothing Can Be Submitted Without A Name")
    func testNothingCanBeSubmittedWithoutAName() {
        let screen = filledScreen(name: "   ")

        #expect(!screen.presenter.canSubmit)
    }

    @Test("Test Nothing Can Be Submitted Without Any Energy")
    func testNothingCanBeSubmittedWithoutAnyEnergy() {
        let screen = filledScreen(protein: nil, carbs: nil, fats: nil)

        #expect(!screen.presenter.canSubmit)
    }

    @Test("Test A Named Entry With Energy Can Be Submitted")
    func testANamedEntryWithEnergyCanBeSubmitted() {
        let screen = filledScreen()

        #expect(screen.presenter.canSubmit)
    }

    /// The guard is on the action too, not only on the button's disabled state.
    @Test("Test Submitting An Incomplete Entry Does Nothing")
    func testSubmittingAnIncompleteEntryDoesNothing() {
        let screen = filledScreen(name: "")

        screen.presenter.onQuickAddPressed(delegate: screen.delegate)

        #expect(screen.box.picked.isEmpty)
    }

    // MARK: - Handing the item back to the picker

    @Test("Test Quick Add Hands The Item To The Picker")
    func testQuickAddHandsTheItemToThePicker() {
        let screen = filledScreen(name: "  Leftovers  ")

        screen.presenter.onQuickAddPressed(delegate: screen.delegate)

        let item = screen.box.picked.first
        #expect(item?.displayName == "Leftovers")
        #expect(item?.sourceType == .quickAdd)
        #expect(screen.interactor.trackedEventNames.contains("FoodItemQuickAddView_QuickAdd"))
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// There is no food behind the item and no weight to scale by, so it is one serving and its
    /// nutrients are absolute. A `resolvedGrams` here would invite something downstream to scale
    /// figures that are already final.
    @Test("Test A Quick Add Item Is One Unscaled Serving")
    func testAQuickAddItemIsOneUnscaledServing() {
        let screen = filledScreen(protein: 10, carbs: 20, fats: 5)

        screen.presenter.onQuickAddPressed(delegate: screen.delegate)

        let item = screen.box.picked.first
        #expect(item?.amount == 1)
        #expect(item?.unit == "serving")
        #expect(item?.resolvedGrams == nil)
        #expect(item?.resolvedMilliliters == nil)
        #expect(item?.nutrients[.calories] == 165)
    }

    @Test("Test The Macros Are Stored In Grams")
    func testTheMacrosAreStoredInGrams() {
        let screen = filledScreen(protein: 10, carbs: 20, fats: 5)

        screen.presenter.onQuickAddPressed(delegate: screen.delegate)

        let item = screen.box.picked.first
        #expect(item?.nutrients[.protein] == 10)
        #expect(item?.nutrients[.carbs] == 20)
        #expect(item?.nutrients[.fatTotal] == 5)
    }

    /// A macro typed in ounces is converted before it is stored, so the entry does not read as 1g
    /// of protein when an ounce was meant.
    @Test("Test Macros Entered In Ounces Are Stored As Grams")
    func testMacrosEnteredInOuncesAreStoredAsGrams() {
        let screen = filledScreen(protein: 1, carbs: 0, fats: 0)
        screen.presenter.weightUnit = .ounces

        screen.presenter.onQuickAddPressed(delegate: screen.delegate)

        let stored = screen.box.picked.first?.nutrients[.protein] ?? 0
        #expect(abs(stored - 28.349523125) < 0.0001)
    }

    /// A macro nobody entered is absent, not zero — the same rule the food form follows.
    @Test("Test Macros Left Blank Are Absent Not Zero")
    func testMacrosLeftBlankAreAbsentNotZero() {
        let screen = filledScreen(protein: 10, carbs: nil, fats: nil)

        screen.presenter.onQuickAddPressed(delegate: screen.delegate)

        let item = screen.box.picked.first
        #expect(item?.nutrients[.protein] == 10)
        #expect(item?.nutrients[.carbs] == nil)
        #expect(item?.nutrients[.fatTotal] == nil)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["FoodItemQuickAddView_Appear"])
    }
}
