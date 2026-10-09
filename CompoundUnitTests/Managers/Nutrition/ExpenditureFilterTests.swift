//
//  ExpenditureFilterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The [L, E, T] filter on its own: the arithmetic `ExpenditureEngine` replays day by day.
struct ExpenditureFilterTests {

    private let kcalPerKg = EnergyDensity.conventionalKcalPerKg

    @Test("Test The Filter Starts At The Prior With Its Uncertainty")
    func testTheFilterStartsAtThePriorWithItsUncertainty() {
        let filter = ExpenditureFilter(levelKg: 80, priorKcal: 2500)

        #expect(filter.levelKg == 80)
        #expect(filter.intakeKcal == 2500)
        #expect(filter.expenditureKcal == 2500)
        // The larger of 15% of the prior (375) and 340.
        #expect(abs(filter.expenditureSD - 375) < 1e-9)
    }

    @Test("Test Predicting Moves The Trend By The Energy Balance And Widens The Uncertainty")
    func testPredictingMovesTheTrendByTheEnergyBalanceAndWidensTheUncertainty() {
        var filter = ExpenditureFilter(levelKg: 80, priorKcal: 2500)
        filter.observeIntake(2000, sdKcal: 1)
        let before = filter.expenditureSD
        let level = filter.levelKg

        filter.predictOneDay(kcalPerKg: kcalPerKg)

        // E is now about 2,000 against T at 2,500: about 500/7700 kg a day down.
        #expect(filter.levelKg < level)
        #expect(abs((level - filter.levelKg) - (filter.expenditureKcal - filter.intakeKcal) / kcalPerKg) < 1e-9)
        #expect(filter.expenditureSD > before)
    }

    @Test("Test Logged Intake With A Flat Weight Pulls Expenditure To The Intake")
    func testLoggedIntakeWithAFlatWeightPullsExpenditureToTheIntake() {
        var filter = ExpenditureFilter(levelKg: 80, priorKcal: 2500)
        for _ in 0..<60 {
            filter.predictOneDay(kcalPerKg: kcalPerKg)
            filter.observeWeighIn(80)
            filter.observeIntake(2200, sdKcal: 400)
        }

        #expect(abs(filter.expenditureKcal - 2200) < 30)
        #expect(filter.expenditureSD < 120)
        #expect(abs(filter.dailyRate(kcalPerKg: kcalPerKg).kgPerDay) < 0.005)
    }

    @Test("Test A Gross Weigh-In Is Held Until The Next One Agrees")
    func testAGrossWeighInIsHeldUntilTheNextOneAgrees() {
        var filter = ExpenditureFilter(levelKg: 80, priorKcal: 2500)

        // 8.0 is a typo for 80: held, then dropped when 80 comes back.
        #expect(filter.observeWeighIn(8.0) == false)
        #expect(filter.levelKg == 80)
        #expect(filter.observeWeighIn(80.1) == true)

        // Two readings 5 kg up in a row are a real shift (a new scale): the second counts in full.
        #expect(filter.observeWeighIn(85) == false)
        #expect(filter.observeWeighIn(85.1) == true)
        #expect(filter.levelKg > 84)
    }

    @Test("Test An Odd Weigh-In Moves The Trend Less Than A Clean One Would")
    func testAnOddWeighInMovesTheTrendLessThanACleanOneWould() {
        var robust = ExpenditureFilter(levelKg: 80, priorKcal: 2500)
        for _ in 0..<20 {
            robust.predictOneDay(kcalPerKg: kcalPerKg)
            robust.observeWeighIn(80)
        }
        let settled = robust
        robust.observeWeighIn(82)
        let moved = robust.levelKg - settled.levelKg

        // The plain Kalman step for the same reading, without the Huber inflation.
        let noise = WeighInNoise.variance(levelKg: settled.levelKg)
        let plain = settled.covariance[0] / (settled.covariance[0] + noise) * 2

        #expect(moved > 0)
        #expect(moved < plain)
    }

    @Test("Test The Weigh-In Noise Is Half A Percent With A Floor")
    func testTheWeighInNoiseIsHalfAPercentWithAFloor() {
        #expect(abs(WeighInNoise.variance(levelKg: 100) - 0.25) < 1e-12)
        #expect(abs(WeighInNoise.variance(levelKg: 40) - 0.09) < 1e-12)
        #expect(WeighInNoise.isGrossError(innovation: 3.1, levelKg: 70))
        #expect(!WeighInNoise.isGrossError(innovation: 3.1, levelKg: 100))
    }
}
