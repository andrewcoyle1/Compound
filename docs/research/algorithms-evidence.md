# Rebuild Compound's maths on published evidence

Compound needs far fewer algorithm changes than "indefensible" suggests. Most of its formulas have literature behind them. What it lacks is the right constants, a cap or two, and a citation. Three components do need replacing. First, the trend, adaptive-TDEE and target-proposal stack: two inconsistent EMAs, a hand-tuned 0.30 blend, a ±150 kcal clamp and a second "rate-error" loop that double-counts. It should become **one Kalman filter** whose noise terms come from published weight-variability and intake-balance data. Second, the activity multipliers sit below the measured physical activity level (PAL) of essentially every free-living adult, and they stack an unpublished additive exercise bonus on top. Third, the mesocycle deload cuts load by 35% but keeps volume, the opposite of reported practice. Everything else is a constant fix: one energy density instead of both 7700 and 3500/lb, an Epley rep cap, sex-specific calorie floors with no unsupervised 800 kcal option, protein on a reference weight, keto as a gram cap, a fat floor, tapered warm-ups, and load-dependent rest. Several things the app already does are among the best-supported choices available: Mifflin-St Jeor as the default RMR, a 28-day back-calculation window, 0.5 credit for secondary muscles, double progression with an RPE gate, a weekly (not daily) streak and an 8,000-step goal. The main caveat about the evidence is that the network blocked PubMed and PMC during the research, so many exact coefficients were recalled rather than re-read. The list at the end must be checked before any number ships in code or copy. Every claim in this summary is sourced in the section that discusses it; the numbered reference list follows the roadmap.

## How to read the evidence labels in this report

Every recommendation carries two labels. The first is the **evidence class**:

| Class | Meaning |
|---|---|
| **Peer-reviewed** | Meta-analyses, RCTs, DLW/DXA validation studies |
| **Consensus** | Guidelines, position stands, Delphi studies |
| **Unreviewed** | Popular but not peer-reviewed: Hacker's Diet, MacroFactor/Stronger By Science, Renaissance Periodization volume landmarks, the RTS RPE chart, Starting Strength-style resets |
| **Inference** | The researchers' own derivation or design choice |

The second is the **verification tag**:

| Tag | Meaning |
|---|---|
| **[confirmed]** | The claim was checked this session against an abstract or search text quoting the source |
| **[recalled]** | The claim comes from well-known literature the researchers cited from memory, with a DOI or PubMed link, but did not re-open |
| **[calc]** | Arithmetic on cited constants |

Certainty is **High**, **Moderate** or **Low**. A design choice to be tuned by replaying users' data is marked **Tune**.

