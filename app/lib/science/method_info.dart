import 'package:compound/l10n/l10n.dart';

/// A published source a calculation rests on (Swift `Citation`). The
/// reference is bibliographic and reads the same in every language.
class const Citation({
  /// The full reference, authors to pages.
  required final String reference,

  /// The DOI, when it has one.
  final String? doi,

  /// A web address, for a source without a DOI.
  final String? url,

  /// False for a book, a website or anything else unreviewed.
  final bool isPeerReviewed = true,
}) {
  /// `doi:…`, or the web address; null with neither.
  String? get linkText => doi != null ? 'doi:$doi' : url;

  /// R30.
  static const schneditz2023 = Citation(
    reference:
        'Schneditz D, et al. (2023). Day-to-day variability in euvolemic '
        'body mass. Ren Fail 45(2):2273421.',
    doi: '10.1080/0886022X.2023.2273421',
  );

  /// R95.
  static const pelland2026 = Citation(
    reference:
        'Pelland JC, Remmert JF, Robinson ZP, Hinson SR, Zourdos MC (2026; '
        'online Dec 2025). The resistance training dose response: '
        'meta-regressions exploring the effects of weekly volume and '
        'frequency on muscle hypertrophy and strength gains. Sports Med '
        '56(2):481–505.',
    doi: '10.1007/s40279-025-02344-w',
  );

  /// R31.
  static const orsama2014 = Citation(
    reference:
        'Orsama AL, Mattila E, Ermes M, van Gils M, Wansink B, Korhonen I '
        '(2014). Weight rhythms: weight increases during weekends and '
        'decreases during weekdays. Obes Facts 7(1):36–47.',
    doi: '10.1159/000356147',
  );

  /// R32.
  static const turicchi2020 = Citation(
    reference:
        "Turicchi J, O'Driscoll R, Horgan G, Duarte C, Palmeira AL, Larsen "
        'SC, Heitmann BL, Stubbs J (2020). Weekly, seasonal and holiday body '
        'weight fluctuation patterns among individuals engaged in a European '
        'multi-centre behavioural weight loss maintenance intervention. PLoS '
        'One 15(4):e0232152.',
    doi: '10.1371/journal.pone.0232152',
  );

  /// R39.
  static const walker = Citation(
    reference:
        "Walker J. The Hacker's Diet (online edition, Fourmilab). Unreviewed.",
    url: 'https://fourmilab.ch/hackdiet/www/subsubsection1_4_1_0_8_3.html',
    isPeerReviewed: false,
  );

  /// R41.
  static const rauch1965 = Citation(
    reference:
        'Rauch HE, Tung F, Striebel CT (1965). Maximum likelihood estimates '
        'of linear dynamic systems. AIAA J 3(8):1445–1450.',
    doi: '10.2514/3.3166',
  );

  /// R72.
  static const cfr21 = Citation(
    reference:
        'US Code of Federal Regulations, Title 21, §101.9(g)(4)–(5) '
        '(nutrition labelling compliance).',
    url: 'https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9',
  );

  /// R102.
  static const currier2026 = Citation(
    reference:
        'Currier BS, et al. (2026). American College of Sports Medicine '
        'position stand. Resistance training prescription for muscle '
        'function, hypertrophy, and physical performance in healthy adults: '
        'an overview of reviews. Med Sci Sports Exerc 58(4):851–872.',
    doi: '10.1249/MSS.0000000000003897',
  );

  /// R107.
  static const bull2020 = Citation(
    reference:
        'Bull FC, et al. (2020). World Health Organization 2020 guidelines on '
        'physical activity and sedentary behaviour. Br J Sports Med '
        '54(24):1451–1462.',
    doi: '10.1136/bjsports-2020-102955',
  );

  /// R108.
  static const lally2010 = Citation(
    reference:
        'Lally P, van Jaarsveld CHM, Potts HWW, Wardle J (2010). How are '
        'habits formed: modelling habit formation in the real world. Eur J '
        'Soc Psychol 40(6):998–1009.',
    doi: '10.1002/ejsp.674',
  );

  /// R111.
  static const paluch2022 = Citation(
    reference:
        'Paluch AE, et al. (2022). Daily steps and all-cause mortality: a '
        'meta-analysis of 15 international cohorts. Lancet Public Health '
        '7(3):e219–e228.',
    doi: '10.1016/S2468-2667(21)00302-9',
  );

  /// R112.
  static const ding2025 = Citation(
    reference:
        'Ding D, et al. (2025). Daily steps and health outcomes in adults: a '
        'systematic review and dose-response meta-analysis. Lancet Public '
        'Health 10(8):e668–e681.',
    doi: '10.1016/S2468-2667(25)00164-1',
  );
}

