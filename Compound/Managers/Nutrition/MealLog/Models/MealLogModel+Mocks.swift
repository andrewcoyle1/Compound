//
//  MealLogModel+Mocks.swift
//  Compound
//
//  Created by Andrew Coyle on 16/09/2026.
//

import Foundation

// MARK: - Meal logs

extension MealLogModel {

    static var mock: MealLogModel {
        let today = Date()
        return MealLogModel(
            mealId: UUID().uuidString,
            authorId: UserModel.mock.userId,
            dayKey: today.dayKey,
            date: today,
            items: MealItemModel.mocks,
            notes: "Had a great breakfast!"
        )
    }

    /// Two weeks of logged meals, working backwards from today.
    static var mocks: [MealLogModel] {
        logs(daysBack: 14, authorId: UserModel.mock.userId)
    }

    /// The current week, Monday to Sunday, keyed by `dayKey`.
    static var mockWeekMealsByDay: [String: [MealLogModel]] {
        weekByDay(authorId: "mock-user")
    }

    /// The current week, Monday to Sunday, keyed by `dayKey`.
    ///
    /// Every day used to be the same oatmeal breakfast, chicken-and-rice lunch and salmon
    /// dinner, so the nutrition screens showed identical totals for seven days running and no
    /// meal ever repeated a food from the library. Days now draw from `PreviewMealLibrary`,
    /// which rotates through fourteen breakfasts, lunches, dinners and snacks.
    static var previewWeekMealsByDay: [String: [MealLogModel]] {
        weekByDay(authorId: "preview-user")
    }

    private static func logs(daysBack: Int, authorId: String) -> [MealLogModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<daysBack).flatMap { daysAgo -> [MealLogModel] in
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return [] }
            return meals(on: day, dayIndex: daysAgo, authorId: authorId, skippingFuture: true)
        }
    }

    private static func weekByDay(authorId: String) -> [String: [MealLogModel]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let daysFromMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today

        var mealsByDay: [String: [MealLogModel]] = [:]
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            mealsByDay[day.dayKey] = meals(on: day, dayIndex: offset, authorId: authorId, skippingFuture: false)
        }
        return mealsByDay
    }

    private static func meals(on day: Date, dayIndex: Int, authorId: String, skippingFuture: Bool) -> [MealLogModel] {
        let calendar = Calendar.current

        return PreviewMealLibrary.day(dayIndex).compactMap { meal in
            guard let date = calendar.date(bySettingHour: meal.hour, minute: meal.minute, second: 0, of: day) else {
                return nil
            }
            if skippingFuture && date > .now { return nil }

            return MealLogModel(
                mealId: UUID().uuidString,
                authorId: authorId,
                dayKey: day.dayKey,
                date: date,
                items: meal.items(),
                notes: meal.note
            )
        }
    }
}

// MARK: - Library

/// The foods and meals the mock logs are built from.
///
/// Items are built fresh on each call so every logged item gets its own id, and nutrients scale
/// with the portion — a 300g serving of something described per 100g reads as three times the
/// calories rather than repeating the reference values.
private enum PreviewMealLibrary {

    /// `items` is a closure so each logged item gets a fresh id every time a day is built.
    struct Meal: Sendable {
        let hour: Int
        let minute: Int
        let note: String?
        let items: @Sendable () -> [MealItemModel]
    }

