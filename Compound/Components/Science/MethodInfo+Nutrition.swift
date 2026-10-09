//
//  MethodInfo+Nutrition.swift
//  Compound
//
//  The formula expenditure estimate, the nutrition targets built on it, and the weight-goal
//  timeline. The code these describe is `FormulaExpenditure`, `NutritionTargets`,
//  `NutritionManager.goalTarget` and `GoalTimeline`; keep the formulas here in step with them.
//

import Foundation

// The user-facing text is one string literal per field so the string catalog extracts it whole,
// which puts those lines over the length limit; as in Citations.swift, the rule is off here only.
// swiftlint:disable line_length
extension MethodInfo {
    static var allNutrition: [MethodInfo] {
        [
            formulaExpenditure,
            restingMetabolicRate,
            thermicEffectOfFood,
            proteinTarget,
            macroSplit,
            calorieFloor,
            calorieCycling,
            weightChangeRate,
            goalTimeline,
            goalProgress
        ]
    }

    // MARK: - Expenditure

    static let formulaExpenditure = MethodInfo(
        id: "formula-expenditure",
        title: "Formula Expenditure Estimate",
        summary: "Your resting calories are multiplied by a physical activity level (PAL) chosen from your activity answer. This is the starting estimate: once you log food and weigh in, Compound replaces it with one worked out from your own data. The activity levels sit inside the ranges measured in free-living adults, and your workouts are part of the activity answer rather than an extra amount on top, because total expenditure does not keep rising with exercise in a straight line.",
        formula: "TDEE = RMR × PAL\nPAL: sedentary 1.40, light 1.55, moderate 1.70, active 1.85, very active 2.00\nTDEE ≥ 1,000 kcal\n(FAO/WHO/UNU bands: sedentary or light 1.40–1.69, active 1.70–1.99, vigorous 2.00–2.40)",
        limitations: "A formula estimate for one person is typically off by a few hundred calories a day. The resting equation alone is within 10% for about three people in four, and the activity level is a self-reported category. Expenditure falls a little with age after about 60, which these equations only partly capture.",
        ownChoices: "The exact PAL for each answer is Compound's choice within the published bands. The 1,000 kcal minimum is a safeguard, not a physiological figure. Missing figures are read as 70 kg, 175 cm and 30 years, and a missing sex as the midpoint of the male and female equations.",
        citations: [.fao2004, .pontzer2016, .pontzer2012, .boning2018, .pontzer2021, .frankenfield2005, .madden2016]
    )

    static let restingMetabolicRate = MethodInfo(
        id: "resting-metabolic-rate",
        title: "Resting Calories",
        summary: "The calories your body burns at rest, from your weight, height, age and sex. Compound uses the Mifflin-St Jeor equation unless you choose another in Expenditure settings. With a logged body fat percentage and the body-fat aware method (or Cunningham chosen), it uses the Cunningham equation, which works from fat-free mass and suits lean, muscular people better.",
        formula: "Mifflin-St Jeor: 10 × kg + 6.25 × cm − 5 × age + s\n  s = +5 (male), −161 (female), −78 (not stated)\nHarris-Benedict (revised):\n  male 88.362 + 13.397 × kg + 4.799 × cm − 5.677 × age\n  female 447.593 + 9.247 × kg + 3.098 × cm − 4.330 × age\nCunningham: 500 + 22 × fat-free kg\n  fat-free kg = kg × (1 − body fat % ÷ 100)",
        limitations: "Mifflin-St Jeor predicts within 10% of measured resting rate for about three people in four, so roughly one in four is further out. Weight-based equations tend to underestimate resting rate in muscular people. Cunningham is only as good as the body fat reading: every kilogram of fat-free mass misjudged moves it by 22 kcal, and home scales can be several percentage points out.",
        ownChoices: "The −78 used when sex is not stated is the midpoint of the male and female terms, not a published constant, and makes the estimate less certain. Age is never read below 14, though the equations were built on adults.",
        citations: [.mifflin1990, .frankenfield2005, .madden2016, .roza1984, .cunningham1980, .oneill2023, .tinsley2019, .tenHaaf2014]
    )