/// What one calculation does and what it rests on, for the info button
/// beside the figure it produces (Swift `MethodInfo`). Every number the app
/// derives for the user, rather than reads back from their logs, has one.
class const MethodInfo({
  required final String title,

  /// How the figure is worked out, in a few sentences.
  required final String summary,

  /// The sources, each with its DOI or address.
  required final List<Citation> citations,

  /// The equation as the code computes it. Not localized: symbols and
  /// numbers.
  final String? formula,

  /// How far to trust the figure.
  final String? limitations,

  /// The constants Compound chose itself, with no study behind them.
  final String? ownChoices,
}) {
  /// The weight trend (Swift `MethodInfo.weightTrend`), computed by
  /// `compound_maths`' `weightTrend`.
  factory weightTrend(AppLocalizations l10n) => MethodInfo(
    title: l10n.weightTrendTitle,
    summary: l10n.weightTrendMethodSummary,
    formula: _weightTrendFormula,
    limitations: l10n.weightTrendMethodLimitations,
    ownChoices: l10n.weightTrendMethodOwnChoices,
    citations: const [
      Citation.schneditz2023,
      Citation.orsama2014,
      Citation.turicchi2020,
      Citation.walker,
      Citation.rauch1965,
    ],
  );

  /// The weekly session goal and the streak (Swift
  /// `MethodInfo.weeklySessionGoal`), computed by `compound_maths`'
  /// `WeeklyStreak`.
  factory weeklySessionGoal(AppLocalizations l10n) => MethodInfo(
    title: l10n.weeklyGoalMethodTitle,
    summary: l10n.weeklyGoalMethodSummary,
    formula:
        'week met = sessions in the week ≥ goal\n'
        'streak = consecutive met weeks, this week included once met\n'
        'default goal 3; range 1–7',
    limitations: l10n.weeklyGoalMethodLimitations,
    ownChoices: l10n.weeklyGoalMethodOwnChoices,
    citations: const [
      Citation.bull2020,
      Citation.currier2026,
      Citation.lally2010,
    ],
  );

  /// The default daily step goal (Swift `MethodInfo.dailyStepGoal`),
  /// computed by `ageAdjustedStepGoal`.
  factory dailyStepGoal(AppLocalizations l10n) => MethodInfo(
    title: l10n.stepGoalMethodTitle,
    summary: l10n.stepGoalMethodSummary,
    formula:
        'goal = your chosen goal, else\n'
        '       8,000 steps/day under 60\n'
        '       7,000 steps/day from 60',
    limitations: l10n.stepGoalMethodLimitations,
    ownChoices: l10n.stepGoalMethodOwnChoices,
    citations: const [Citation.paluch2022, Citation.ding2025],
  );

  /// When a day's eating counts as on target (Swift
  /// `MethodInfo.calorieAdherenceBand`), judged by `NutritionItem.isDone`.
  factory calorieAdherenceBand(AppLocalizations l10n) => MethodInfo(
    title: l10n.adherenceBandMethodTitle,
    summary: l10n.adherenceBandMethodSummary,
    formula:
        'calories on target: |eaten − target| ≤ 10% × target\n'
        'protein on target: eaten ≥ target',
    limitations: l10n.adherenceBandMethodLimitations,
    ownChoices: l10n.adherenceBandMethodOwnChoices,
    citations: const [Citation.cfr21],
  );

  /// A template's planned sets per muscle (Swift
  /// `MethodInfo.plannedSetsPerMuscle`), computed by
  /// `TemplateSummary.targetMuscles`.
  factory plannedSetsPerMuscle(AppLocalizations l10n) => MethodInfo(
    title: l10n.plannedSetsMethodTitle,
    summary: l10n.plannedSetsMethodSummary,
    formula: 'planned sets = Σ planned sets × (1 if primary, 0.5 if secondary)',
    limitations: l10n.plannedSetsMethodLimitations,
    citations: const [Citation.pelland2026],
  );

  /// Every method ported so far, keyed by its Swift `MethodInfo.id`, in
  /// Swift's order (`MethodInfo.all`: energy, nutrition, training, volume,
  /// habits), for Settings › Methods & Sources. Add each new method here.
  static Map<String, MethodInfo> all(AppLocalizations l10n) => {
    'weight-trend': MethodInfo.weightTrend(l10n),
    'volume.plannedSets': MethodInfo.plannedSetsPerMuscle(l10n),
    'habits.weeklyGoal': MethodInfo.weeklySessionGoal(l10n),
    'habits.stepGoal': MethodInfo.dailyStepGoal(l10n),
    'habits.adherenceBand': MethodInfo.calorieAdherenceBand(l10n),
  };

  static const _weightTrendFormula = '''
State: level L (kg), slope b (kg/day). Between weigh-ins Δt days apart:
  L ← L + b·Δt
  P ← F·P·Fᵀ + Q,  F = [[1, Δt], [0, 1]]
  Q = 0.004²·[[Δt³/3, Δt²/2], [Δt²/2, Δt]] + diag(0.05²·Δt, 0)
Weigh-in y: v = y − L,  R = max((0.005·L)², 0.3²),  S = P_LL + R
  R_eff = R·max(1, (|v| / (2.5·√S))²)       (robust, Huber-type)
  |v| > max(3 kg, 0.04·L): held until the next weigh-in agrees
  K = P[:,0] / (P_LL + R_eff);  x ← x + K·v
Start: L = median of the first 3 weigh-ins, b = 0 (SD 0.1 kg/day)
Chart: Rauch–Tung–Striebel smoother over the whole series''';
}