    /// A day's meals: three mains, plus snacks on some days, in different combinations each day.
    static func day(_ index: Int) -> [Meal] {
        var meals = [
            breakfasts[index % breakfasts.count],
            lunches[(index * 2 + 1) % lunches.count],
            dinners[(index * 3 + 2) % dinners.count]
        ]

        // Not every day is logged the same way — some carry a snack or two, some neither.
        if index % 2 == 0 {
            meals.append(snacks[index % snacks.count])
        }
        if index % 3 == 0 {
            meals.append(snacks[(index * 2 + 3) % snacks.count])
        }

        return meals.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    // MARK: Breakfasts

    static let breakfasts: [Meal] = [
        Meal(hour: 7, minute: 10, note: "Pre-training breakfast.", items: {
            [Food.oats.item(80), Food.banana.item(1), Food.peanutButter.item(20), Food.milk.item(200)]
        }),
        Meal(hour: 8, minute: 5, note: nil, items: {
            [Food.eggs.item(3), Food.sourdough.item(2), Food.avocado.item(0.5), Food.coffee.item(1)]
        }),
        Meal(hour: 6, minute: 45, note: "Early start before work.", items: {
            [Food.greekYogurt.item(200), Food.blueberries.item(100), Food.honey.item(15), Food.almonds.item(20)]
        }),
        Meal(hour: 9, minute: 20, note: nil, items: {
            [Food.proteinSmoothie.item(1), Food.apple.item(1)]
        }),
        Meal(hour: 8, minute: 30, note: nil, items: {
            [Food.eggWhites.item(200), Food.sourdough.item(2), Food.smokedSalmon.item(60), Food.coffee.item(1)]
        }),
        Meal(hour: 7, minute: 50, note: "Rest day, bigger breakfast.", items: {
            [Food.oats.item(100), Food.wheyProtein.item(30), Food.blueberries.item(80), Food.almondButter.item(20)]
        }),
        Meal(hour: 10, minute: 0, note: "Late one after a lie-in.", items: {
            [Food.cottageCheese.item(200), Food.rye.item(2), Food.honey.item(10), Food.orangeJuice.item(250)]
        })
    ]

    // MARK: Lunches

    static let lunches: [Meal] = [
        Meal(hour: 12, minute: 45, note: nil, items: {
            [Food.chickenBreast.item(200), Food.brownRice.item(180), Food.broccoli.item(120), Food.oliveOil.item(10)]
        }),
        Meal(hour: 13, minute: 15, note: "Desk lunch.", items: {
            [Food.tuna.item(120), Food.wholewheatWrap.item(1), Food.saladMix.item(80), Food.hummus.item(40)]
        }),
        Meal(hour: 12, minute: 30, note: nil, items: {
            [Food.beefMince.item(150), Food.pasta.item(120), Food.tomatoSauce.item(150), Food.parmesan.item(20)]
        }),
        Meal(hour: 14, minute: 0, note: "Lunch out.", items: {
            [Food.chickenBurrito.item(1), Food.tortillaChips.item(40)]
        }),
        Meal(hour: 13, minute: 0, note: nil, items: {
            [Food.tofu.item(200), Food.noodles.item(150), Food.stirFryVeg.item(150), Food.soySauce.item(15)]
        }),
        Meal(hour: 12, minute: 15, note: nil, items: {
            [Food.eggs.item(2), Food.sweetPotato.item(250), Food.saladMix.item(100), Food.feta.item(40)]
        }),
        Meal(hour: 13, minute: 40, note: "Leftovers.", items: {
            [Food.salmonFillet.item(150), Food.quinoa.item(150), Food.asparagus.item(120)]
        })
    ]

    // MARK: Dinners

    static let dinners: [Meal] = [
        Meal(hour: 19, minute: 15, note: "Cooked at home.", items: {
            [Food.salmonFillet.item(180), Food.jasmineRice.item(200), Food.asparagus.item(150), Food.oliveOil.item(10)]
        }),
        Meal(hour: 20, minute: 0, note: nil, items: {
            [Food.chickenBreast.item(220), Food.sweetPotato.item(300), Food.broccoli.item(150)]
        }),
        Meal(hour: 18, minute: 45, note: nil, items: {
            [Food.beefSteak.item(250), Food.potatoes.item(300), Food.greenBeans.item(150), Food.butter.item(10)]
        }),
        Meal(hour: 19, minute: 30, note: "Takeaway night.", items: {
            [Food.thaiGreenCurry.item(1), Food.jasmineRice.item(200)]
        }),
        Meal(hour: 20, minute: 15, note: nil, items: {
            [Food.porkLoin.item(200), Food.pasta.item(140), Food.tomatoSauce.item(150), Food.parmesan.item(25)]
        }),
        Meal(hour: 19, minute: 0, note: nil, items: {
            [Food.tofu.item(250), Food.brownRice.item(180), Food.stirFryVeg.item(200), Food.soySauce.item(20)]
        }),
        Meal(hour: 21, minute: 0, note: "Late dinner after training.", items: {
            [Food.chickenThigh.item(220), Food.couscous.item(180), Food.saladMix.item(120), Food.feta.item(40)]
        })
    ]

    // MARK: Snacks

    static let snacks: [Meal] = [
        Meal(hour: 16, minute: 0, note: nil, items: { [Food.proteinBar.item(1), Food.coffee.item(1)] }),
        Meal(hour: 10, minute: 30, note: nil, items: { [Food.apple.item(1), Food.almonds.item(25)] }),
        Meal(hour: 22, minute: 0, note: "Before bed.", items: { [Food.caseinShake.item(1)] }),
        Meal(hour: 15, minute: 30, note: nil, items: { [Food.greekYogurt.item(150), Food.blueberries.item(80)] }),
        Meal(hour: 21, minute: 30, note: nil, items: { [Food.darkChocolate.item(30), Food.popcorn.item(25)] }),
        Meal(hour: 11, minute: 0, note: nil, items: { [Food.riceCakes.item(3), Food.peanutButter.item(20)] })
    ]
}

// MARK: - Foods

/// One food as it is logged. `nutrients` describe `referenceAmount` of `unit`, and `item(_:)`
/// scales from there.
private struct PreviewFood {
    let id: String
    let name: String
    let sourceType: MealItemSourceType
    let unit: String
    let referenceAmount: Double
    let referenceGrams: Double?
    let referenceMilliliters: Double?
    let nutrients: NutrientMap