    static let thermicEffectOfFood = MethodInfo(
        id: "thermic-effect-of-food",
        title: "Calories Spent Digesting Food",
        summary: "Digesting and storing food costs about 10% of the energy you take in on a mixed diet. Compound shows it as 10% of your estimated expenditure, then counts the rest above resting as daily activity and exercise.",
        formula: "Digestion = 0.10 × TDEE\nActivity = TDEE − resting − digestion",
        limitations: "The share varies from about 5% to 15% between people and diets: protein costs much more to digest than fat. The split is for illustration; only the total is used to set targets.",
        citations: [.westerterp2004]
    )

    // MARK: - Targets

    static let proteinTarget = MethodInfo(
        id: "protein-target",
        title: "Protein Target",
        summary: "Protein is set in grams per kilogram for the level you chose. Gains in muscle from training level off at around 1.6 g/kg for most people, and lean people in a calorie deficit may benefit from more. If your BMI is 30 or over, it is worked out on a reference weight rather than your full weight, because fat mass needs little protein. People aged 65 and over never get less than 1.2 g/kg.",
        formula: "g/kg: low 1.6, moderate 2.0, high 2.2, very high 2.6\nprotein = g/kg × reference weight\nreference weight = weight, if BMI < 30\n  otherwise min(weight, max(30 × height(m)², goal weight))\nage ≥ 65: g/kg ≥ 1.2",
        limitations: "The 1.6 g/kg plateau is an average, with a confidence interval reaching about 2.2 g/kg. No trials have measured protein needs in obesity, so the reference-weight rule follows clinical practice rather than a trial. Higher intakes showed no harm to kidney function in healthy adults, but people with kidney disease should ask their doctor.",
        ownChoices: "The four tiers and the reference-weight formula, max(BMI 30 weight, goal weight), are Compound's choices. No guideline recommends 2.6 g/kg for everyone; it is offered for lean people cutting hard.",
        citations: [.morton2018, .nunes2022, .helms2014, .devries2018, .weijs2025, .dekker2022, .bauer2013, .thomas2016]
    )

    static let macroSplit = MethodInfo(
        id: "macro-split",
        title: "Fat and Carbohydrate Split",
        summary: "After protein, the rest of each day's calories are split by your diet choice: balanced gives 30% of calories to fat, low fat 20%, low carb gives 20% to carbs, and keto caps carbs at about 30 g. Fat never drops below 20% of calories or 0.5 g per kilogram, whichever is more, and carbs take whatever is left.",
        formula: "remaining = calories − 4 × protein g\nfat kcal: balanced 0.30 × calories, low fat 0.20 × calories,\n  low carb remaining − 0.20 × calories, keto remaining − min(4 × 30, remaining)\nfat kcal = min(remaining, max(fat kcal, 9 × 0.5 × reference kg, 0.20 × calories))\ncarb g = (remaining − fat kcal) ÷ 4\nAtwater factors: protein 4, carbs 4, fat 9 kcal/g",
        limitations: "The fat floor of 0.5 g/kg is expert opinion rather than a tested threshold. Carbohydrate has no floor because studies found it generally did not limit strength training, though endurance athletes may need more.",
        ownChoices: "The 30% balanced share and the 30 g keto default (inside the usual 20–50 g definition) are Compound's choices.",
        citations: [.iom2005, .thomas2016, .whittaker2021, .iraki2019, .feinman2015, .henselmans2022, .fao2003]
    )

    static let calorieFloor = MethodInfo(
        id: "calorie-floor",
        title: "Calorie Floor",
        summary: "Your daily target never goes below 1,200 calories for women or 1,500 for men, or 1,350 if you'd rather not say, however low your expenditure or fast your goal. A goal's deficit is also capped at a quarter of your expenditure. Diets of 800 calories or less are meant to be followed under medical supervision, so Compound doesn't offer them.",
        formula: "floor = 1,200 (female), 1,500 (male), 1,350 (not stated)\ntarget = max(floor, expenditure − min(goal deficit, 0.25 × expenditure))",
        limitations: "1,200 and 1,500 kcal are where the obesity guideline's suggested diet ranges start for women and men. They are conventions, not the least a body can safely run on, and someone eating near them may need more for training.",
        ownChoices: "1,350 for an unstated sex is the midpoint, and the 25% deficit cap is Compound's own; neither comes from a study.",
        citations: [.jensen2014, .niddk, .niddk2025]
    )

