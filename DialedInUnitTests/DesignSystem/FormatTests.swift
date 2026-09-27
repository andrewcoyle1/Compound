//
//  FormatTests.swift
//  DialedInUnitTests
//
//  Pins every `Format` function's output: rounding boundaries, kg/lb conversion, the en dash and
//  placeholder, and grouping in a non-English locale.
//

import Testing
import Foundation
@testable import DialedIn

struct FormatTests {

    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    @Test func kcalGroupsAndDropsDecimals() {
        #expect(Format.kcal(1850, locale: english) == "1,850 kcal")
        #expect(Format.kcal(1849.6, locale: english) == "1,850 kcal")
        #expect(Format.kcal(1849.4, locale: english) == "1,849 kcal")
        #expect(Format.kcal(0, locale: english) == "0 kcal")
    }

    @Test func kcalGroupsForTheLocale() {
        #expect(Format.kcal(1850, locale: german) == "1.850 kcal")
    }

    @Test func gramsDropDecimalsFromTenUp() {
        #expect(Format.grams(12.4, locale: english) == "12 g")
        #expect(Format.grams(10, locale: english) == "10 g")
        #expect(Format.grams(9.96, locale: english) == "10 g")
        #expect(Format.grams(9.94, locale: english) == "9.9 g")
        #expect(Format.grams(2.5, locale: english) == "2.5 g")
        #expect(Format.grams(3, locale: english) == "3 g")
        #expect(Format.grams(2.5, locale: german) == "2,5 g")
    }

    @Test func nutrientKeepsOneDecimalAtAnySize() {
        #expect(Format.nutrient(16.9, locale: english) == "16.9 g")
        #expect(Format.nutrient(16.94, locale: english) == "16.9 g")
        #expect(Format.nutrient(17, locale: english) == "17 g")
        #expect(Format.nutrient(120, unit: "mg", locale: english) == "120 mg")
        #expect(Format.nutrient(16.9, locale: german) == "16,9 g")
    }

    @Test func weightInKilograms() {
        #expect(Format.weight(kg: 82.5, unit: ExerciseWeightUnit.kilograms, locale: english) == "82.5 kg")
        #expect(Format.weight(kg: 100, unit: ExerciseWeightUnit.kilograms, locale: english) == "100 kg")
        #expect(Format.weight(kg: 82.5, unit: WeightUnitPreference.kilograms, locale: english) == "82.5 kg")
        #expect(Format.weight(kg: 82.5, unit: WeightUnitPreference.kilograms, locale: german) == "82,5 kg")
    }

    @Test func weightConvertsToPounds() {
        // 82.5 × 2.20462 = 181.88
        #expect(Format.weight(kg: 82.5, unit: ExerciseWeightUnit.pounds, locale: english) == "181.9 lb")
        #expect(Format.weight(kg: 82.5, unit: WeightUnitPreference.pounds, locale: english) == "181.9 lb")
        // 100 × 2.20462 = 220.46
        #expect(Format.weight(kg: 100, unit: WeightUnitPreference.pounds, locale: english) == "220.5 lb")
        #expect(Format.weight(kg: 1000, unit: WeightUnitPreference.pounds, locale: english) == "2,204.6 lb")
    }

    @Test func repsPluralise() {
        #expect(Format.reps(8, locale: english) == "8 reps")
        #expect(Format.reps(1, locale: english) == "1 rep")
        #expect(Format.reps(0, locale: english) == "0 reps")
    }

    @Test func repRangeUsesAnEnDash() {
        #expect(Format.repRange(8, 12, locale: english) == "8\u{2013}12")
    }

    @Test func durationSwitchesPatternAtAnHour() {
        #expect(Format.duration(270, locale: english) == "4:30")
        #expect(Format.duration(59.9, locale: english) == "0:59")
        #expect(Format.duration(3599, locale: english) == "59:59")
        #expect(Format.duration(3600, locale: english) == "1:00:00")
        #expect(Format.duration(3930, locale: english) == "1:05:30")
    }

    @Test func distanceInTheUsersUnit() {
        #expect(Format.distance(meters: 5200, unit: .kilometers, locale: english) == "5.2 km")
        #expect(Format.distance(meters: 5000, unit: .kilometers, locale: english) == "5 km")
        // 5,000 m × 0.000621371 = 3.107 mi
        #expect(Format.distance(meters: 5000, unit: .miles, locale: english) == "3.1 mi")
    }

    @Test func distanceInAnExercisesUnit() {
        #expect(Format.distance(meters: 400, exerciseUnit: .meters, locale: english) == "400 m")
        #expect(Format.distance(meters: 5000.4, exerciseUnit: .meters, locale: english) == "5,000 m")
        // 402.336 m is a quarter mile
        #expect(Format.distance(meters: 402.336, exerciseUnit: .miles, locale: english) == "0.25 mi")
    }

    @Test func percentFromAFraction() {
        #expect(Format.percent(0.45, locale: english) == "45%")
        #expect(Format.percent(1, locale: english) == "100%")
        #expect(Format.percent(0.004, locale: english) == "0%")
    }

    @Test func placeholderIsAnEmDash() {
        #expect(Format.placeholder == "\u{2014}")
    }
}