    func item(_ amount: Double) -> MealItemModel {
        let multiplier = referenceAmount == 0 ? 1 : amount / referenceAmount
        return MealItemModel(
            itemId: UUID().uuidString,
            sourceType: sourceType,
            sourceId: id,
            displayName: name,
            amount: amount,
            unit: unit,
            resolvedGrams: referenceGrams.map { $0 * multiplier },
            resolvedMilliliters: referenceMilliliters.map { $0 * multiplier },
            nutrients: nutrients.mapValues { $0 * multiplier }
        )
    }
}

/// The macro and micro figures for a food, grouped so the factories below stay within a
/// sensible parameter count.
private struct PreviewMacros {
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    var satFat: Double = 0
    var fibre: Double = 0
    var sugar: Double = 0
    var sodium: Double = 0

    var nutrients: NutrientMap {
        [
            .calories: kcal,
            .protein: protein,
            .carbs: carbs,
            .fatTotal: fat,
            .fatSaturated: satFat,
            .fiber: fibre,
            .sugar: sugar,
            .sodiumMg: sodium
        ]
    }
}

extension PreviewFood {

    /// Per 100g, the way nutrition labels are written.
    static func per100g(_ id: String, _ name: String, _ macros: PreviewMacros) -> PreviewFood {
        PreviewFood(
            id: id,
            name: name,
            sourceType: .ingredient,
            unit: "g",
            referenceAmount: 100,
            referenceGrams: 100,
            referenceMilliliters: nil,
            nutrients: macros.nutrients
        )
    }

    /// Per item — an egg, a banana, a wrap.
    static func perItem(_ id: String, _ name: String, grams: Double, _ macros: PreviewMacros) -> PreviewFood {
        PreviewFood(
            id: id,
            name: name,
            sourceType: .ingredient,
            unit: "unit",
            referenceAmount: 1,
            referenceGrams: grams,
            referenceMilliliters: nil,
            nutrients: macros.nutrients
        )
    }

    /// Per 100ml, for drinks logged by volume.
    static func perMillilitres(_ id: String, _ name: String, _ macros: PreviewMacros) -> PreviewFood {
        PreviewFood(
            id: id,
            name: name,
            sourceType: .ingredient,
            unit: "ml",
            referenceAmount: 100,
            referenceGrams: nil,
            referenceMilliliters: 100,
            nutrients: macros.nutrients
        )
    }

    /// Per serving of a recipe or a bought meal.
    static func perServing(_ id: String, _ name: String, _ macros: PreviewMacros, millilitres: Double? = nil) -> PreviewFood {
        PreviewFood(
            id: id,
            name: name,
            sourceType: .recipe,
            unit: "serving",
            referenceAmount: 1,
            referenceGrams: nil,
            referenceMilliliters: millilitres,
            nutrients: macros.nutrients
        )
    }
}

/// The food library the meals above are assembled from. Values are rounded real-world figures.
private enum Food {