    static let calorieCycling = MethodInfo(
        id: "calorie-cycling",
        title: "Calorie Distribution",
        summary: "Even gives every day the same target. Varied gives one higher day for each training day in your program, spread as evenly as the week allows, and lowers the other days so the weekly total stays the same. Your program is a queue rather than a calendar, so the higher days aren't tied to the days you actually train: treat them as a preference you can swap around.",
        formula: "N = training days in the program (1–6)\nbonus = min(0.10, 0.15 × (7 − N) ÷ N)\nhigh day = target × (1 + bonus)\nother days = target × (1 − bonus × N ÷ (7 − N))\nweekly total = 7 × target",
        limitations: "No study supports fixed high days. Trials of refeed days and diet breaks are small, and a reanalysis of the refeed trial found no clear difference in lean mass. Varying calories mainly helps if it makes the plan easier to follow.",
        ownChoices: "The 10% bonus, the 85% lowest day and the even spread are Compound's choices.",
        citations: [.campbell2020, .peos2021]
    )

    // MARK: - Weight goal

    static let weightChangeRate = MethodInfo(
        id: "weight-change-rate",
        title: "Weekly Rate",
        summary: "Rates are set as a share of your body weight, since half a kilogram a week asks far more of a 60 kg person than of a 120 kg one. Losing ranges from 0.25% to 1% of body weight a week, starting at 0.5% if your BMI is under 25 and 0.75% otherwise. Gaining starts at 0.25% a week. Compound warns above 0.75% a week when a lean person is losing, and above 0.5% when gaining. The daily calorie change uses 7,700 kcal per kilogram.",
        formula: "lose: 0.25% to min(1% × weight, 1.5 kg) a week\n  default 0.5% (BMI < 25) or 0.75%; warning above 0.75% if BMI < 25\ngain: 0.1% to min(1% × weight, 1.5 kg) a week\n  default 0.25%; warning above 0.5%\ndaily kcal = weekly kg × 7,700 ÷ 7",
        limitations: "The loss band comes from guidance for lean athletes; in people with obesity, faster and slower loss led to similar regain. For gaining, a larger surplus in trained lifters added fat but not more muscle. 7,700 kcal/kg is an average: lean people lose more lean tissue per kilogram, which holds less energy.",
        ownChoices: "The defaults, the BMI 25 cut-off, the 0.75% warning, the 0.1% gain minimum and the 1.5 kg ceiling are Compound's choices.",
        citations: [.helms2014b, .garthe2011, .purcell2014, .iraki2019, .helms2023, .wishnofsky1958, .hall2008]
    )

    static let goalTimeline = MethodInfo(
        id: "goal-timeline",
        title: "Goal Timeline",
        summary: "The estimate is the distance to your goal divided by your weekly rate, rounded up to whole weeks. The weekly check-in adjusts your target to keep that rate, which means the target steps down as you lose (or up as you gain): expenditure changes by roughly 24 kcal a day for each kilogram. The timeline assumes you follow those adjustments.",
        formula: "weeks = ⌈|target weight − current weight| ÷ weekly rate⌉\ntarget change by goal ≈ 24 kcal/day × kg to go",
        limitations: "Real progress is rarely linear: water and glycogen move the scale, and adherence usually slips over time, which is the main reason plateaus happen. 24 kcal a day per kilogram is an average from modelling, not a measurement of you.",
        citations: [.hall2011, .guo2018, .martins2020, .thomas2014]
    )

    static let goalProgress = MethodInfo(
        id: "goal-progress",
        title: "Goal Progress",
        summary: "Progress is how far your trend weight, the smoothed line on the Weight Trend screen, has moved from where the goal started toward its target, from 0% to 100%. Using the trend rather than your last weigh-in means a single heavy or light day barely moves it. Moving away from the target reads as 0%, not negative.",
        formula: "progress = clamp(|start − trend weight| ÷ |start − target|, 0, 1)",
        limitations: "Day-to-day weight varies by about half a percent of body weight from water and food alone, so the trend lags a real change by a week or two.",
        citations: [.schneditz2023]
    )
}
// swiftlint:enable line_length