Citations are given as **[R*n*]** and resolve to the numbered **References** list at the end, where every entry carries a DOI or, for guidelines, books and web pages, a stable URL or full bibliographic reference. The inline links are kept for convenience. Two further labels mark claims that have no published source: **[derived: …]** for the researchers' own arithmetic or algebra, and **[design choice — no source; tune by replay]** (or **[Inference — no source]**) for the researchers' own engineering choices. Non-peer-reviewed sources (MacroFactor, Stronger By Science, Hacker's Diet, Renaissance Periodization, practitioner books, preprints) are marked **Unreviewed** with a URL. A separate file, `docs/research/citation-verification-checklist.md`, lists every reference with what to check.

All app paths below are relative to `/home/user/Compound`. `functions/coach-maths.js` is a line-for-line port of the Swift expenditure engine, formula TDEE, weight trend, Epley e1RM and weekly-sets maths. `CompoundUnitTests/Managers/CoachParityTests.swift` checks both against `CompoundUnitTests/Fixtures/coach-parity.json`. Every change in those areas therefore lands in both languages, with a regenerated fixture (see the roadmap).

## Energy expenditure: keep Mifflin, replace the activity table

### Current behaviour
`Compound/Managers/Nutrition/NutritionManager/NutritionManager.swift:287-386` computes RMR with one of three equations:

- Mifflin-St Jeor: 10W + 6.25H − 5A, plus 5 (male), −161 (female) [R1] or −78 (prefer not to say; the app's own midpoint, see below).
- Revised Harris-Benedict [R2].
- Katch-McArdle (370 + 21.6·LBM) [R3], which is forced when body fat is logged.

It then multiplies by an additive PAL: sedentary 1.2, light 1.35, moderate 1.5, active 1.7, very active 1.9, plus 0.05–0.20 for exercise frequency, capped at 2.1, with a floor of 1000 kcal. These multipliers and the add-on are the app's own values; no published scheme with these exact numbers was found. If inputs are missing, it defaults to a 70 kg, 175 cm, 30-year-old man.

`Compound/Core/Onboarding/4 - CompleteAccountSetup/9 - Expenditure/ExpenditurePresenter.swift` duplicates this formula. It also shows a "Digesting Food" (TEF) slice that is only a rounding remainder of about 0. The step nowcast uses 0.0005 kcal/step/kg.

### Verdict

| Component | Verdict |
|---|---|
| Mifflin default | **Keep** |
| Katch-McArdle | **Replace** |
| PAL table | **Replace** |
| Frequency add-on | **Remove** |
| TEF slice | **Modify** |
| Step constant | **Modify** |
| Silent male/70 kg defaults | **Remove** |

### Mifflin is the right default

Mifflin-St Jeor is the best-validated weight-and-height equation. The Frankenfield systematic review found it "the most reliable, predicting RMR within 10% of measured in more nonobese and obese individuals than any other equation" ([PSU record](https://pure.psu.edu/en/publications/comparison-of-predictive-equations-for-resting-metabolic-rate-in-)) [confirmed] [R4]. A review in overweight and obese adults put about **75% of Mifflin predictions within 10%** (in the BMI 30–39.9 and ≥40 subgroups), which leaves roughly one user in four outside that band ([UHRA](https://uhra.herts.ac.uk/id/eprint/5072/)) [confirmed] [R5]. The app should therefore show RMR as an estimate with a ±10% band and say plainly that about a quarter of people fall outside it. Peer-reviewed; High.

The −78 sex-neutral constant is the arithmetic midpoint of +5 and −161 [R1]. That puts it 83 kcal (about 5% of a 1,600 kcal RMR) from either sex's value [calc]. Keep it, but widen the stated uncertainty to about ±15% [design choice — no source; tune by replay]. Inference; Moderate.

The silent male/70 kg/175 cm defaults bias anyone who skips a field. Require weight and height, and use the neutral constant when sex is unknown. The age floor of 14 sits below the adult validation range of every equation here (Mifflin was derived in adults aged 19–78 [R1]). Inference.

### Lean, muscular users need a different FFM equation than Katch-McArdle

Weight-based equations, Mifflin included, tend to **underestimate** RMR in resistance-trained people. A 2023 Sports Medicine meta-analysis covered 29 studies, 1,430 athletes and 100 equations. Only five equations were not significantly different from measured RMR, among them **Cunningham 1980, Cunningham 1991 and ten Haaf & Weijs**, with ten Haaf showing I² = 0% ([PMC10687135](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10687135/)) [confirmed] [R6]. Katch-McArdle was not among them. In muscular physique athletes, "nearly all" body-weight and FFM equations underestimated RMR, the exceptions being ten Haaf and Cunningham 1980 ([TTU record](https://scholars.ttu.edu/en/publications/resting-metabolic-rate-in-muscular-physique-athletes-validity-of--5)) [confirmed] [R7].

```
Cunningham 1980:   RMR = 500 + 22·FFM                                   [recalled; PubMed 7435418; abstract now confirms] [R8]
ten Haaf FFM:      RMR = 22.771·FFM + 484.264                           [recalled; doi:10.1371/journal.pone.0108460] [R9]
ten Haaf weight:   RMR = 11.936·W + 587.728·H(m) − 8.129·A + 191.027·male + 29.279   [recalled] [R9]
```

Replace Katch-McArdle with Cunningham 1980 when FFM is known. The bigger risk lies in the FFM input, because consumer bioimpedance body-fat readings err by several percentage points [Inference — no source retrieved for the size of consumer BIA error]. Every 1 kg of FFM error moves RMR by about 22 kcal (the Cunningham slope [R8]), so 5 kg costs about 110 kcal/day [calc]. Use the FFM path only when the body-fat source is trusted (DEXA, or a stable multi-reading average), or average the FFM-based and weight-based estimates. Peer-reviewed for the equation choice (High in athletes); Inference for the gating.

### The PAL table starts below every measured free-living adult

FAO/WHO/UNU 2004 defines sedentary or light lifestyles as **PAL 1.40–1.69**, active 1.70–1.99 and vigorous 2.00–2.40 ([FAO report](https://www.fao.org/4/y5686e/y5686e00.htm)) [recalled] [R10]. The app's "sedentary 1.2" suits bed-bound patients, not free-living gym-goers [Inference — no source]. It biases the prior about 15% low relative to PAL 1.4 [calc].

No published PAL scheme adds a training-frequency term on top of a lifestyle category [Inference — based on the schemes reviewed, R10, R14, R17]. Those categories already include habitual exercise [R10, R14]. DLW data also show that total energy expenditure "increases with physical activity at low activity levels but plateaus at higher activity levels" ([doi](https://doi.org/10.1016/j.cub.2015.12.046)) [confirmed] [R11]. Hadza foragers have a higher PAL than Westerners, yet the same size-adjusted daily expenditure ([PLoS One](https://journals.plos.org/plosone/article%3Fid%3D10.1371/journal.pone.0040503)) [confirmed] [R12]. Stacking up to +0.20 on a category, to a cap of 2.1, therefore double-counts exercise [Inference]. The constrained-energy model is contested ([critique](https://www.germanjournalsportsmedicine.com/archive/archive-2018/heft-1/editorial-fat-in-spite-of-exercise-an-alleged-paradigm-change-results-from-calculation-mistakes/)) [R13], but that does not rescue an additive bonus. It only argues about how much TEE plateaus.

The most defensible prior is the **2023 National Academies DRI estimated-energy-requirement (EER) equations**. They were built by commissioning "an independent analysis of databases of doubly labeled water (DLW) measures" and validated against 144 cohorts ([NAP ch. 7](https://www.nationalacademies.org/read/26818/chapter/7)) [confirmed] [R14]. They publish their own error. For inactive men, R² = 0.73 and RMSE = **339 kcal/day** ([NAP Table S-1](https://nap.nationalacademies.org/read/26818/chapter/2)) [confirmed] [R14].

```
Men 19+, inactive:      EER = 753.07  − 10.83·age + 6.50·H + 14.10·W     [confirmed, Table S-1] [R14]
Men, low active:        EER = 581.47  − 10.83·age + 8.30·H + 14.94·W     [recalled; search snippet of Table S-1 agrees] [R14]
Men, active:            EER = 1004.82 − 10.83·age + 6.52·H + 15.91·W     [recalled; secondary copies agree] [R14, R16]
Men, very active:       EER = −517.88 − 10.83·age + 15.61·H + 19.11·W    [recalled; CONFLICTING search result, see checklist] [R14, R16]
Women 19+, inactive:    EER = 584.90 − 7.01·age + 5.72·H + 11.71·W       [confirmed via secondary copies] [R14, R15, R16]
Women, low active:      EER = 575.77 − 7.01·age + 6.60·H + 12.14·W       [secondary copies] [R14, R15, R16]
Women, active:          EER = 710.25 − 7.01·age + 6.54·H + 12.34·W       [secondary copies] [R14, R15, R16]
Women, very active:     EER = 511.83 − 7.01·age + 9.07·H + 12.56·W       [secondary copies] [R14, R15, R16]
PAL bands: inactive 1.0–<1.4; low active 1.4–<1.6; active 1.6–<1.9; very active 1.9–<2.5   [recalled; may be the 2005 IOM bands, see checklist] [R14, R17]
(H in cm, W in kg)
```

The women's coefficients come from teaching copies and Health Canada's republication ([canada.ca](https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/equations-estimate-energy-requirement.html) [R15]; [USP](https://edisciplinas.usp.br/mod/resource/view.php?id=4749455) [R16]). They were not read from Table S-1 itself.

**Recommendation (Option A, preferred):** map Compound's five activity levels onto the four DRI categories and use the sex-specific EER [R14]. When sex is unknown, average the two outputs and widen the band [design choice — no source]. Delete the frequency add-on. Display the prior as "about X ± 340 kcal" (the inactive-men RMSE, rounded [R14]). Consensus built on DLW; High.

**Option B (minimum change):** keep Mifflin × PAL, but use 1.4 / 1.55 / 1.7 / 1.85 / 2.0 (allowing up to 2.2 for very active) with no add-on [design choice — no source; values chosen inside the FAO bands, R10]. Inference within FAO bands; Moderate.

Two cheaper alternatives were set aside. Bajunaid et al. 2025 built a newer TEE equation from 6,497 DLW measurements and use its 95% predictive limits to screen misreported intake. They found misreporting in more than 50% of NDNS and NHANES records ([Strathprints](https://strathprints.strath.ac.uk/91881)) [confirmed] [R18] (an author correction to the NDNS/NHANES application has since been published; see checklist). Its coefficients were not retrieved, so it is a future plausibility screen, not a drop-in. Age also matters less than the linear term implies: size-adjusted TEE is stable from about 20 to 60 and declines after about 60 (Pontzer 2021, [doi](https://doi.org/10.1126/science.abe5017)) [recalled; abstract now confirms] [R19]. Accept that as a small known bias rather than invent a correction.

### TEF and steps

Diet-induced thermogenesis is about **10% of intake** on a mixed diet: protein 20–30%, carbohydrate 5–10%, fat 0–3% (Westerterp 2004, [doi](https://doi.org/10.1186/1743-7075-1-5)) [recalled] [R20]. Either compute the slice as 10% of TDEE, or as 0.25·P_kcal + 0.075·C_kcal + 0.02·F_kcal [derived: midpoints of Westerterp's per-macronutrient ranges, R20], then let activity = TDEE − RMR − TEF. Otherwise remove it. A ~0 rounding remainder labelled "Digesting Food" is simply wrong. Peer-reviewed; High for the 10% figure.

The ACSM walking equation (VO₂ = 0.1·speed + 1.8·speed·grade + 3.5 mL/kg/min [R21]) gives a net horizontal cost of about 0.49 kcal/kg/km [derived: 0.1 mL O₂/kg/m × ~4.9 kcal/L O₂]. At about 1,300–1,400 steps/km [assumption — no source retrieved; implies a step length of ~0.71–0.77 m], that is **≈0.00035–0.0004 kcal/step/kg net** [recalled equation; calc] ([Minetti 2002](https://iris.unibs.it/retrieve/ddc633e4-3c03-4e2e-e053-3705fe0a4c80/Minetti%20JAP%202002.pdf) [R22], a gross walking-cost cross-check, not the source of the ACSM equation). The app's 0.0005 is roughly the *gross* figure [derived: adding 3.5 mL/kg/min resting VO₂ at ~5 km/h gives ≈0.7 kcal/kg/km]. Because the nowcast works on step *differences*, the net figure is the right one [Inference]. The difference is about 10 kcal per 1,000 extra steps at 70 kg [calc], so this is low priority. Moderate.

## Energy density of weight change: one function, Forbes-partitioned

### Current behaviour
`Compound/Managers/Nutrition/Expenditure/ExpenditureEngine.swift` and the goal-calorie code use **7700 kcal/kg**. The onboarding goal-rate screen uses **3500 kcal/lb** (≈7716 kcal/kg).

**Verdict:** **Replace** with a single function ρ(F), falling back to 7700 when fat mass is unknown.

### Why a flat 7700 is a rough average

The 3,500 kcal/lb rule traces to Wishnofsky (1958) [R23], whose caveats were dropped in later use. Hall's modified-Forbes analysis showed that "a larger cumulative energy deficit is required per unit weight loss for people with greater initial body fat" ([PMC2376744](https://pmc.ncbi.nlm.nih.gov/articles/PMC2376744)) [confirmed] [R24]. Fat holds about 39.5 MJ/kg (≈9,440 kcal/kg) and lean tissue about 7.6 MJ/kg (≈1,816 kcal/kg) ([Hall Lancet 2011 web appendix](https://www.niddk.nih.gov/-/media/Files/BWP/Hall_Lancet_Web_Appendix.pdf)) [confirmed] [R25]. Forbes' relation then gives the defensible formula:

```
pF   = F / (F + 10.4)                         F = fat mass in kg          [recalled: Forbes/Hall] [R26, R27]
ρ(F) = pF · 9440 + (1 − pF) · 1816            kcal per kg of weight change   [derived: Forbes partition × Hall densities, R25–R27]

F = 15 kg  → ρ ≈ 6,315     F = 25 kg → ρ ≈ 7,200     F = 35 kg → ρ ≈ 7,700     F = 40 kg → ρ ≈ 7,870   [calc]
```

So 7700 is exactly right only for someone carrying about 35 kg of fat [calc; consistent with Hall 2008's statement that the rule fits initial body fat above ~30 kg, R24]. For a lean lifter with 12–15 kg of fat it overstates energy per kg by about 20%. A 0.5 kg/week loss is then credited as a 550 kcal/day deficit instead of about 450, inflating the back-calculated TDEE by about 100 kcal/day [calc].

Early weight change is cheaper still. In CALERIE data, the energy content of lost weight was **4,858 ± 388 kcal/kg at week 4**, rose to 6,041 ± 376 by week 6, and then stabilised ([Monash record](https://research.monash.edu/en/publications/energy-content-of-weight-loss-kinetic-features-during-voluntary-c/)) [confirmed] [R28]. The reason is that glycogen (about 400–500 g, bound to about 3 g water per gram) leaves first ([PubMed 1615908](https://pubmed.ncbi.nlm.nih.gov/1615908/)) [recalled] [R29]. Peer-reviewed; Moderate–High.

### An insight that sets the priority: ρ largely cancels inside a closed loop

If the estimator infers TDEE as T̂ = Ī − ρ·b̂ and the target is set as Ī_target = T̂ + ρ·r_goal, then Ī_target = Ī + ρ·(r_goal − b̂). At steady state, when the observed rate b̂ matches the goal, the target equals current intake **whatever ρ is** [calc]. A wrong ρ mainly distorts two things: the *displayed* TDEE number, and how strongly the loop corrects when the rate is off target. This explains why one researcher was content to keep 7700 and the other wanted Forbes: both are right about different outputs.

The recommendation is a single `energyDensity(fatMassKg:)` function used by the estimator, the target and every rate screen. It returns ρ(F) when body fat is known and 7700 otherwise. This deletes the 3500/lb duplicate. Inference built on peer-reviewed constants; Moderate.

When F is unknown, a BMI-based body-fat estimate could feed ρ(F). No such equation was researched in these notes, so the 7700 fallback stands until one is sourced.

## One filter replaces two EMAs, a blend, a clamp and a second loop

### Current behaviour
**Display trend.** `Compound/Utilities/WeightTrendCalculator.swift` uses an EMA with α = 0.25 *per weigh-in*. That is a time constant of 3.5 days for someone who weighs daily and about 24 days for someone who weighs weekly [derived: τ = −1/ln(1−α) per sample].

**Engine trend.** `ExpenditureEngine.swift:246-270` uses α = 0.10 *per day*, seeded from the mean of the first 7 weigh-ins. Weigh-ins are clamped to the trend ±2.5%, and missing days are carried forward.

**Adaptive TDEE.** `ExpenditureEngine.swift` and `ExpenditureWindowStats.swift` compute raw = mean(logged intake) − Δtrend·7700/span. The constants are a 28-day window, a 14-day minimum, minLoggedFraction 0.5 and 4 weigh-ins. The update is running += clamp(0.30·(raw − running), ±150/day), bounded to 0.6–1.6× the formula value.

**Target proposal.** `Compound/Managers/Nutrition/Expenditure/TargetProposal.swift` adds a second loop: clamp((goalRate − trendRate)·7700/7, ±200).

**Balance cards.** These still use the static formula TDEE, and one divides 7-day intake by 7 regardless of unlogged days.

**Verdict:** **Replace** the whole stack with the design below. **Remove** the rate-error term now, even before the filter ships.

### What the literature fixes, and what it leaves to tuning

Three facts are well supported.

**Weigh-ins are noisy.** A 30-year, 9,211-day-pair series found the SD of day-to-day change was **0.53% of body mass** at a 1-day interval and 0.69% at 7 days ([PMC10653631](https://pmc.ncbi.nlm.nih.gov/articles/PMC10653631/)) [confirmed; n = 1] [R30]. Weight also follows a weekly rhythm: it rises from Saturday, falls from Tuesday, and swings about **0.35%** within the week (Orsama 2014, [PMC5644907](https://pmc.ncbi.nlm.nih.gov/articles/PMC5644907/) [R31]; Turicchi 2020, [White Rose](https://eprints.whiterose.ac.uk/162249/) [R32]) [confirmed]. Around menstruation, weight rises about **0.45 kg**, entirely as extracellular water ([Kanellakis 2023](https://onlinelibrary.wiley.com/doi/full/10.1002/ajhb.23951)) [confirmed] [R33].

**Individual estimates need about four weeks of daily weights.** Hall & Chow found that "daily weight measurements over periods longer than 28 days were required" for a 95% CI under 300 kcal/day ([AJCN](https://academic.oup.com/ajcn/article/94/1/66/4597980)) [confirmed] [R34]. Standard regression algebra agrees. With per-weigh-in noise σ = 0.5 kg (rounded up from R30's 0.53%, see the parameter table), the slope SE is σ·√(12/(N(N²−1))): **≈±255 kcal/day at 14 days** and **≈±90 kcal/day at 28 days** at 7700 kcal/kg [calc; standard OLS slope SE, assumes independent noise]. The app's 14-day minimum is therefore well short of the evidence.

**Even good data leave about ±200 kcal of individual error.** Against DLW/DXA over two years of CALERIE, weight-based intake estimates were within 40 kcal/day on average. Individual RMSD was **215 kcal/day** ([PMC4515869](https://pmc.ncbi.nlm.nih.gov/articles/PMC4515869)) [confirmed] [R35].

The intake-balance approach is also self-correcting in a precise, conditional sense. If logged intake is (1−u)·true intake with a constant under-report fraction u, the inferred TDEE is TDEE_true − u·I. A target computed on that same scale still produces the intended weight change [calc]. The correction breaks when u drifts (more careful logging after a stall) or when unlogged days differ from logged ones, for example weekend eating, which Orsama's weekend rise makes plausible [Inference, R31]. Under-reporting is large: "diet-resistant" subjects under-reported intake by 47% ([PubMed 1454084](https://pubmed.ncbi.nlm.nih.gov/1454084/)) [recalled] [R36] (a subgroup of 10 people). The displayed TDEE should therefore be labelled "based on what you logged".

Kalman filtering for this purpose has academic precedent. Guo, Rivera et al. estimated energy intake recursively from intermittent weights with a Kalman filter, including "correlated partial data losses" ([PMC6941743](https://pmc.ncbi.nlm.nih.gov/articles/PMC6941743) [R37]; [ASU 2017](https://asu.elsevierpure.com/en/publications/state-estimation-under-correlated-partial-measurement-losses-impl/) [R38]) [confirmed]. That work was in pregnancy, and **no study validates a consumer-app Kalman TDEE against DLW** [negative finding of this research; none located]. The filter's structure is literature-anchored, but its tuning is not.

### Reconciling the two proposed filters

The two notes proposed different designs:

- **energy_expenditure.md** proposed a daily two-state filter, x = [W_trend, T]. Intake is a noisy input, and unlogged intake is a wide prior centred on T.
- **weight_trend_and_adaptive_control.md** proposed a cascade. First, a local-linear-trend filter on weight, x = [L, b], updated per weigh-in. Then a separate 1-D weekly filter on TDEE, fed z = Ī − ρ·b̂ over a trailing 28-day window.

The cascade's weakness is that consecutive weekly observations share 21 of their 28 days. Treating them as independent overstates the evidence about fourfold [derived: 28-day window ÷ 7-day step], and the reported SD would be falsely tight. The two-state filter has the opposite weakness: a user who never logs food gets a level-only trend with EMA-like lag, because no slope state exists.

Both are special cases of one three-state model. The slope is not a free state but the energy imbalance divided by ρ:

```
State (daily time step):  x = [ L  (trend weight, kg),
                                E  (habitual intake level, kcal/day, on the user's logging scale),
                                T  (TDEE, kcal/day, same scale) ]

Process (Δt = 1 day; predict repeatedly across days with no data):
  L(t+1) = L(t) + (E(t) − T(t)) / ρ(F)                     + w_L
  E(t+1) = E(t)                                            + w_E
  T(t+1) = T(t) − ε · (L(t+1) − L(t))                      + w_T      ε ≈ 24 kcal/day per kg (optional) [R25]

Observations:
  weigh-in day:   y_W = L + v_W                 v_W ~ N(0, R_W)
  logged day:     y_I = E + v_I                 v_I ~ N(0, σ_I²)
  unlogged or partial day: no intake observation (predict only)

Outputs:  trend weight L;  rate b = (E − T)/ρ  (×7 for kg/week);  TDEE T ± √P_TT
```

The model and the algebra in this subsection are the researchers' own synthesis [derived: standard state-space algebra; no published source for this specific model]. The model collapses to each note's design as data allow. With no food logs, E and T are not separately identifiable. Only their difference is, and that difference is exactly note 2's slope b, with slope random-walk intensity q_b = (q_E + q_T)/ρ². With food logs, E is pinned by the logs and T becomes identifiable from weight. That is note 1's two-state filter.

Unlogged days need no special rule: the filter predicts through them, and the weights alone carry their information. The one-step prediction is a natural place for the "unlogged days look like logged days" assumption to live as an explicit prior rather than a hidden average.

The model costs 3×3 matrix arithmetic with no library, about 60 lines in each of Swift and JavaScript [estimate — not measured].

### Parameters, separated by what backs them

| Parameter | Value | Basis |
|---|---|---|
| R_W (weigh-in variance) | (0.005·L)², floor (0.3 kg)² | 0.53% day-to-day SD ([PMC10653631](https://pmc.ncbi.nlm.nih.gov/articles/PMC10653631/)) [R30]; per-weigh-in ≈0.37% [derived: 0.53%/√2, assuming independent errors], rounded up for autocorrelation. Literature-backed, **Tune** the 0.005; the 0.3 kg floor is a [design choice — no source; tune by replay] |
| Robust update | R_eff = R_W·max(1, (\|v\|/(2.5·√S))²); hold for confirmation if \|v\| > max(3 kg, 4%·L) | Standard Huber-type robust Kalman technique [method; no specific source cited]. The 2.5 and the 3 kg / 4% thresholds are a [design choice — no source; tune by replay]. Replaces the ±2.5% clamp, which at about 5× daily SD only ever caught typos [derived: 2.5% ÷ 0.53%]. Inference |
| Same-day weigh-ins | Use the first (morning) value | [Inference — no source] |
| Menstrual window (opt-in via HealthKit) | R_W ×2 from 5 days before to day 2 of menses | 0.45 kg ECW shift ([Kanellakis](https://onlinelibrary.wiley.com/doi/full/10.1002/ajhb.23951)) [R33]. Size of multiplier and window: [design choice — no source; tune by replay] |
| q_L (level noise) | (0.05 kg)²/day | [design choice — no source; tune by replay] **Tune** |
| Glycogen/water burst | q_L = (0.15 kg)²/day for 14 days after a target change ≥300 kcal or a diet-type switch | Early ρ ≈ 4,860 kcal/kg ([Monash](https://research.monash.edu/en/publications/energy-content-of-weight-loss-kinetic-features-during-voluntary-c/)) [R28]. Treated as level disturbance, not slope. The 0.15 kg, 14 days and 300 kcal are a [design choice — no source; tune by replay] **Tune** |
| q_E (intake random walk) | ≈(30 kcal)²/day; inflate P_EE to (300 kcal)² on target change | Chosen so that q_b ≈ (0.004 kg/d)²/day [derived: q_b = (q_E + q_T)/ρ²], giving a 7–10 day smoothing time constant like Hacker's Diet τ ≈ 9.5 d ([Fourmilab](https://fourmilab.ch/hackdiet/www/subsubsection1_4_1_0_8_3.html), Unreviewed) [R39]. [design choice — no source; tune by replay] **Tune** |
| q_T (TDEE drift) | ≈(13 kcal)²/day (= 35 kcal per week) | Both notes independently land here (10–20 kcal/day; 35 kcal/week) [design choice — no source; tune by replay]. Adaptation literature: −50 to −230 kcal/day over months ([PMC7657334](https://pmc.ncbi.nlm.nih.gov/articles/PMC7657334)) [R40, R54; the −230 figure is from Nunes 2022 (R54, which reports −65 to −230), not from the linked Martins paper; see checklist]. **Tune** |
| σ_I (daily intake observation) | User's own SD of logged daily intake (≈300–500 kcal); exclude days below 50% of T̂ as partial | [Inference — no source]. The partial-day flag already exists in the weekly check-in |
| ε (mass-driven TDEE drift) | 24 kcal/day per kg | Hall 2011, ≈100 kJ/day per kg ([web appendix](https://www.niddk.nih.gov/-/media/Files/BWP/Hall_Lancet_Web_Appendix.pdf)) [recalled] [R25]. Optional |
| ρ(F) | Forbes function above, 7700 fallback | Peer-reviewed constants [R25–R27] |
| Prior T₀ | DRI EER (or Mifflin × corrected PAL), SD = published RMSE (≈340) or 15%, ±15% wider if sex unknown | NASEM 2023 [confirmed for inactive men] [R14]. The 15% alternatives are a [design choice — no source] |
| Prior L₀, E₀ | L₀ = median of first 3 weigh-ins; E₀ = T₀ with SD 500 | [Inference — no source] |
| Sanity bounds | Keep 0.6–1.6× prior as a guard only | [Inference — the app's existing bounds; no source] |
| Logging gate | Days logged in last 28 ≥ 80% for "calibrated"; below 60%, inflate σ_I ×2 | [design choice — no source; tune by replay], from the unlogged-day bias argument |

Everything marked **Tune** must be set by **replaying anonymised user histories**, not by argument. Run the filter forward on past data and score three things:

1. One-step-ahead weigh-in prediction error.
2. Interval calibration: the 80% interval should contain the next week's realised energy balance about 80% of the time.
3. Target stability: the number of proposals per user-month.

No published evaluation exists to borrow these values from [negative finding of this research; none located].

### Cadence, display and uncertainty

The filter runs once per day and on every weigh-in. Display reads the filter's trend L. For the history chart only, a Rauch-Tung-Striebel smoother [R41] can revise past points using later data. This one trend replaces both EMAs, so the chart and the engine finally agree.

**TDEE display.** Show TDEE as an 80% interval, T̂ ± 1.28·√P_TT [1.28 = two-sided 80% normal quantile] ("2,450 kcal, likely 2,300–2,600"), or as a confidence badge: low above 250 kcal SD, medium 120–250, high below 120. Show the rate as "−0.4 kg/week ± 0.15". Until at least 21 days and 14 weigh-ins have accrued *and* SD_T < 200 kcal, show "calibrating, using formula". Given Sanghvi's 215 kcal RMSD [R35], an app claiming better than about ±150 kcal (1 SD) is overclaiming [Inference]. The SD thresholds, the 21-day/14-weigh-in gate and the 80% choice are a [design choice — no source; tune by replay].

**Balance cards.** The energy-balance and deficit cards should read T̂ from the filter, not the static formula, and should average intake over logged days only, stating the count.

**Timeline.** Goal progress should use L, not raw weight. That fixes the raw-weight readings in the goal timeline and in Today's weekly weight change.

### The calorie-target controller, without double counting

The current design runs two loops:

- **Loop A** is the adaptive TDEE. It is already an integral-type estimator that absorbs any persistent gap between predicted and observed weight change.
- **Loop B** (`TargetProposal.swift`) adds clamp((goalRate − trendRate)·7700/7, ±200) on top.

If the rate is off because TDEE was wrong, Loop A fixes it and Loop B double-counts. If the rate is off because the user is eating above target, Loop B lowers a target the user is already missing. That is the wrong response [Inference], and MacroFactor's published logic explicitly avoids it by using logged intake ([MacroFactor help](https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure), Unreviewed) [R42].

The replacement is feedforward plus a deadband, evaluated weekly:

```
Target_raw  = T̂ + ρ(F) · r_goal / 7                 r_goal in kg/week (signed)
Propose only if  |Target_raw − Target_current| > max(50 kcal, SD_T)
             and ≥ 7 days since the last change
             and the filter is past "calibrating"
Step limit:  |change| ≤ 150 kcal per week
Adherence first: if mean logged intake over the week > Target_current + 10% and the rate is slower
                 than goal → message about adherence, no target change
Maintenance only (optional): if |L − goal weight| > max(0.7 kg, 1% BW) → r_goal = ±0.15% BW/week
Then apply floors (next section).
```

The structure follows clinical adaptive programmes. In SmartLoss, validated energy-balance models quantified adherence from weight, and counsellors intervened when weight left a predicted zone. Weight change was **−9.4% vs −0.6%** in controls ([PMC4414058](https://pmc.ncbi.nlm.nih.gov/articles/PMC4414058)) [confirmed] [R43]. The Rivera group formalises adaptive interventions as model-predictive control ([PMC3856197](https://pmc.ncbi.nlm.nih.gov/articles/PMC3856197/)) [confirmed] [R44]. The deadband (50 kcal / SD_T), the 150 kcal step, the 10% adherence margin, the 0.7 kg / 1% BW maintenance band and the weekly cadence are a [design choice — no source; tune by replay] without trial evidence (**Tune**). The maintenance rule mirrors MacroFactor's published 1.5 lb / 0.15% BW rule (Unreviewed) [R42].

### Goal timelines

A linear timeline of weeks = Δkg ÷ rate ignores the predictable fall of about 24 kcal/day per kg lost [R25]. For a 10 kg loss at fixed intake, the deficit would shrink by about 240 kcal/day and the rate would slow by about 40% [calc]. Because the controller re-targets weekly, the *rate* can be held. A linear timeline is acceptable only if the copy says "your target will step down as you lose". Otherwise, simulate W(t+1) = W + (I − T(W))/ρ(F), with T falling by ε per kg, as the NIH Body Weight Planner does [R25]. In CALERIE, that planner's mean bias was −0.47 kg ([Semantic Scholar](https://www.semanticscholar.org/paper/Simulating-long-term-human-weight-loss-dynamics-in-Guo-Brager/4af2df07ad9b262e425b8a35c2402e6a9d643ef3)) [confirmed] [R45].

Adaptive thermogenesis beyond the mass-driven fall is modest and transient: **−92 ± 110 kcal/day** at the end of a diet, falling to −7 ± 129 (not significant) at one year ([PMC7657334](https://pmc.ncbi.nlm.nih.gov/articles/PMC7657334)) [confirmed] [R40]. The filter's q_T absorbs it [Inference]. Plateaus are mostly declining adherence ([PubMed 25080458](https://pubmed.ncbi.nlm.nih.gov/25080458/)) [recalled] [R46] (a modelling result), which is one more reason the controller checks adherence before lowering targets.

## Macros, rates and floors: right shape, wrong anchors

### Current behaviour
Protein is set per kg of *total* body weight: 1.6/2.0/2.2/2.6 g/kg, with the top tier labelled "highest recommended intake". Fat and carbohydrate are set as % of calories: fat 30% (balanced) or 20% (low-fat), carbs 20% (low-carb) or **5% of kcal (keto)**. There is no fat floor in g/kg.

The "varied" split is ×1.10 on Mon/Wed/Fri and ×0.925 on other days, regardless of the actual training schedule. Rates run from 0.25 kg/week to min(1% BW, 1.5 kg)/week, with a 0.5 kg/week default. Calorie floors are 1200, or 800 in a "low" setting, and are not sex-specific. Adherence is on target within ±10%. Atwater factors are 4/4/9/7. All of this lives in `NutritionManager.computeDietPlan` and the onboarding goal-rate screen.

### Protein: keep the tiers, fix the basis and the label

Morton's meta-analysis of 49 RCTs found no further resistance-training FFM gain beyond **1.62 g/kg/day** ([PubMed 28698222](https://pubmed.ncbi.nlm.nih.gov/28698222/)) [confirmed] [R47]. The upper CI of about 2.2 g/kg is [recalled] [R47]. Nunes 2022 (74 RCTs) found a small extra lean-mass gain from higher protein with RT, SMD 0.22 ([PubMed 35187864](https://pubmed.ncbi.nlm.nih.gov/35187864/)) [confirmed] [R48]. During a cut in lean lifters, the expert range is **2.3–3.1 g/kg FFM** (Helms 2014, [doi](https://doi.org/10.1123/ijsnem.2013-0054)) [recalled] [R49]. That is about 2.0–2.6 g/kg total body weight at 15% body fat [calc].

The 1.6/2.0/2.2 tiers fit this well [Inference, R47, R49]. Relabel 2.6 as "very high: lean, aggressive cut". It is safe for healthy users in the medium term (no adverse GFR effect in a meta-analysis, [doi](https://doi.org/10.1093/jn/nxy197) [recalled] [R50]), but no position stand "recommends" it [negative finding of this research; e.g. ACSM/AND/DC gives 1.2–2.0 g/kg, R55]. Peer-reviewed; Moderate–High.

Total body weight overstates needs in obesity. A review found **no trials measuring protein requirements in obesity** and suggests at least 1.2 g/kg using a weight capped at BMI 30 ([Amsterdam UMC](https://pure.amsterdamumc.nl/ws/files/142148308/Protein-requirement-in-obesity.pdf)) [confirmed] [R51]. Actual-weight and FFM-based targets differed meaningfully in 78–100% of people with overweight ([HvA](https://research.hva.nl/en/publications/calculation-of-protein-requirements-a-comparison-of-calculations-/)) [confirmed] [R52].

```
reference_weight = W                                   if BMI < 30
                 = max(30·H_m², goal_weight)           if BMI ≥ 30
protein_g = tier_g_per_kg × reference_weight
            (optionally FFM × 2.0–2.6 when trusted body fat exists)
age ≥ 65: floor at 1.2 g/kg (PROT-AGE, doi:10.1016/j.jamda.2013.05.021 [recalled]) [R53]
add a kidney-disease caveat in copy
```

The reference-weight rule is extrapolated from clinical practice (Inference; Moderate) [R51, R52; the max(30·H², goal weight) form is a design choice — no source]. Its effect is large. A 130 kg, 1.75 m user drops from 208–338 g/day to 147 g at 1.6 g/kg [calc].

### Fat, carbohydrate, keto

Fat should stay within the AMDR of 20–35% of energy [R17], and sports bodies discourage going below 20% (ACSM/AND/DC 2016, [doi](https://doi.org/10.1016/j.jand.2015.12.006)) [recalled] [R55]. Low-fat diets cut total testosterone modestly, by SMD −0.38 or about 10–15% ([SBS summary](https://www.strongerbyscience.com/low-fat-diets-testosterone/), Unreviewed secondary of the peer-reviewed meta-analysis R56) [confirmed] [R56]. The flaw in a pure percentage is that 20% of 1,500 kcal is 33 g, about 0.4 g/kg at 80 kg [calc]. Hence:

```
fat_g   = max(split_result, 0.5 g/kg·reference_weight, 0.20·kcal/9)     [R57 for 0.5 g/kg; R17/R55 for 20%] (0.6 g/kg for women: Inference — no source)
keto:     carbs_g = 30 (user range 20–50), not 5% of kcal                Feinman 2015, doi:10.1016/j.nut.2014.06.011 [recalled] [R58]; default of 30 g is a design choice — no source
note:     show "below typical sport range" if non-keto carbs < 3 g/kg   (note, not a floor) [R57: ≥3–5 g/kg; R55]
```

The fat g/kg floor is expert opinion (Iraki 2019, [doi](https://doi.org/10.3390/sports7070154) [recalled] [R57]; Low). Keto as **20–50 g/day** is the standard definition [R58] (Consensus; Moderate). A carbohydrate floor would be weak, because carbohydrate availability "generally did not affect" RT performance (Henselmans 2022, [doi](https://doi.org/10.3390/nu14040856)) [recalled] [R59]. Atwater factors [R60] and net carbs = carbs − fiber [convention — no source; not a regulatory definition in the US] are standard: **Keep**.

### Calorie cycling

No evidence favours fixed Mon/Wed/Fri high days [negative finding of this research; none located]. Block refeeds and diet breaks have small-trial support. Two refeed days per week cost **−0.4 kg FFM vs −1.3 kg** with continuous restriction in lean lifters ([DOAJ](https://doaj.org/article/507c78c8a3b444f3ac47006e96d34df5)) [confirmed] [R61]. A diet break raised FFM by about 0.7 kg in an ICECAP secondary analysis ([PMC7906362](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7906362/)) [confirmed] [R62].

**Modify** "varied" so high days come from the user's actual mesocycle day plans. Keep the week energy-neutral: high = target × 1.10 on N training days, and the other days take the remainder so the weekly total equals 7 × target [design choice — no source; the 1.10 is the app's existing value]. Present it as an adherence preference. Low certainty, low risk.

### Rates

For lean or lifting users, the consensus loss band is **0.5–1.0% BW/week** (Helms 2014, [doi](https://doi.org/10.1186/1550-2783-11-20)) [recalled] [R63]. In elite athletes, 0.7% beat 1.4% for lean mass and strength (Garthe 2011, [doi](https://doi.org/10.1123/ijsnem.21.2.97)) [recalled] [R64]. In obesity, fast and slow loss regain similarly (Purcell 2014, [doi](https://doi.org/10.1016/S2213-8587%2814%2970200-1)) [recalled] [R65].

For gaining, 0.25–0.5% BW/week is consensus (Iraki 2019) [R57] (stated for novice and intermediate bodybuilders). In trained lifters, a +15% surplus added skinfold but not muscle thickness compared with +5% ([PubMed 37914977](https://pubmed.ncbi.nlm.nih.gov/37914977/)) [confirmed; pilot] [R66].

```
loss:  min 0.25% BW/wk; max min(1.0% BW, 1.5 kg)/wk
       default 0.5% BW/wk if BMI < 25 or BF ≤ 15% (men) / ≤ 25% (women), else 0.75%
       flag > 0.75% as aggressive for lean users
gain:  default 0.25% BW/wk; allowed 0.1–0.5%; flag > 0.5% "mostly fat gain likely"
```

The bands are Consensus (Moderate) [R57, R63]; the defaults, the 0.75% "aggressive" flag, the 0.1% gain minimum and the BMI/BF% cut-points for choosing a default are Inference (Low) [design choice — no source; tune by replay]. The 1.5 kg/week cap is the app's existing value. The current 0.5 kg default is 0.83% BW at 60 kg but 0.42% at 120 kg [calc], which is why % BW scales better.

### Floors and low energy availability

A VLCD (≤800 kcal) is by definition clinically supervised ([NIDDK](https://www.niddk.nih.gov/Dictionary/V/very-low-calorie-diet)) [confirmed] [R67]. NICE NG246 reserves it for clinical programmes ([NICE](https://www.nice.org.uk/guidance/NG246)) [confirmed existence] [R68]. The 1,200/1,500 figures are the AHA/ACC/TOS *prescription* ranges for women and men ([PubMed 24222017](https://pubmed.ncbi.nlm.nih.gov/24222017/)) [recalled] [R69]. They are conventions, not physiological minimums, and both researchers found no stronger basis.

```
floor = 1200 (female) | 1500 (male) [R69] | 1350 (unspecified: Inference — midpoint, no source)
target ≥ max(floor, T̂ − min(0.25·T̂, ρ(F)·0.01·W/7))     [design choice — no source; 1% BW/wk from R63]
warn if target < RMR                                         [design choice — no source]
remove the 800 option (or gate behind an explicit medical-supervision acknowledgement)   [R67, R68]
if FFM known and workouts logged: caution when (target − exercise kcal)/FFM < 30 kcal/kg for > 2 weeks   [R70; "> 2 weeks" is a design choice — no source]
```

The 30 kcal/kg FFM figure comes from Loucks & Thuma ([doi](https://doi.org/10.1210/jc.2002-020369)) [recalled] [R70] (measured per kg lean body mass in sedentary women over 5 days). The 2023 IOC REDs statement frames low energy availability as a spectrum ([Amsterdam UMC](https://pure.amsterdamumc.nl/en/publications/2023-international-olympic-committees-ioc-consensus-statement-on-/)) [confirmed] [R71]. Whether it keeps 30 as a hard number is unverified, so present this as a caution, not a block. Consensus; Moderate.

### Adherence band

**Keep ±10%.** US labels may understate calories by up to 20% before a product is misbranded ([eCFR 101.9](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9)) [recalled] [R72]. Any tighter band would measure label noise [Inference]. No study validates a particular band width [negative finding of this research].

## Strength: cap the estimate, progress by percentage, deload volume instead of load

### Current behaviour
`Compound/Managers/Training/Progression/ProgressionEngine.swift` handles progression:

- Double progression over the last 3 sessions, with an RPE gate.
- Increments of 2.5 kg / 5 lb, or the machine's own increment.
- A −10% reset after two sessions with misses.
- In-session −5% / +1 increment, off by default.

The mesocycle deload multiplies load by 0.65, leaves sets and reps unchanged, and does not round. Warm-ups are 1–3 sets at 50/70/90% with reps equal to working reps. Rest is a fixed 90 s. e1RM is uncapped Epley that ignores RPE. Tonnage excludes bodyweight.

### e1RM: Epley with a cap and RIR

Every common equation agrees closely at low reps and diverges above about 10 [R73]. Reynolds et al. concluded "no more than 10 repetitions should be used" ([Reynolds 2006](https://www.unm.edu/~rrobergs/478RMStrengthPrediction.pdf)) [confirmed] [R73]. No equation is consistently best. Lombardi won for one sample ([DOAJ](https://doaj.org/article/248a0c4089a641d5b87f1ca3f9770895)) [confirmed] [R74] (men's bench and squat). Reps at a given %1RM differ with training background: at 70% 1RM, endurance athletes did 39.9 reps against 17.9 for weightlifters ([PMC4042664](https://pmc.ncbi.nlm.nih.gov/articles/PMC4042664)) [confirmed] [R75]. Lifters underpredict reps-to-failure by about **0.95 reps**, with accuracy worse above 12 reps and at light loads ([sportRxiv](https://sportrxiv.org/index.php/server/preprint/view/67); published version [R76]) [confirmed] [R76].

```
n     = reps + RIR            RIR = 10 − RPE [R77, RIR-based RPE scale]; RPE not logged → n = reps (no RIR credit), and treat effort as unknown, not RPE 10, in gates
e1RM  = w                     if n = 1
      = w · (1 + n/30)        if 2 ≤ n ≤ 10      [Epley form, R78 (Unreviewed); cap from R73]
      = excluded from e1RM/PR analytics (still logged)    if n > 10
display as an estimate (±5–10%) [Inference — no source for the band]; PRs = rep-max PRs at a given rep count; e1RM for trend lines
current e1RM per exercise = recency-weighted (half-life ≈ 3–4 weeks), weight 1/variance rising with n and RIR   [design choice — no source; tune by replay]
```

**Modify** e1RM along these lines. The cap is High certainty [R73]; RIR adjustment Moderate [R76, R77]. Logged RIR slightly *underestimates* e1RM, which is the conservative direction [derived from R76's under-prediction finding]. The r = 1 fix removes Epley's 1.033 inflation [calc: 1 + 1/30], which lets a lighter single "beat" a heavier one.

The self-correcting extension fits a per-user, per-exercise slope k in %1RM(n) = 1/(1 + n/k). The prior is k = 30 with an SD spanning about 20–45. The slope is updated whenever a heavy set (n ≤ 3) and a near-failure higher-rep set fall within two weeks of each other. This is defensible in direction (individual curves differ, R75) but entirely Inference (Low) [design choice — no source; tune by replay]. Most users rarely test heavy, so the prior will dominate. Ship it last.

### Progression and increments

Load progression and rep progression grow muscle equally ([PeerJ 14142](https://peerj.com/articles/14142)) [confirmed] [R79]. RPE-based loading performed at least as well as %1RM loading ([PubMed 29628895](https://pubmed.ncbi.nlm.nih.gov/29628895/)) [confirmed] [R80]. Hypertrophy improves closer to failure, while strength is driven more by load (Robinson 2024, [Abertay](https://rke.abertay.ac.uk/en/publications/exploring-the-dose-response-relationship-between-estimated-resist/)) [confirmed] [R81]. The existing double progression with an RPE gate is sound. **Keep**, and modify three details.

```
target RIR: compounds 1–3, isolation/machines 0–2, novices 2–3      [Inference from R81, R82, R76 — no source gives these exact bands]
add load when all working sets hit top of range AND last-set RIR ≥ target RIR
          (no RPE logged → top of range on 2 consecutive sessions; ACSM 2009, doi:10.1249/MSS.0b013e3181915670 [recalled]) [R83]
increment: desired % = 5% lower-body compound, 2.5–5% upper-body compound, 5–10% isolation   [design choice within ACSM's 2–10%, R83]
           round to the smallest available plate/machine step;
           if that step > 10% of working load → progress reps (or a set) instead    [R83 upper bound; R79]
next load after a change = e1RM_cal × 1/(1 + (target_reps + target_RIR)/30), rounded to available plates   [derived: inverse Epley, R78]
```

The percentage rule extends ACSM's 2–10% band [R83]. No trial compares absolute with percentage increments (Moderate) [negative finding of this research]. The fallback to reps is justified by Plotkin's equivalence result [R79]. The motivating example: 2.5 kg on a 12 kg lateral raise is a 21% jump [calc].

### Resets and deloads

Deloading is "ubiquitous yet under-researched" ([Delphi, DOAJ](https://doaj.org/article/599784d71dff41b197ff5cf66a3d11dd)) [confirmed] [R84]. Among 246 strength and physique athletes, a typical deload lasted **6.4 days every 5.6 weeks**. It cut reps and sets, reduced load and effort (more RIR), and kept frequency ([DOAJ](https://doaj.org/article/7d15e260e0ac4cff9e8c685dd7335389)) [confirmed] [R85]. Coaches favour reducing volume and effort ([PubMed 36619355](https://pubmed.ncbi.nlm.nih.gov/36619355/)) [confirmed] [R86]. The only RCT found that a full week off mid-programme did not change hypertrophy and slightly reduced strength gains ([PeerJ 16777](https://peerj.com/articles/16777)) [confirmed] [R87].

The app's ×0.65 load with unchanged sets cuts the variable practitioners keep and keeps the variable they cut [Inference from R85, R86]. **Replace**:

```
deload week: sets × 0.5–0.6 (e.g. 4 → 2), reps in range, load × 0.85–0.95 (or same load, target RIR +2 → 4–5),
             frequency unchanged, rounded to available plates; every 4–8 weeks or when triggered (stalled
             e1RM trend, rising RPE at fixed load); optional for beginners
reset (exercise level): after 2 consecutive sessions below min reps at RPE ≥ 9.5,
             re-derive load from calibrated e1RM at target reps + RIR (typically −5–10%)
```

The deload is Consensus/practice (Low) [R84–R86; the exact multipliers 0.5–0.6 and 0.85–0.95, the RIR +2 and the 4–8-week interval are a design choice — no source; tune by replay]. The reset is Inference that replaces a fixed −10% practitioner convention (Starting Strength [R88], 5/3/1 training-max style [R89]; Unreviewed). The RPE ≥ 9.5 and two-session triggers are a [design choice — no source]. Merging the two concepts also resolves the inventory's "two deload rules" conflict.

### Warm-ups and rest

Few-rep, higher-load specific warm-ups improved squat velocity over light ones ([PMC7558980](https://pmc.ncbi.nlm.nih.gov/articles/PMC7558980)) [confirmed] [R90]. Two sets of 6 at 40% and 80% of the training load beat no warm-up ([JOMH](https://article.imrpress.com/journal/JOMH/17/4/10.31083/jomh.2021.069/226-233%20JOMH2021041602.pdf)) [confirmed] [R91]. Reps equal to working reps at 90% of working load is effectively an extra working set [Inference — no source]. **Modify**:

```
sets: isolation or working load < 40% e1RM → 0–1; compounds → 2–4 (scale with working load relative to e1RM, not absolute kg)
loads: ~45%, ~65%, ~82% of working weight; reps taper 8 → 5 → 3 (→ 1–2); rest after warm-ups 45–60 s
```

The direction is Moderate [R90, R91]; the exact numbers are Low [design choice — no source; the ~40%/80% anchors come from R90, R91].

Longer rest preserves volume in trained lifters [R83; Inference from the volume-load mechanism discussed in R92]. A 2024 Bayesian meta-analysis found only small, uncertain hypertrophy benefits beyond about 60–90 s: thigh 0.17 (95% CrI −0.13 to 0.43) ([PubMed 39205815](https://pubmed.ncbi.nlm.nih.gov/39205815/)) [confirmed] [R92]. ACSM recommends 2–3 min for heavy core lifts and 1–2 min for assistance work [recalled] [R83]. **Modify** the fixed 90 s to: heavy multi-joint work (≤6 reps or ≥80% e1RM) 180 s, other multi-joint 120 s, isolation 75–90 s, always user-overridable [design choice within R83's ranges; the ≤6-rep / ≥80% cut-off has no source]. The "+30 s if RPE ≥ 9" add-on is Inference with no source.

### Tonnage

Excluding bodyweight makes pull-up, dip and push-up tonnage zero. Force-plate data put a push-up at about **64% of body mass** ([ISBS](https://ojs.ub.uni-konstanz.de/cpa/article/view/4457)) [confirmed via secondary] [R93], or about 69–75% top to bottom ([PubMed 20179649](https://pubmed.ncbi.nlm.nih.gov/20179649)) [recalled numbers; PMID confirmed] [R94]. **Modify** to tonnage = (BW × factor + added load − assistance) × reps:

| Exercise | Factor |
|---|---|
| Pull-up, chin-up, dip | 1.0 [Inference from mechanics — no measured source] |
| Push-up | 0.65–0.70 [R93, R94] |
| Knee push-up | 0.5 [R93 ≈49%; R94 ≈54–62%] |
| Inverted row | ≈0.5–0.6 (unsourced) |

Store bodyweight tonnage in a separate field so historical comparisons stay consistent. Moderate.

## Volume: one band for every muscle, counted by hard sets, adjusted by the user's own response

### Current behaviour
`Compound/Managers/Training/Exercise/Models/MuscleVolume.swift` counts a primary muscle as 1 set and a secondary as 0.5. It counts completed non-warm-up sets regardless of effort, load or reps, over rolling 7 days. The fixed bands are 10–20 sets/week for chest, lats, upper back, quads, hamstrings and glutes, and 6–12 for every other muscle, identical for every user.

### Verdict and evidence

**Fractional counting: Keep.** This is the best-supported part of the algorithm. Pelland et al. analysed 67 studies and 2,058 participants. Counting indirect sets as 0.5 predicted both hypertrophy and strength better than counting them as 1 or 0 ([sponet](https://sponet.de/sponet/Record/4097139?lng=en)) [confirmed] [R95]. The weaker point is *which* muscles an exercise lists as secondary, not the 0.5 coefficient [Inference]. Peer-reviewed; Moderate.

**The 10–20 band: Keep, re-presented.** Hypertrophy rises with weekly hard sets along a diminishing, roughly square-root curve with no clear plateau below about 20. Strength saturates much earlier (Pelland, [SportRxiv](https://sportrxiv.org/index.php/server/preprint/view/460)) [confirmed] [R95, R96 (preprint, Unreviewed); the "square-root" shape was relayed by a commentary]. Earlier, Schoenfeld 2017 found about +0.37% growth per extra weekly set ([doi](https://doi.org/10.1080/02640414.2016.1210197); link corrected, see checklist) [confirmed] [R97]. In trained men, 12–20 sets "may be an optimum", and *triceps* did better above 20 ([PMC8884877](https://pmc.ncbi.nlm.nih.gov/articles/PMC8884877/)) [confirmed] [R98]. Peer-reviewed; Moderate–High.

**The 6–12 band for small muscles: Replace.** No meta-analysis supports a lower band for small muscles [negative finding of this research], and the only muscle-level signal (triceps) points the other way [R98]. Use the same tiers for every muscle:

| Fractional sets per week | Label |
|---|---|
| Fewer than 4 | Below maintenance |
| 4–9 | Maintaining |
| 10–20 | Productive |
| More than 20 | High: fine if progressing and recovering |

The 0.5 credit already gives arms and delts 5–10 sets from compound lifts [calc]. The tier labels and the <4 / 4–9 cut-points are Inference [design choice — no source; "maintaining" is anchored loosely on R105].

**What counts as a hard set: Modify.** Hypertrophy improves as sets end closer to failure (Robinson 2024) [confirmed] [R81]. Training all the way to failure is only trivially better, ES 0.19 ([PMC9935748](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9935748/)) [confirmed] [R82]. Loads from about 30% 1RM up work when taken near failure ([BISp](https://www.bisp-surf.de/Record/PU201603001398)) [confirmed] [R99, R100; the ~30% figure is stated in R100].

```
counts as 1 set if: not a warm-up AND 5 ≤ reps ≤ 30 AND (RPE missing OR RPE ≥ 6)   [rep range from R100; RPE ≥ 6 is a design choice — no source]
optional effort weight: RIR 0–3 → 1.0, RIR 4–5 → 0.5                                 [design choice — no source; direction from R81]
drop sets / myo-reps: 1 + 0.5 per extra mini-set, max 2                              [design choice — no source]
do not weight by load for hypertrophy; surface %e1RM ≥ 75–80% separately for strength goals   [R99, R81; the 75–80% cut-off is a design choice]
```

The effort weights and drop-set rule are Inference (Low). Missing RPE counts as a full set so users who do not log RPE are not penalised.

**Frequency.** With volume equated, frequency does not change hypertrophy ([Stronger By Science](https://www.strongerbyscience.com/frequency/), Unreviewed secondary; [ECU](https://ro.ecu.edu.au/ecuworkspost2013/5665)) [confirmed] [R101]. Strength does benefit from frequency [R95]. Keep counting weekly volume, set no hypertrophy frequency target, and keep ≥2 days/week as the guideline floor ([ACSM 2026](https://acsm.org/resistance-training-guidelines-update-2026/)) [confirmed] [R102].

### The self-correcting volume rule

A within-subject RCT found that training at **1.2× a person's own habitual volume beat a standard 22 sets/week** (+1.08 cm² CSA; [PubMed 32108724](https://pubmed.ncbi.nlm.nih.gov/32108724/)) [confirmed] [R103]. Another trial found a +120% increase no better than +20% ([PDF](https://www.fisiologiadelejercicio.com/wp-content/uploads/2026/07/Large-increases-in-resistance-training-volume-do-not-impair-muscle-hypertrophy.pdf)) [confirmed] [R104]. Maintenance needs very little: about one session and one set per exercise per week in younger adults, provided intensity is kept, and more in older adults ([PubMed 33629972](https://pubmed.ncbi.nlm.nih.gov/33629972/)) [confirmed] [R105]. The MEV/MAV/MRV "landmarks" are coaching heuristics with no validation (Unreviewed) [R106]. No closed-loop volume algorithm has been trialled [negative finding of this research], so the rule below is defensible in direction but engineered in detail (Inference; Low) [design choice — no source; tune by replay; the +10–20% step follows R103, R104 and the 4-set floor follows R105]:

```
per muscle, every 2–3-week block:
  baseline   = median fractional hard sets/week over last 4 weeks (new users: clamp into 10–20)
  trend      = slope of capped, RIR-adjusted e1RM (or reps at fixed load) on exercises where the muscle is primary, %/week
  if adherence to planned sets < 80%           → hold (fix consistency first)
  elif trend > +0.5%/wk and RPE at fixed load stable → hold
  elif |trend| ≤ 0.5%/wk and recovery fine     → +10–20% (≈ 1–3 sets/week)
  elif trend < −0.5%/wk or RPE at fixed load ↑ ≥ 1 or poor recovery → −20–33% or deload week
  guardrails: floor 4 fractional sets (6 if age ≥ 60); one step per block; > 20–25 shows "high volume" copy, no block
```

The ±0.5%/week noise threshold is a placeholder (**Tune**). Session-to-session e1RM variability for gym-goers was not researched, and the threshold should be set from replayed training logs, just as the nutrition filter is. Name the feature "adjusts based on your progress", never "your MRV".

## Habits, steps and body ratios: mostly keep, add bands and forgiveness

**Weekly streak (default 3/week): Keep, add forgiveness.** WHO 2020 and ACSM 2026 set ≥2 strength days/week ([PMC9219310](https://pmc.ncbi.nlm.nih.gov/articles/PMC9219310)) [confirmed] [R107, R102]. In Lally's study, missing a single opportunity did not materially affect habit formation, and automaticity plateaued after a median of 66 days ([James Clear summary](https://jamesclear.com/new-habit), Unreviewed secondary) [confirmed via secondary] [R108]. In Milkman's 61,000-member megastudy, **the top arm rewarded returning after a missed workout**, though only about 8% of effects outlasted the four-week programme ([Penn Today](https://penntoday.upenn.edu/news/wharton-study-best-ways-boost-workout-habits)) [confirmed] [R109].

Add three things. First, a return-after-miss reward [R109]. Second, one grace week per N weeks, or count a week as met at goal − 1 after a miss [design choice — no source; motivated by R108]. Third, never auto-lower the goal below 2/week [R107, R102]. "Habit forming" copy is justified at about 6–10 weeks [Inference from R108 (66 days ≈ 9–10 weeks) and R110 (6 weeks)], as encouragement rather than a threshold. Kaushal & Rhodes' ≥4 sessions/week for 6 weeks ([UVic](https://dspace.library.uvic.ca/items/113699e5-2131-4f46-8ec6-2180cffed8c3/full)) [confirmed] [R110] is observational and should not become the default. Consensus plus behavioural evidence; Moderate for the goal, Low for the streak mechanics.

**Step goal (8,000): Keep, add an age adjustment.** In Paluch 2022, mortality benefit plateaued at about 8,000–10,000 steps under age 60 and 6,000–8,000 at 60 and over ([doi](https://doi.org/10.1016/S2468-2667%2821%2900302-9)) [recalled] [R111]. Ding 2025 found **HR 0.53 at 7,000 vs 2,000 steps**, with the inflection at about 5,000–7,000 ([PubMed 40713949](https://pubmed.ncbi.nlm.nih.gov/40713949/)) [confirmed] [R112]. Default to 8,000 under 60 and 7,000 at 60 and over [design choice within R111, R112]. Observational; Moderate.

**Body ratios: Modify by adding screening bands.** NICE NG246 bands for waist-to-height ratio are 0.40–0.49 healthy, **0.50–0.59 increased risk** and **≥0.60 high risk**. They apply to all sexes and ethnicities, including people with high muscle mass, for BMI < 35, with the message "keep your waist to less than half your height" ([NICE NG246](https://www.nice.org.uk/guidance/NG246/chapter/Identifying-and-assessing-overweight-obesity-and-central-adiposity)) [confirmed] [R68]. The <0.40 band was not confirmed in the text. For waist-to-hip ratio, ≥0.90 (men) and ≥0.85 (women) mark substantially increased risk ([WHO IRIS](https://iris.who.int/handle/10665/44583)) [recalled] [R113]. Label both "screening, not diagnosis". Guideline; Moderate. WHtR is the better-supported ratio for lifters [R68 explicitly includes high-muscle-mass adults].

**Weekly review and Today.** Use trend weight L rather than raw weight for "weekly weight change". Mean RPE and volume % change need no algorithmic change.

## Citations to verify before shipping

The network proxy blocked PubMed, PMC, Europe PMC, NAP, Nature, SportRxiv and arXiv full texts. Every item below either feeds a constant in code or would appear in user-facing copy, and was recalled or relayed second-hand. The full per-source checklist, with DOIs, what to check and the discrepancies found by a later verification pass, is in `docs/research/citation-verification-checklist.md`:

| Item | What to check | Where it is used |
|---|---|---|
| 2023 DRI EER male low-active, active and very-active coefficients; PAL band edges; women's coefficients against Table S-1 | Exact numbers ([NAP](https://nap.nationalacademies.org/read/26818/chapter/2)) | Formula prior |
| Mifflin coefficients; Cunningham 500 + 22·FFM; ten Haaf FFM and weight forms | Exact coefficients | RMR |
| Forbes 10.4 constant; 9,440 / 1,816 kcal/kg; Hall 2008 worked values | Constants ([PMC2376744](https://pmc.ncbi.nlm.nih.gov/articles/PMC2376744)) | ρ(F) |
| Hall 2011 ≈24 kcal/day per kg (100 kJ/day per kg) | Interpretation as the TEE slope | ε, timeline |
| Bajunaid 2025 coefficients and interval width | Not retrieved | Future plausibility screen |
| Westerterp 2004 TEF 10% and per-macro ranges | Numbers | TEF slice |
| ACSM walking equation; stride ≈0.413–0.415 × height | Equation; stride heuristic unverified | Step nowcast |
| AHA/ACC/TOS 1,200–1,500 / 1,500–1,800 kcal ranges | Wording (prescription, not floor) | Floors copy |
| Loucks & Thuma 30 kcal/kg FFM; whether IOC REDs 2023 keeps a numeric threshold | Threshold wording | LEA caution |
| Morton 2018 CI 1.03–2.20 g/kg; Helms 2.3–3.1 g/kg FFM; Nunes/Tagawa inflection points | Numbers | Protein copy |
| Feinman 2015 keto 20–50 g/day; Iraki 2019 fat 0.5–1.5 g/kg and gain 0.25–0.5%/wk | Numbers | Keto, fat floor, gain rate |
| Garthe 2011 0.7% vs 1.4%; Purcell 2014; Ashtary-Larky 2020 pooled values | Numbers | Rate copy |
| Epley/Brzycki/etc. forms; ACSM 2009 "+1–2 reps twice → +2–10%"; Schoenfeld 2016 rest; Grgic 2017/2018 | Exact wording | Progression, rest |
| Tinsley muscular-athlete paper year and coefficients | Year and numbers | RMR copy only |
| Pelland follow-up preprint (~31 / ~3 fractional sets PUOS; +3.27% strength per extra day) | Preprint relayed by search | Do not quote numerically yet |
| Aube 2022 author list; Enes population and venue; Brigatto set counts | Attribution | Volume copy |
| Milkman 27% top-arm figure; Lally analysable n; Kaushal & Rhodes "four bouts" definition | Numbers | Streak copy |
| NICE WHtR < 0.40 band; WHO WHR cut-offs; Paluch 2022 plateaus | Bands | Body ratios, steps |
| Suprak 2011 push-up 69–75% | Numbers | Tonnage factors |

Beyond these checks, no validated reference exists for the controller's deadband and step limit, the filter's process noises, the volume-rule thresholds or the per-exercise e1RM calibration. Those are tuned by replay, not by reading.

## Implementation roadmap

Order the work by evidence strength and blast radius. Constants first, then the trend and filter, then progression and volume structure. Each phase that touches the formula TDEE, the expenditure engine, the weight trend, e1RM or weekly sets must, in the same change:

1. Mirror the Swift change in `functions/coach-maths.js`.
2. Regenerate `CompoundUnitTests/Fixtures/coach-parity.json` from the Swift. The fixture is generated from the Swift and checked by both `CoachParityTests.swift` and `functions/coach-maths.test.js`.
3. Run `-only-testing:CompoundUnitTests/CoachParityTests` and `npm test` in `functions/`.
4. Because the coach reads these numbers, run `node scripts/coach-eval.js` from `functions/`.
5. Update `docs/specs/adaptive-expenditure.md`, `docs/specs/smart-progression.md` and `docs/specs/weekly-check-in.md` to cite the sources.
6. Deploy Cloud Functions, since `functions/` changes have no effect until then.

| Phase | Change | Files (indicative) | Parity/fixture |
|---|---|---|---|
| **0. Safety and constants (days)** | Remove the 800 kcal floor; sex-specific 1,200/1,500/1,350 floors plus the relative cap and below-RMR warning. One `energyDensity` (7700 for now) replacing 3500/lb. Epley cap n ≤ 10, w at n = 1, RIR included. Keto 30 g cap; fat floor 0.5 g/kg; relabel 2.6 g/kg; protein reference weight; ≥65 floor. Delete the TargetProposal rate-error term. minWindowDays 14→28 (21 with inflated variance); minLoggedFraction 0.5→0.8; exclude partial days. Progress and Today use trend weight | `NutritionManager.swift`, onboarding goal-rate screen, `TargetProposal.swift`, `ExpenditureWindowStats.swift`, e1RM helper | Yes: engine, e1RM |
| **1. Prior and display honesty (1–2 weeks)** | Replace the additive PAL with the DRI EER (or the corrected PAL table); drop the frequency add-on; Cunningham instead of Katch-McArdle, gated on trusted BF%; TEF = 10% of TDEE; net step constant 0.0004; dedupe `ExpenditurePresenter` onto the manager's formula; RMR ±10% copy; WHtR/WHR bands; age-adjusted step goal; forgiving streak | `NutritionManager.swift`, `ExpenditurePresenter.swift`, `ExpenditureEngine.swift` (step nowcast), body-ratio and Today screens | Yes: formula TDEE |
| **2. Training quick fixes (1–2 weeks)** | Deload = sets ×0.5–0.6, load ×0.85–0.95, rounded; reset re-derived from e1RM; % increments with rep fallback; warm-up taper; rest by exercise type; bodyweight tonnage factors; hard-set counting rule; single volume band and tier labels | `ProgressionEngine.swift`, mesocycle deload code, warm-up/rest generators, `MuscleVolume.swift` | Yes: weekly sets |
| **3. One trend (2 weeks)** | Replace both EMAs with the filter's weight block, using time-based Δt and the Huber update; RTS smoothing for the chart; opt-in menstrual R inflation | `WeightTrendCalculator.swift`, `ExpenditureEngine.swift:246-270` | Yes: weight trend |
| **4. The three-state filter and controller (3–4 weeks + replay)** | [L, E, T] filter replacing raw/blend/clamp; SD display, badge and "calibrating" state; weekly deadband controller with adherence check; balance cards read T̂; ρ(F) where BF% is trusted; dynamic timeline or a "target steps down" caveat. **Tune** q_E, q_T, q_L, R_W and the deadband on replayed anonymised histories, scored by prediction error, 80%-interval coverage and proposals per month | `ExpenditureEngine.swift`, `ExpenditureWindowStats.swift`, `TargetProposal.swift`, balance/deficit cards | Yes: engine and samples; add filter-state cases to the fixture |
| **5. Self-correction for training (later)** | Volume rule per muscle per block; per-exercise e1RM calibration of k; training-day-linked calorie cycling | `MuscleVolume.swift`, `ProgressionEngine.swift`, `computeDietPlan` | Yes: weekly sets, e1RM |

Phase 0 is safe to ship before any replay data exist. Most of it removes unsupported options or adds caps that the literature agrees on. Phases 3 and 4 should ship behind a flag, with the old engine running in shadow until replay shows the filter's intervals are calibrated.

## Conclusion

The real problem with Compound's maths is not that it guesses where science is silent. It is that it guesses *invisibly*: fixed gains, clamps and duplicate loops that cannot be cited, tuned or explained. Each proposed replacement turns a hidden guess into one of three things. Some become a published constant (ρ(F), the EER, the rep cap). Some become a stated variance (weigh-in noise, TDEE drift). The rest become a tunable parameter that the app's own data can calibrate. Even the parts no paper validates, such as the filter's noises, the controller's deadband and the volume thresholds, become defensible once they are explicit, are scored on replayed data, and show their uncertainty to the user.

Two findings change the priorities. First, the energy density largely cancels inside a closed loop, so the Forbes correction matters mainly for the displayed TDEE and timelines, not for whether users hit their rate. That puts ρ(F) behind the double-counting rate-error term, which actively mis-steers non-adherent users today. Second, the three-state filter does more than merge the two researchers' proposals. Its behaviour matches each user's data: it is a trend line for people who only weigh in, and an expenditure estimator for people who also log food. One design therefore serves both audiences, with honest error bars for each.

## References

Each entry gives the DOI as a link where one exists; otherwise a stable URL or full bibliographic reference. **(DOI recalled)** marks a DOI that was not confirmed by search during the verification pass; **(DOI not found)** means it must be located by hand. **Unreviewed** marks a source that is not peer reviewed. The verification status of every entry is in `docs/research/citation-verification-checklist.md`.

**Energy expenditure**

- **R1.** Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO (1990). A new predictive equation for resting energy expenditure in healthy individuals. *Am J Clin Nutr* 51(2):241–247. https://doi.org/10.1093/ajcn/51.2.241
- **R2.** Roza AM, Shizgal HM (1984). The Harris Benedict equation reevaluated: resting energy requirements and the body cell mass. *Am J Clin Nutr* 40(1):168–182. https://doi.org/10.1093/ajcn/40.1.168 (DOI recalled)
- **R3.** McArdle WD, Katch FI, Katch VL. *Exercise Physiology: Nutrition, Energy, and Human Performance.* Wolters Kluwer (textbook, several editions; source of the Katch-McArdle 370 + 21.6·LBM form). No DOI; check the edition.
- **R4.** Frankenfield D, Roth-Yousey L, Compher C (2005). Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review. *J Am Diet Assoc* 105(5):775–789. https://doi.org/10.1016/j.jada.2005.02.005
- **R5.** Madden AM, Mulrooney HM, Shah S (2016). Estimation of energy expenditure using prediction equations in overweight and obese adults: a systematic review. *J Hum Nutr Diet* 29(4):458–476. https://doi.org/10.1111/jhn.12355 (DOI and author list recalled) — record: https://uhra.herts.ac.uk/id/eprint/5072/
- **R6.** O'Neill JER, Corish CA, Horner K (2023). Accuracy of resting metabolic rate prediction equations in athletes: a systematic review with meta-analysis. *Sports Med* 53(12):2373–2398. https://doi.org/10.1007/s40279-023-01896-z
- **R7.** Tinsley GM, Graybeal AJ, Moore ML (2019). Resting metabolic rate in muscular physique athletes: validity of existing methods and development of new prediction equations. *Appl Physiol Nutr Metab* 44(4):397–406. https://doi.org/10.1139/apnm-2018-0412 (DOI recalled)
- **R8.** Cunningham JJ (1980). A reanalysis of the factors influencing basal metabolic rate in normal adults. *Am J Clin Nutr* 33(11):2372–2374. https://doi.org/10.1093/ajcn/33.11.2372
- **R9.** ten Haaf T, Weijs PJM (2014). Resting energy expenditure prediction in recreational athletes of 18–35 years: confirmation of Cunningham equation and an improved weight-based alternative. *PLoS One* 9(10):e108460. https://doi.org/10.1371/journal.pone.0108460
- **R10.** FAO/WHO/UNU (2004). *Human energy requirements: report of a joint FAO/WHO/UNU expert consultation, Rome, 17–24 October 2001.* FAO Food and Nutrition Technical Report Series 1. Rome: FAO. https://www.fao.org/4/y5686e/y5686e00.htm (no DOI)
- **R11.** Pontzer H, et al. (2016). Constrained total energy expenditure and metabolic adaptation to physical activity in adult humans. *Curr Biol* 26(3):410–417. https://doi.org/10.1016/j.cub.2015.12.046
- **R12.** Pontzer H, Raichlen DA, Wood BM, Mabulla AZP, Racette SB, Marlowe FW (2012). Hunter-gatherer energetics and human obesity. *PLoS One* 7(7):e40503. https://doi.org/10.1371/journal.pone.0040503
- **R13.** Böning D (2018). Fat in spite of exercise? An alleged paradigm change results from calculation mistakes (editorial). *Dtsch Z Sportmed* 69(1):3–4. https://doi.org/10.5960/dzsm.2017.311
- **R14.** National Academies of Sciences, Engineering, and Medicine (2023). *Dietary Reference Intakes for Energy.* Washington, DC: National Academies Press. https://doi.org/10.17226/26818 (DOI recalled; NAP book ID 26818 confirmed). Table S-1: https://nap.nationalacademies.org/read/26818/chapter/2
- **R15.** Health Canada. Dietary reference intakes tables: equations to estimate energy requirement (secondary republication). https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/equations-estimate-energy-requirement.html
- **R16.** Universidade de São Paulo teaching material, "Necessidades de energia – DRIs 2023" (secondary copy of Table S-1; Unreviewed). https://edisciplinas.usp.br/mod/resource/view.php?id=4749455
- **R17.** Institute of Medicine (2005). *Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids.* Washington, DC: National Academies Press. https://doi.org/10.17226/10490 (DOI recalled; source of the AMDRs and of the 2005 PAL categories)
- **R18.** Bajunaid R, et al. (2025). Predictive equation derived from 6,497 doubly labelled water measurements enables the detection of erroneous self-reported energy intake. *Nat Food* 6(1):58–71. https://doi.org/10.1038/s43016-024-01089-5 — Author correction: https://doi.org/10.1038/s43016-025-01175-2
- **R19.** Pontzer H, et al. (2021). Daily energy expenditure through the human life course. *Science* 373(6556):808–812. https://doi.org/10.1126/science.abe5017
- **R20.** Westerterp KR (2004). Diet induced thermogenesis. *Nutr Metab (Lond)* 1:5. https://doi.org/10.1186/1743-7075-1-5
- **R21.** American College of Sports Medicine. *ACSM's Guidelines for Exercise Testing and Prescription*, 11th ed. Philadelphia: Wolters Kluwer, 2021 (metabolic equations for walking). No DOI.
- **R22.** Minetti AE, Moia C, Roi GS, Susta D, Ferretti G (2002). Energy cost of walking and running at extreme uphill and downhill slopes. *J Appl Physiol* 93(3):1039–1046. https://doi.org/10.1152/japplphysiol.01177.2001 (DOI recalled)

**Energy density of weight change**

- **R23.** Wishnofsky M (1958). Caloric equivalents of gained or lost weight. *Am J Clin Nutr* 6(5):542–546. https://doi.org/10.1093/ajcn/6.5.542
- **R24.** Hall KD (2008). What is the required energy deficit per unit weight loss? *Int J Obes* 32(3):573–576. https://doi.org/10.1038/sj.ijo.0803720
- **R25.** Hall KD, Sacks G, Chandramohan D, Chow CC, Wang YC, Gortmaker SL, Swinburn BA (2011). Quantification of the effect of energy imbalance on bodyweight. *Lancet* 378(9793):826–837. https://doi.org/10.1016/S0140-6736(11)60812-X — Web appendix: https://www.niddk.nih.gov/-/media/Files/BWP/Hall_Lancet_Web_Appendix.pdf
- **R26.** Hall KD (2007). Body fat and fat-free mass inter-relationships: Forbes's theory revisited. *Br J Nutr* 97(6):1059–1063. https://doi.org/10.1017/S0007114507691946
- **R27.** Forbes GB (1987). Lean body mass–body fat interrelationships in humans. *Nutr Rev* 45(8):225–231. https://doi.org/10.1111/j.1753-4887.1987.tb02684.x (DOI recalled)
- **R28.** Heymsfield SB, et al. (2012). Energy content of weight loss: kinetic features during voluntary caloric restriction. *Metabolism* 61(7):937–943. https://doi.org/10.1016/j.metabol.2011.11.012
- **R29.** Kreitzman SN, Coxon AY, Szaz KF (1992). Glycogen storage: illusions of easy weight loss, excessive weight regain, and distortions in estimates of body composition. *Am J Clin Nutr* 56(1 Suppl):292S–293S. https://doi.org/10.1093/ajcn/56.1.292S (DOI recalled; not found by search)

**Weight trend, adaptive TDEE and control**

- **R30.** Schneditz D, et al. (2023). Day-to-day variability in euvolemic body mass. *Ren Fail* 45(2):2273421. https://doi.org/10.1080/0886022X.2023.2273421 (volume/issue recalled)
- **R31.** Orsama AL, Mattila E, Ermes M, van Gils M, Wansink B, Korhonen I (2014). Weight rhythms: weight increases during weekends and decreases during weekdays. *Obes Facts* 7(1):36–47. https://doi.org/10.1159/000356147
- **R32.** Turicchi J, O'Driscoll R, Horgan G, Duarte C, Palmeira AL, Larsen SC, Heitmann BL, Stubbs J (2020). Weekly, seasonal and holiday body weight fluctuation patterns among individuals engaged in a European multi-centre behavioural weight loss maintenance intervention. *PLoS One* 15(4):e0232152. https://doi.org/10.1371/journal.pone.0232152
- **R33.** Kanellakis S, et al. (2023). Changes in body weight and body composition during the menstrual cycle. *Am J Hum Biol* 35(11):e23951. https://doi.org/10.1002/ajhb.23951
- **R34.** Hall KD, Chow CC (2011). Estimating changes in free-living energy intake and its confidence interval. *Am J Clin Nutr* 94(1):66–74. https://doi.org/10.3945/ajcn.111.014399
- **R35.** Sanghvi A, Redman LM, Martin CK, Ravussin E, Hall KD (2015). Validation of an inexpensive and accurate mathematical method to measure long-term changes in free-living energy intake. *Am J Clin Nutr* 102(2):353–358. https://doi.org/10.3945/ajcn.115.111070
- **R36.** Lichtman SW, et al. (1992). Discrepancy between self-reported and actual caloric intake and exercise in obese subjects. *N Engl J Med* 327(27):1893–1898. https://doi.org/10.1056/NEJM199212313272701
- **R37.** Guo P, Rivera DE, Savage JS, Hohman EE, Pauley AM, Leonard KS, Downs DS (2020; online 2018). System identification approaches for energy intake estimation: enhancing interventions for managing gestational weight gain. *IEEE Trans Control Syst Technol* 28(1):63–78. https://doi.org/10.1109/TCST.2018.2871871
- **R38.** Guo P, Rivera DE, Savage JS, Downs DS (2017). State estimation under correlated partial measurement losses: implications for weight control interventions. *IFAC-PapersOnLine* 50(1):13532–13537 (20th IFAC World Congress). DOI not found — locate manually. Record: https://asu.elsevierpure.com/en/publications/state-estimation-under-correlated-partial-measurement-losses-impl/
- **R39.** Walker J. *The Hacker's Diet* (online edition, Fourmilab). Unreviewed. https://fourmilab.ch/hackdiet/www/subsubsection1_4_1_0_8_3.html
- **R40.** Martins C, et al. (2020). Metabolic adaptation is an illusion, only present when participants are in negative energy balance. *Am J Clin Nutr* 112(5):1212–1218. https://doi.org/10.1093/ajcn/nqaa220
- **R41.** Rauch HE, Tung F, Striebel CT (1965). Maximum likelihood estimates of linear dynamic systems. *AIAA J* 3(8):1445–1450. https://doi.org/10.2514/3.3166 (DOI recalled)
- **R42.** MacroFactor help centre, "How should I interpret changes to my energy expenditure?" (Unreviewed). https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure — see also Stronger By Science, "MacroFactor's algorithms and core philosophy" (Unreviewed). https://www.strongerbyscience.com/macrofactor-algorithms-philosophy/
- **R43.** Martin CK, et al. (2015). Efficacy of SmartLoss, a smartphone-based weight loss intervention: results from a randomized controlled trial. *Obesity* 23(5):935–942. https://doi.org/10.1002/oby.21063
- **R44.** Rivera DE and colleagues, control-systems formulation of adaptive behavioural interventions (gestational weight gain, model-predictive control). The article at PMC3856197 was not identified by search; it is probably one of the Dong/Rivera hybrid-MPC papers. DOI not found — locate manually. https://pmc.ncbi.nlm.nih.gov/articles/PMC3856197/
- **R45.** Guo J, Brager DC, Hall KD (2018). Simulating long-term human weight-loss dynamics in response to calorie restriction. *Am J Clin Nutr* 107(4):558–565. https://doi.org/10.1093/ajcn/nqx080
- **R46.** Thomas DM, Martin CK, Redman LM, Heymsfield SB, Lettieri S, Levine JA, Bouchard C, Schoeller DA (2014). Effect of dietary adherence on the body weight plateau: a mathematical model incorporating intermittent compliance with energy intake prescription. *Am J Clin Nutr* 100(3):787–795. https://doi.org/10.3945/ajcn.113.079822

**Macros, rates and floors**

- **R47.** Morton RW, et al. (2018). A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults. *Br J Sports Med* 52(6):376–384. https://doi.org/10.1136/bjsports-2017-097608
- **R48.** Nunes EA, et al. (2022). Systematic review and meta-analysis of protein intake to support muscle mass and function in healthy adults. *J Cachexia Sarcopenia Muscle* 13(2):795–810. https://doi.org/10.1002/jcsm.12922
- **R49.** Helms ER, Zinn C, Rowlands DS, Brown SR (2014). A systematic review of dietary protein during caloric restriction in resistance trained lean athletes: a case for higher intakes. *Int J Sport Nutr Exerc Metab* 24(2):127–138. https://doi.org/10.1123/ijsnem.2013-0054
- **R50.** Devries MC, Sithamparapillai A, Brimble KS, Banfield L, Morton RW, Phillips SM (2018). Changes in kidney function do not differ between healthy adults consuming higher- compared with lower- or normal-protein diets: a systematic review and meta-analysis. *J Nutr* 148(11):1760–1775. https://doi.org/10.1093/jn/nxy197
- **R51.** Weijs PJM (2025). Protein requirement in obesity. *Curr Opin Clin Nutr Metab Care* 28(1). https://doi.org/10.1097/MCO.0000000000001087 — PDF: https://pure.amsterdamumc.nl/ws/files/142148308/Protein-requirement-in-obesity.pdf
- **R52.** Dekker IM, van Rijssen NM, Verreijen A, Weijs PJM, de Boer WB, Terpstra D, Kruizenga HM (2022). Calculation of protein requirements: a comparison of calculations based on bodyweight and fat free mass. *Clin Nutr ESPEN* 48:378–385. https://doi.org/10.1016/j.clnesp.2022.01.014
- **R53.** Bauer J, et al. (2013). Evidence-based recommendations for optimal dietary protein intake in older people: a position paper from the PROT-AGE Study Group. *J Am Med Dir Assoc* 14(8):542–559. https://doi.org/10.1016/j.jamda.2013.05.021
- **R54.** Nunes CL, et al. (2022). Adaptive thermogenesis after moderate weight loss: magnitude and methodological issues. *Eur J Nutr* 61(3):1405–1416. https://doi.org/10.1007/s00394-021-02742-6 (cited in the filter parameter table)
- **R55.** Thomas DT, Erdman KA, Burke LM (2016). Position of the Academy of Nutrition and Dietetics, Dietitians of Canada, and the American College of Sports Medicine: nutrition and athletic performance. *J Acad Nutr Diet* 116(3):501–528. https://doi.org/10.1016/j.jand.2015.12.006 (DOI recalled)
- **R56.** Whittaker J, Wu K (2021). Low-fat diets and testosterone in men: systematic review and meta-analysis of intervention studies. *J Steroid Biochem Mol Biol* 210:105878. https://doi.org/10.1016/j.jsbmb.2021.105878 (DOI recalled; PMID 33741447 confirmed). Unreviewed summary: https://www.strongerbyscience.com/low-fat-diets-testosterone/
- **R57.** Iraki J, Fitschen P, Espinar S, Helms E (2019). Nutrition recommendations for bodybuilders in the off-season: a narrative review. *Sports* 7(7):154. https://doi.org/10.3390/sports7070154
- **R58.** Feinman RD, et al. (2015). Dietary carbohydrate restriction as the first approach in diabetes management: critical review and evidence base. *Nutrition* 31(1):1–13. https://doi.org/10.1016/j.nut.2014.06.011
- **R59.** Henselmans M, Bjørnsen T, Hedderman R, Vårvik FT (2022). The effect of carbohydrate intake on strength and resistance training performance: a systematic review. *Nutrients* 14(4):856. https://doi.org/10.3390/nu14040856 (DOI and author list recalled)
- **R60.** FAO (2003). *Food energy – methods of analysis and conversion factors.* FAO Food and Nutrition Paper 77. Rome: FAO. https://www.fao.org/4/y5022e/y5022e00.htm (no DOI; URL recalled)
- **R61.** Campbell BI, et al. (2020). Intermittent energy restriction attenuates the loss of fat free mass in resistance trained individuals: a randomized controlled trial. *J Funct Morphol Kinesiol* 5(1):19. https://doi.org/10.3390/jfmk5010019 — Authors' reply to a reanalysis: https://doi.org/10.3390/jfmk5040086
- **R62.** Peos JJ, Helms ER, Fournier PA, Krieger J, Sainsbury A (2021). A 1-week diet break improves muscle endurance during an intermittent dieting regime in adult athletes: a pre-specified secondary analysis of the ICECAP trial. *PLoS One* 16(2):e0247292. https://doi.org/10.1371/journal.pone.0247292
- **R63.** Helms ER, Aragon AA, Fitschen PJ (2014). Evidence-based recommendations for natural bodybuilding contest preparation: nutrition and supplementation. *J Int Soc Sports Nutr* 11:20. https://doi.org/10.1186/1550-2783-11-20
- **R64.** Garthe I, Raastad T, Refsnes PE, Koivisto A, Sundgot-Borgen J (2011). Effect of two different weight-loss rates on body composition and strength and power-related performance in elite athletes. *Int J Sport Nutr Exerc Metab* 21(2):97–104. https://doi.org/10.1123/ijsnem.21.2.97 (DOI recalled; matches volume/issue/page)
- **R65.** Purcell K, Sumithran P, Prendergast LA, Bouniu CJ, Delbridge E, Proietto J (2014). The effect of rate of weight loss on long-term weight management: a randomised controlled trial. *Lancet Diabetes Endocrinol* 2(12):954–962. https://doi.org/10.1016/S2213-8587(14)70200-1
- **R66.** Helms ER, et al. (2023). Effect of small and large energy surpluses on strength, muscle, and skinfold thickness in resistance-trained individuals: a parallel groups design. *Sports Med Open* 9:102. https://doi.org/10.1186/s40798-023-00651-y
- **R67.** National Institute of Diabetes and Digestive and Kidney Diseases. "Very-low-calorie diet" (health dictionary). https://www.niddk.nih.gov/Dictionary/V/very-low-calorie-diet
- **R68.** National Institute for Health and Care Excellence (2025). *Overweight and obesity management* (NICE guideline NG246). https://www.nice.org.uk/guidance/NG246 — WHtR chapter: https://www.nice.org.uk/guidance/NG246/chapter/Identifying-and-assessing-overweight-obesity-and-central-adiposity
- **R69.** Jensen MD, et al. (2014; online 2013). 2013 AHA/ACC/TOS guideline for the management of overweight and obesity in adults. *Circulation* 129(25 Suppl 2):S102–S138. https://doi.org/10.1161/01.cir.0000437739.71477.ee
- **R70.** Loucks AB, Thuma JR (2003). Luteinizing hormone pulsatility is disrupted at a threshold of energy availability in regularly menstruating women. *J Clin Endocrinol Metab* 88(1):297–311. https://doi.org/10.1210/jc.2002-020369
- **R71.** Mountjoy M, et al. (2023). 2023 International Olympic Committee's (IOC) consensus statement on Relative Energy Deficiency in Sport (REDs). *Br J Sports Med* 57(17):1073–1097. https://doi.org/10.1136/bjsports-2023-106994
- **R72.** US Code of Federal Regulations, Title 21, §101.9(g)(4)–(5) (nutrition labelling compliance). https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9

**Strength**

- **R73.** Reynolds JM, Gordon TJ, Robergs RA (2006). Prediction of one repetition maximum strength from multiple repetition maximum testing and anthropometry. *J Strength Cond Res* 20(3):584–592. https://doi.org/10.1519/00124278-200608000-00020 — full text: https://www.unm.edu/~rrobergs/478RMStrengthPrediction.pdf
- **R74.** Ribeiro AS, et al. (2024). Accuracy of 1RM prediction equations before and after resistance training in three different lifts. *Int J Strength Cond.* DOI not found — locate manually. https://doaj.org/article/248a0c4089a641d5b87f1ca3f9770895
- **R75.** Richens B, Cleather DJ (2014). The relationship between the number of repetitions performed at given intensities is different in endurance and strength trained athletes. *Biol Sport* 31(2):157–161. https://doi.org/10.5604/20831862.1099047
- **R76.** Halperin I, et al. (2022). Accuracy in predicting repetitions to task failure in resistance exercise: a scoping review and exploratory meta-analysis. *Sports Med* 52(2):377–390. https://doi.org/10.1007/s40279-021-01559-x — preprint: https://sportrxiv.org/index.php/server/preprint/view/67
- **R77.** Zourdos MC, et al. (2016). Novel resistance training-specific rating of perceived exertion scale measuring repetitions in reserve. *J Strength Cond Res* 30(1):267–275. https://doi.org/10.1519/JSC.0000000000001049 (DOI recalled)
- **R78.** Epley B (1985). *Poundage Chart.* Boyd Epley Workout. Lincoln, NE: Body Enterprises. No DOI; Unreviewed (practitioner chart, cited via Reynolds 2006 [R73]).
- **R79.** Plotkin D, et al. (2022). Progressive overload without progressing load? The effects of load or repetition progression on muscular adaptations. *PeerJ* 10:e14142. https://doi.org/10.7717/peerj.14142
- **R80.** Helms ER, et al. (2018). RPE vs. percentage 1RM loading in periodized programs matched for sets and repetitions. *Front Physiol* 9:247. https://doi.org/10.3389/fphys.2018.00247
- **R81.** Robinson ZP, Pelland JC, Remmert JF, Refalo MC, Jukic I, Steele J, Zourdos MC (2024). Exploring the dose–response relationship between estimated resistance training proximity to failure, strength gain, and muscle hypertrophy: a series of meta-regressions. *Sports Med* 54(9):2209–2231. https://doi.org/10.1007/s40279-024-02069-2
- **R82.** Refalo MC, et al. (2023). Influence of resistance training proximity-to-failure on skeletal muscle hypertrophy: a systematic review with meta-analysis. *Sports Med* 53(3):649–665. https://doi.org/10.1007/s40279-022-01784-y
- **R83.** American College of Sports Medicine (2009). Progression models in resistance training for healthy adults (position stand). *Med Sci Sports Exerc* 41(3):687–708. https://doi.org/10.1249/MSS.0b013e3181915670 (DOI recalled)
- **R84.** Bell L, Strafford BW, Coleman M, Androulakis Korakakis P, Nolan D (2023). Integrating deloading into strength and physique sports training programmes: an international Delphi consensus approach. *Sports Med Open* 9:87. https://doi.org/10.1186/s40798-023-00633-0
- **R85.** Rogerson D, Nolan D, Androulakis Korakakis P, Immonen V, Wolf M, Bell L (2024). Deloading practices in strength and physique sports: a cross-sectional survey. *Sports Med Open* 10. https://doi.org/10.1186/s40798-024-00691-y
- **R86.** Bell L, Nolan D, Androulakis Korakakis P, et al. (2022). "You can't shoot another bullet until you've reloaded the gun": coaches' perceptions, practices and experiences of deloading in strength and physique sports. *Front Sports Act Living* 4:1073223. https://doi.org/10.3389/fspor.2022.1073223
- **R87.** Coleman M, et al. (2024). Gaining more from doing less? The effects of a one-week deload period during supervised resistance training on muscular adaptations. *PeerJ* 12:e16777. https://doi.org/10.7717/peerj.16777
- **R88.** Rippetoe M. *Starting Strength: Basic Barbell Training*, 3rd ed. Wichita Falls, TX: Aasgaard, 2011. No DOI; Unreviewed (practitioner book).
- **R89.** Wendler J. *5/3/1: The Simplest and Most Effective Training System for Raw Strength.* Jim Wendler LLC, 2009. No DOI; Unreviewed (practitioner book).
- **R90.** Ribeiro B, et al. (2020). [Specific warm-up load and squat/bench press velocity; title to confirm]. *Int J Environ Res Public Health* 17(18):6882. https://doi.org/10.3390/ijerph17186882 (DOI inferred from the publisher record; title not retrieved) — https://pmc.ncbi.nlm.nih.gov/articles/PMC7558980
- **R91.** Ribeiro B, et al. (2021). [Specific warm-up and first-set velocity; title to confirm]. *J Mens Health* 17(4):226–233. https://doi.org/10.31083/jomh.2021.069 (DOI taken from the publisher URL)
- **R92.** Singer A, et al. (2024). Give it a rest: a systematic review with Bayesian meta-analysis on the effect of inter-set rest interval duration on muscle hypertrophy. *Front Sports Act Living* 6:1429789. https://doi.org/10.3389/fspor.2024.1429789
- **R93.** Ebben WP, Wurm B, et al. (2011). Kinetic analysis of several variations of push-ups. ISBS Conference Proceedings Archive, https://ojs.ub.uni-konstanz.de/cpa/article/view/4457 ; journal version *J Strength Cond Res* 25(10):2891–2894, https://doi.org/10.1519/JSC.0b013e31820c8587 (journal DOI recalled)
- **R94.** Suprak DN, Dawes J, Stephenson MD (2011). The effect of position on the percentage of body mass supported during traditional and modified push-up variants. *J Strength Cond Res* 25(2):497–503. https://doi.org/10.1519/JSC.0b013e3181bde2cf

**Volume**

- **R95.** Pelland JC, Remmert JF, Robinson ZP, Hinson SR, Zourdos MC (2026; online Dec 2025). The resistance training dose response: meta-regressions exploring the effects of weekly volume and frequency on muscle hypertrophy and strength gains. *Sports Med* 56(2):481–505. https://doi.org/10.1007/s40279-025-02344-w
- **R96.** Pelland JC, et al. SportRxiv preprints 460 (v2, the above meta-regression) and 537 (follow-up). Unreviewed preprints. https://sportrxiv.org/index.php/server/preprint/view/460 ; https://sportrxiv.org/index.php/server/preprint/view/537
- **R97.** Schoenfeld BJ, Ogborn D, Krieger JW (2017; online 2016). Dose-response relationship between weekly resistance training volume and increases in muscle mass: a systematic review and meta-analysis. *J Sports Sci* 35(11):1073–1082. https://doi.org/10.1080/02640414.2016.1210197
- **R98.** Baz-Valle E, Balsalobre-Fernández C, Alix-Fages C, Santos-Concejero J (2022). A systematic review of the effects of different resistance training volumes on muscle hypertrophy. *J Hum Kinet* 81:199–210. https://doi.org/10.2478/hukin-2022-0017
- **R99.** Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW (2017). Strength and hypertrophy adaptations between low- vs. high-load resistance training: a systematic review and meta-analysis. *J Strength Cond Res* 31(12):3508–3523. https://doi.org/10.1519/JSC.0000000000002200 (probably the BISp record linked in the text)
- **R100.** Schoenfeld BJ, Grgic J, Van Every DW, Plotkin DL (2021). Loading recommendations for muscle strength, hypertrophy, and local endurance: a re-examination of the repetition continuum. *Sports* 9(2):32. https://doi.org/10.3390/sports9020032 (DOI recalled)
- **R101.** Schoenfeld BJ, Grgic J, Krieger J (2019). How many times per week should a muscle be trained to maximize muscle hypertrophy? A systematic review and meta-analysis of studies examining the effects of resistance training frequency. *J Sports Sci* 37(11):1286–1295. https://doi.org/10.1080/02640414.2018.1555906
- **R102.** Currier BS, et al. (2026). American College of Sports Medicine position stand. Resistance training prescription for muscle function, hypertrophy, and physical performance in healthy adults: an overview of reviews. *Med Sci Sports Exerc* 58(4):851–872. https://doi.org/10.1249/MSS.0000000000003897
- **R103.** Scarpelli MC, Nóbrega SR, Santanielo N, Alvarez IF, Otoboni GB, Ugrinowitsch C, Libardi CA (2022; online 2020). Muscle hypertrophy response is affected by previous resistance training volume in trained individuals. *J Strength Cond Res* 36(4):1153–1157. https://doi.org/10.1519/JSC.0000000000003558
- **R104.** Camargo JBB, et al. (2026). Large increases in resistance training volume do not impair muscle hypertrophy or anabolic–catabolic molecular signaling in trained individuals. *J Appl Physiol* (online 16 July 2026). https://doi.org/10.1152/japplphysiol.00284.2026 (DOI from a secondary listing; unconfirmed) — PDF: https://www.fisiologiadelejercicio.com/wp-content/uploads/2026/07/Large-increases-in-resistance-training-volume-do-not-impair-muscle-hypertrophy.pdf
- **R105.** Spiering BA, Mujika I, Sharp MA, Foulis SA (2021). Maintaining physical performance: the minimal dose of exercise needed to preserve endurance and strength over time. *J Strength Cond Res* 35(5):1449–1458. https://doi.org/10.1519/JSC.0000000000003964
- **R106.** Israetel M, Hoffmann J, Smith CW. *Scientific Principles of Strength Training.* Renaissance Periodization, 2015 (source of the MEV/MAV/MRV volume landmarks). No DOI; Unreviewed.

**Habits, steps and body ratios**

- **R107.** Bull FC, et al. (2020). World Health Organization 2020 guidelines on physical activity and sedentary behaviour. *Br J Sports Med* 54(24):1451–1462. https://doi.org/10.1136/bjsports-2020-102955
- **R108.** Lally P, van Jaarsveld CHM, Potts HWW, Wardle J (2010). How are habits formed: modelling habit formation in the real world. *Eur J Soc Psychol* 40(6):998–1009. https://doi.org/10.1002/ejsp.674
- **R109.** Milkman KL, et al. (2021). Megastudies improve the impact of applied behavioural science. *Nature* 600:478–483. https://doi.org/10.1038/s41586-021-04128-4
- **R110.** Kaushal N, Rhodes RE (2015). Exercise habit formation in new gym members: a longitudinal study. *J Behav Med* 38(4):652–663. https://doi.org/10.1007/s10865-015-9640-7
- **R111.** Paluch AE, et al. (2022). Daily steps and all-cause mortality: a meta-analysis of 15 international cohorts. *Lancet Public Health* 7(3):e219–e228. https://doi.org/10.1016/S2468-2667(21)00302-9
- **R112.** Ding D, et al. (2025). Daily steps and health outcomes in adults: a systematic review and dose-response meta-analysis. *Lancet Public Health* 10(8):e668–e681. https://doi.org/10.1016/S2468-2667(25)00164-1
- **R113.** World Health Organization (2011). *Waist circumference and waist–hip ratio: report of a WHO expert consultation, Geneva, 8–11 December 2008.* ISBN 9789241501491. https://iris.who.int/handle/10665/44583