    // Breakfast staples
    static let oats = PreviewFood.per100g("ing-oats", "Oats", PreviewMacros(kcal: 379, protein: 13, carbs: 67, fat: 7, satFat: 1.2, fibre: 10, sugar: 1))
    static let banana = PreviewFood.perItem("ing-banana", "Banana", grams: 120, PreviewMacros(kcal: 105, protein: 1.3, carbs: 27, fat: 0.4, fibre: 3, sugar: 14))
    static let blueberries = PreviewFood.per100g("ing-blueberries", "Blueberries", PreviewMacros(kcal: 57, protein: 0.7, carbs: 14, fat: 0.3, fibre: 2.4, sugar: 10))
    static let greekYogurt = PreviewFood.per100g("ing-greek-yogurt", "Greek Yogurt", PreviewMacros(kcal: 90, protein: 12, carbs: 5, fat: 2.3, satFat: 1.5, sugar: 5))
    static let cottageCheese = PreviewFood.per100g("ing-cottage-cheese", "Cottage Cheese", PreviewMacros(kcal: 98, protein: 11, carbs: 3.4, fat: 4.3, satFat: 1.7, sodium: 364))
    static let honey = PreviewFood.per100g("ing-honey", "Honey", PreviewMacros(kcal: 304, protein: 0.3, carbs: 82, fat: 0, sugar: 82))
    static let eggs = PreviewFood.perItem("ing-egg", "Egg", grams: 58, PreviewMacros(kcal: 78, protein: 6.3, carbs: 0.6, fat: 5.3, satFat: 1.6, sodium: 62))
    static let eggWhites = PreviewFood.per100g("ing-egg-white", "Egg Whites", PreviewMacros(kcal: 52, protein: 11, carbs: 0.7, fat: 0.2, sodium: 166))
    static let sourdough = PreviewFood.perItem("ing-sourdough", "Sourdough Toast", grams: 50, PreviewMacros(kcal: 130, protein: 5, carbs: 25, fat: 0.8, fibre: 1.5, sodium: 290))
    static let rye = PreviewFood.perItem("ing-rye", "Rye Bread", grams: 45, PreviewMacros(kcal: 110, protein: 4, carbs: 21, fat: 1, fibre: 3, sodium: 240))
    static let smokedSalmon = PreviewFood.per100g("ing-smoked-salmon", "Smoked Salmon", PreviewMacros(kcal: 117, protein: 18, carbs: 0, fat: 4.3, satFat: 0.9, sodium: 780))
    static let avocado = PreviewFood.perItem("ing-avocado", "Avocado", grams: 200, PreviewMacros(kcal: 320, protein: 4, carbs: 17, fat: 29, satFat: 4.2, fibre: 13))

    // Proteins
    static let chickenBreast = PreviewFood.per100g("ing-chicken-breast", "Chicken Breast", PreviewMacros(kcal: 165, protein: 31, carbs: 0, fat: 3.6, satFat: 1, sodium: 74))
    static let chickenThigh = PreviewFood.per100g("ing-chicken-thigh", "Chicken Thigh", PreviewMacros(kcal: 209, protein: 26, carbs: 0, fat: 11, satFat: 3, sodium: 84))
    static let beefMince = PreviewFood.per100g("ing-beef-mince", "Beef Mince (5%)", PreviewMacros(kcal: 137, protein: 21, carbs: 0, fat: 5, satFat: 2.3, sodium: 66))
    static let beefSteak = PreviewFood.per100g("ing-sirloin", "Sirloin Steak", PreviewMacros(kcal: 206, protein: 29, carbs: 0, fat: 9.6, satFat: 3.8, sodium: 55))
    static let porkLoin = PreviewFood.per100g("ing-pork-loin", "Pork Loin", PreviewMacros(kcal: 190, protein: 27, carbs: 0, fat: 9, satFat: 3.1, sodium: 60))
    static let salmonFillet = PreviewFood.per100g("ing-salmon", "Salmon Fillet", PreviewMacros(kcal: 208, protein: 20, carbs: 0, fat: 13, satFat: 3.1, sodium: 59))
    static let tuna = PreviewFood.per100g("ing-tuna", "Tuna", PreviewMacros(kcal: 116, protein: 26, carbs: 0, fat: 1, satFat: 0.3, sodium: 320))
    static let tofu = PreviewFood.per100g("ing-tofu", "Firm Tofu", PreviewMacros(kcal: 144, protein: 17, carbs: 3, fat: 9, satFat: 1.3, fibre: 2))
    static let wheyProtein = PreviewFood.per100g("ing-whey", "Whey Protein", PreviewMacros(kcal: 400, protein: 80, carbs: 7, fat: 6, satFat: 3, sodium: 300))

    // Carbs and sides
    static let brownRice = PreviewFood.per100g("ing-brown-rice", "Brown Rice (cooked)", PreviewMacros(kcal: 112, protein: 2.6, carbs: 24, fat: 0.9, fibre: 1.8))
    static let jasmineRice = PreviewFood.per100g("ing-jasmine-rice", "Jasmine Rice (cooked)", PreviewMacros(kcal: 130, protein: 2.7, carbs: 28, fat: 0.3))
    static let pasta = PreviewFood.per100g("ing-pasta", "Pasta (cooked)", PreviewMacros(kcal: 158, protein: 5.8, carbs: 31, fat: 0.9, fibre: 1.8))
    static let noodles = PreviewFood.per100g("ing-noodles", "Egg Noodles (cooked)", PreviewMacros(kcal: 138, protein: 4.5, carbs: 25, fat: 2.1, sodium: 180))
    static let couscous = PreviewFood.per100g("ing-couscous", "Couscous (cooked)", PreviewMacros(kcal: 112, protein: 3.8, carbs: 23, fat: 0.2, fibre: 1.4))
    static let quinoa = PreviewFood.per100g("ing-quinoa", "Quinoa (cooked)", PreviewMacros(kcal: 120, protein: 4.4, carbs: 21, fat: 1.9, fibre: 2.8))
    static let sweetPotato = PreviewFood.per100g("ing-sweet-potato", "Sweet Potato", PreviewMacros(kcal: 86, protein: 1.6, carbs: 20, fat: 0.1, fibre: 3, sugar: 4.2))
    static let potatoes = PreviewFood.per100g("ing-potato", "Potatoes", PreviewMacros(kcal: 77, protein: 2, carbs: 17, fat: 0.1, fibre: 2.2))
    static let wholewheatWrap = PreviewFood.perItem("ing-wrap", "Wholewheat Wrap", grams: 64, PreviewMacros(kcal: 190, protein: 6, carbs: 32, fat: 4, fibre: 4, sodium: 390))
    static let riceCakes = PreviewFood.perItem("ing-rice-cake", "Rice Cake", grams: 9, PreviewMacros(kcal: 35, protein: 0.7, carbs: 7.3, fat: 0.3, sodium: 26))

    // Vegetables and extras
    static let broccoli = PreviewFood.per100g("ing-broccoli", "Broccoli", PreviewMacros(kcal: 35, protein: 2.8, carbs: 7, fat: 0.4, fibre: 2.6, sugar: 1.7))
    static let asparagus = PreviewFood.per100g("ing-asparagus", "Asparagus", PreviewMacros(kcal: 20, protein: 2.2, carbs: 3.9, fat: 0.1, fibre: 2.1))
    static let greenBeans = PreviewFood.per100g("ing-green-beans", "Green Beans", PreviewMacros(kcal: 31, protein: 1.8, carbs: 7, fat: 0.1, fibre: 3.4))
    static let saladMix = PreviewFood.per100g("ing-salad", "Mixed Salad", PreviewMacros(kcal: 17, protein: 1.4, carbs: 2.9, fat: 0.2, fibre: 1.6))
    static let stirFryVeg = PreviewFood.per100g("ing-stir-fry-veg", "Stir-Fry Vegetables", PreviewMacros(kcal: 42, protein: 2, carbs: 8, fat: 0.4, fibre: 2.4))
    static let hummus = PreviewFood.per100g("ing-hummus", "Hummus", PreviewMacros(kcal: 166, protein: 8, carbs: 14, fat: 10, satFat: 1.5, fibre: 6, sodium: 379))
    static let feta = PreviewFood.per100g("ing-feta", "Feta", PreviewMacros(kcal: 264, protein: 14, carbs: 4.1, fat: 21, satFat: 15, sodium: 917))
    static let parmesan = PreviewFood.per100g("ing-parmesan", "Parmesan", PreviewMacros(kcal: 392, protein: 36, carbs: 3.2, fat: 26, satFat: 17, sodium: 1529))
    static let tomatoSauce = PreviewFood.per100g("ing-tomato-sauce", "Tomato Sauce", PreviewMacros(kcal: 55, protein: 1.8, carbs: 9, fat: 1.5, fibre: 1.9, sugar: 6, sodium: 430))
    static let oliveOil = PreviewFood.per100g("ing-olive-oil", "Olive Oil", PreviewMacros(kcal: 884, protein: 0, carbs: 0, fat: 100, satFat: 14))
    static let butter = PreviewFood.per100g("ing-butter", "Butter", PreviewMacros(kcal: 717, protein: 0.9, carbs: 0.1, fat: 81, satFat: 51, sodium: 643))
    static let soySauce = PreviewFood.per100g("ing-soy-sauce", "Soy Sauce", PreviewMacros(kcal: 53, protein: 8, carbs: 4.9, fat: 0.6, sodium: 5493))
    static let peanutButter = PreviewFood.per100g("ing-peanut-butter", "Peanut Butter", PreviewMacros(kcal: 588, protein: 25, carbs: 20, fat: 50, satFat: 10, fibre: 6, sugar: 9, sodium: 430))
    static let almondButter = PreviewFood.per100g("ing-almond-butter", "Almond Butter", PreviewMacros(kcal: 614, protein: 21, carbs: 19, fat: 56, satFat: 4.2, fibre: 10))
    static let almonds = PreviewFood.per100g("ing-almonds", "Almonds", PreviewMacros(kcal: 579, protein: 21, carbs: 22, fat: 50, satFat: 3.8, fibre: 12, sugar: 4.4))

    // Snacks and drinks
    static let apple = PreviewFood.perItem("ing-apple", "Apple", grams: 180, PreviewMacros(kcal: 95, protein: 0.5, carbs: 25, fat: 0.3, fibre: 4.4, sugar: 19))
    static let darkChocolate = PreviewFood.per100g("ing-dark-chocolate", "Dark Chocolate", PreviewMacros(kcal: 546, protein: 5, carbs: 61, fat: 31, satFat: 18, fibre: 7, sugar: 48))
    static let popcorn = PreviewFood.per100g("ing-popcorn", "Popcorn", PreviewMacros(kcal: 387, protein: 13, carbs: 78, fat: 4.5, fibre: 15, sodium: 8))
    static let tortillaChips = PreviewFood.per100g("ing-tortilla-chips", "Tortilla Chips", PreviewMacros(kcal: 489, protein: 7, carbs: 63, fat: 23, satFat: 3, fibre: 5, sodium: 400))
    static let milk = PreviewFood.perMillilitres("ing-milk", "Semi-Skimmed Milk", PreviewMacros(kcal: 50, protein: 3.5, carbs: 4.8, fat: 1.8, satFat: 1.1, sugar: 4.8, sodium: 44))
    static let orangeJuice = PreviewFood.perMillilitres("ing-orange-juice", "Orange Juice", PreviewMacros(kcal: 45, protein: 0.7, carbs: 10.4, fat: 0.2, sugar: 8.4))
    static let coffee = PreviewFood.perServing("ing-latte", "Latte", PreviewMacros(kcal: 120, protein: 8, carbs: 12, fat: 4.5, satFat: 2.8, sugar: 11, sodium: 100), millilitres: 240)

    // Prepared meals and shakes
    static let proteinSmoothie = PreviewFood.perServing("recipe-smoothie", "Protein Smoothie", PreviewMacros(kcal: 380, protein: 34, carbs: 42, fat: 8, satFat: 2, fibre: 5, sugar: 28), millilitres: 400)
    static let caseinShake = PreviewFood.perServing("recipe-casein", "Casein Shake", PreviewMacros(kcal: 220, protein: 32, carbs: 12, fat: 4, satFat: 2), millilitres: 350)
    static let proteinBar = PreviewFood.perServing("recipe-protein-bar", "Protein Bar", PreviewMacros(kcal: 230, protein: 20, carbs: 22, fat: 7, satFat: 3.5, fibre: 8, sugar: 2, sodium: 210))
    static let chickenBurrito = PreviewFood.perServing("recipe-burrito", "Chicken Burrito", PreviewMacros(kcal: 720, protein: 42, carbs: 78, fat: 26, satFat: 8, fibre: 9, sodium: 1400))
    static let thaiGreenCurry = PreviewFood.perServing("recipe-green-curry", "Thai Green Curry", PreviewMacros(kcal: 540, protein: 32, carbs: 24, fat: 34, satFat: 21, fibre: 4, sodium: 1150))
}
