//
//  Citations.swift
//  Compound
//
//  Every published source the app's calculations rest on. Generated from the reference list of
//  docs/research/algorithms-evidence.md (R1–R113); `reportNumber` is the R-number there, and
//  docs/research/citation-verification-checklist.md records how each DOI was checked. References are not
//  localized: a paper keeps its own title. R56 onwards are in `Citations+R56.swift`.
//

import Foundation

// swiftlint:disable line_length
extension Citation {

    /// R1
    static let mifflin1990 = Citation(
        reportNumber: 1,
        reference: "Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO (1990). A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr 51(2):241–247.",
        doi: "10.1093/ajcn/51.2.241"
    )

    /// R2
    static let roza1984 = Citation(
        reportNumber: 2,
        reference: "Roza AM, Shizgal HM (1984). The Harris Benedict equation reevaluated: resting energy requirements and the body cell mass. Am J Clin Nutr 40(1):168–182.",
        doi: "10.1093/ajcn/40.1.168"
    )

    /// R3
    static let mcardle = Citation(
        reportNumber: 3,
        reference: "McArdle WD, Katch FI, Katch VL. Exercise Physiology: Nutrition, Energy, and Human Performance. Wolters Kluwer (textbook, several editions; source of the Katch-McArdle 370 + 21.6·LBM form). No DOI; check the edition."
    )

    /// R4
    static let frankenfield2005 = Citation(
        reportNumber: 4,
        reference: "Frankenfield D, Roth-Yousey L, Compher C (2005). Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review. J Am Diet Assoc 105(5):775–789.",
        doi: "10.1016/j.jada.2005.02.005"
    )

    /// R5
    static let madden2016 = Citation(
        reportNumber: 5,
        reference: "Madden AM, Mulrooney HM, Shah S (2016). Estimation of energy expenditure using prediction equations in overweight and obese adults: a systematic review. J Hum Nutr Diet 29(4):458–476.",
        doi: "10.1111/jhn.12355"
    )

    /// R6
    static let oneill2023 = Citation(
        reportNumber: 6,
        reference: "O'Neill JER, Corish CA, Horner K (2023). Accuracy of resting metabolic rate prediction equations in athletes: a systematic review with meta-analysis. Sports Med 53(12):2373–2398.",
        doi: "10.1007/s40279-023-01896-z"
    )

    /// R7
    static let tinsley2019 = Citation(
        reportNumber: 7,
        reference: "Tinsley GM, Graybeal AJ, Moore ML (2019). Resting metabolic rate in muscular physique athletes: validity of existing methods and development of new prediction equations. Appl Physiol Nutr Metab 44(4):397–406.",
        doi: "10.1139/apnm-2018-0412"
    )

    /// R8
    static let cunningham1980 = Citation(
        reportNumber: 8,
        reference: "Cunningham JJ (1980). A reanalysis of the factors influencing basal metabolic rate in normal adults. Am J Clin Nutr 33(11):2372–2374.",
        doi: "10.1093/ajcn/33.11.2372"
    )

    /// R9
    static let tenHaaf2014 = Citation(
        reportNumber: 9,
        reference: "ten Haaf T, Weijs PJM (2014). Resting energy expenditure prediction in recreational athletes of 18–35 years: confirmation of Cunningham equation and an improved weight-based alternative. PLoS One 9(10):e108460.",
        doi: "10.1371/journal.pone.0108460"
    )

    /// R10
    static let fao2004 = Citation(
        reportNumber: 10,
        reference: "FAO/WHO/UNU (2004). Human energy requirements: report of a joint FAO/WHO/UNU expert consultation, Rome, 17–24 October 2001. FAO Food and Nutrition Technical Report Series 1. Rome: FAO.",
        url: "https://www.fao.org/4/y5686e/y5686e00.htm"
    )

    /// R11
    static let pontzer2016 = Citation(
        reportNumber: 11,
        reference: "Pontzer H, et al. (2016). Constrained total energy expenditure and metabolic adaptation to physical activity in adult humans. Curr Biol 26(3):410–417.",
        doi: "10.1016/j.cub.2015.12.046"
    )

    /// R12
    static let pontzer2012 = Citation(
        reportNumber: 12,
        reference: "Pontzer H, Raichlen DA, Wood BM, Mabulla AZP, Racette SB, Marlowe FW (2012). Hunter-gatherer energetics and human obesity. PLoS One 7(7):e40503.",
        doi: "10.1371/journal.pone.0040503"
    )

    /// R13
    static let boning2018 = Citation(
        reportNumber: 13,
        reference: "Böning D (2018). Fat in spite of exercise? An alleged paradigm change results from calculation mistakes (editorial). Dtsch Z Sportmed 69(1):3–4.",
        doi: "10.5960/dzsm.2017.311"
    )

    /// R14
    static let nasem2023 = Citation(
        reportNumber: 14,
        reference: "National Academies of Sciences, Engineering, and Medicine (2023). Dietary Reference Intakes for Energy. Washington, DC: National Academies Press.",
        doi: "10.17226/26818"
    )

    /// R15
    static let healthCanada = Citation(
        reportNumber: 15,
        reference: "Health Canada. Dietary reference intakes tables: equations to estimate energy requirement (secondary republication).",
        url: "https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/dietary-reference-intakes/tables/equations-estimate-energy-requirement.html"
    )

    /// R16
    static let usp2023 = Citation(
        reportNumber: 16,
        reference: "Universidade de São Paulo teaching material, \"Necessidades de energia – DRIs 2023\" (secondary copy of Table S-1; Unreviewed).",
        url: "https://edisciplinas.usp.br/mod/resource/view.php?id=4749455",
        isPeerReviewed: false
    )

    /// R17
    static let iom2005 = Citation(
        reportNumber: 17,
        reference: "Institute of Medicine (2005). Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids. Washington, DC: National Academies Press.",
        doi: "10.17226/10490"
    )

    /// R18
    static let bajunaid2025 = Citation(
        reportNumber: 18,
        reference: "Bajunaid R, et al. (2025). Predictive equation derived from 6,497 doubly labelled water measurements enables the detection of erroneous self-reported energy intake. Nat Food 6(1):58–71.",
        doi: "10.1038/s43016-024-01089-5"
    )

    /// R19
    static let pontzer2021 = Citation(
        reportNumber: 19,
        reference: "Pontzer H, et al. (2021). Daily energy expenditure through the human life course. Science 373(6556):808–812.",
        doi: "10.1126/science.abe5017"
    )

    /// R20
    static let westerterp2004 = Citation(
        reportNumber: 20,
        reference: "Westerterp KR (2004). Diet induced thermogenesis. Nutr Metab (Lond) 1:5.",
        doi: "10.1186/1743-7075-1-5"
    )

    /// R21
    static let acsm2021 = Citation(
        reportNumber: 21,
        reference: "American College of Sports Medicine. ACSM's Guidelines for Exercise Testing and Prescription, 11th ed. Philadelphia: Wolters Kluwer, 2021 (metabolic equations for walking). No DOI."
    )

    /// R22
    static let minetti2002 = Citation(
        reportNumber: 22,
        reference: "Minetti AE, Moia C, Roi GS, Susta D, Ferretti G (2002). Energy cost of walking and running at extreme uphill and downhill slopes. J Appl Physiol 93(3):1039–1046.",
        doi: "10.1152/japplphysiol.01177.2001"
    )

    /// R23
    static let wishnofsky1958 = Citation(
        reportNumber: 23,
        reference: "Wishnofsky M (1958). Caloric equivalents of gained or lost weight. Am J Clin Nutr 6(5):542–546.",
        doi: "10.1093/ajcn/6.5.542"
    )

    /// R24
    static let hall2008 = Citation(
        reportNumber: 24,
        reference: "Hall KD (2008). What is the required energy deficit per unit weight loss? Int J Obes 32(3):573–576.",
        doi: "10.1038/sj.ijo.0803720"
    )

    /// R25
    static let hall2011 = Citation(
        reportNumber: 25,
        reference: "Hall KD, Sacks G, Chandramohan D, Chow CC, Wang YC, Gortmaker SL, Swinburn BA (2011). Quantification of the effect of energy imbalance on bodyweight. Lancet 378(9793):826–837.",
        doi: "10.1016/S0140-6736(11)60812-X"
    )

    /// R26
    static let hall2007 = Citation(
        reportNumber: 26,
        reference: "Hall KD (2007). Body fat and fat-free mass inter-relationships: Forbes's theory revisited. Br J Nutr 97(6):1059–1063.",
        doi: "10.1017/S0007114507691946"
    )

    /// R27
    static let forbes1987 = Citation(
        reportNumber: 27,
        reference: "Forbes GB (1987). Lean body mass–body fat interrelationships in humans. Nutr Rev 45(8):225–231.",
        doi: "10.1111/j.1753-4887.1987.tb02684.x"
    )

    /// R28
    static let heymsfield2012 = Citation(
        reportNumber: 28,
        reference: "Heymsfield SB, et al. (2012). Energy content of weight loss: kinetic features during voluntary caloric restriction. Metabolism 61(7):937–943.",
        doi: "10.1016/j.metabol.2011.11.012"
    )

    /// R29
    static let kreitzman1992 = Citation(
        reportNumber: 29,
        reference: "Kreitzman SN, Coxon AY, Szaz KF (1992). Glycogen storage: illusions of easy weight loss, excessive weight regain, and distortions in estimates of body composition. Am J Clin Nutr 56(1 Suppl):292S–293S.",
        doi: "10.1093/ajcn/56.1.292S"
    )

    /// R30
    static let schneditz2023 = Citation(
        reportNumber: 30,
        reference: "Schneditz D, et al. (2023). Day-to-day variability in euvolemic body mass. Ren Fail 45(2):2273421.",
        doi: "10.1080/0886022X.2023.2273421"
    )

    /// R31
    static let orsama2014 = Citation(
        reportNumber: 31,
        reference: "Orsama AL, Mattila E, Ermes M, van Gils M, Wansink B, Korhonen I (2014). Weight rhythms: weight increases during weekends and decreases during weekdays. Obes Facts 7(1):36–47.",
        doi: "10.1159/000356147"
    )

    /// R32
    static let turicchi2020 = Citation(
        reportNumber: 32,
        reference: "Turicchi J, O'Driscoll R, Horgan G, Duarte C, Palmeira AL, Larsen SC, Heitmann BL, Stubbs J (2020). Weekly, seasonal and holiday body weight fluctuation patterns among individuals engaged in a European multi-centre behavioural weight loss maintenance intervention. PLoS One 15(4):e0232152.",
        doi: "10.1371/journal.pone.0232152"
    )

    /// R33
    static let kanellakis2023 = Citation(
        reportNumber: 33,
        reference: "Kanellakis S, et al. (2023). Changes in body weight and body composition during the menstrual cycle. Am J Hum Biol 35(11):e23951.",
        doi: "10.1002/ajhb.23951"
    )

    /// R34
    static let hall2011b = Citation(
        reportNumber: 34,
        reference: "Hall KD, Chow CC (2011). Estimating changes in free-living energy intake and its confidence interval. Am J Clin Nutr 94(1):66–74.",
        doi: "10.3945/ajcn.111.014399"
    )

    /// R35
    static let sanghvi2015 = Citation(
        reportNumber: 35,
        reference: "Sanghvi A, Redman LM, Martin CK, Ravussin E, Hall KD (2015). Validation of an inexpensive and accurate mathematical method to measure long-term changes in free-living energy intake. Am J Clin Nutr 102(2):353–358.",
        doi: "10.3945/ajcn.115.111070"
    )

    /// R36
    static let lichtman1992 = Citation(
        reportNumber: 36,
        reference: "Lichtman SW, et al. (1992). Discrepancy between self-reported and actual caloric intake and exercise in obese subjects. N Engl J Med 327(27):1893–1898.",
        doi: "10.1056/NEJM199212313272701"
    )

    /// R37
    static let guo2020 = Citation(
        reportNumber: 37,
        reference: "Guo P, Rivera DE, Savage JS, Hohman EE, Pauley AM, Leonard KS, Downs DS (2020; online 2018). System identification approaches for energy intake estimation: enhancing interventions for managing gestational weight gain. IEEE Trans Control Syst Technol 28(1):63–78.",
        doi: "10.1109/TCST.2018.2871871"
    )

    /// R38
    static let guo2017 = Citation(
        reportNumber: 38,
        reference: "Guo P, Rivera DE, Savage JS, Downs DS (2017). State estimation under correlated partial measurement losses: implications for weight control interventions. IFAC-PapersOnLine 50(1):13532–13537 (20th IFAC World Congress). DOI not found — locate manually. Record:.",
        url: "https://asu.elsevierpure.com/en/publications/state-estimation-under-correlated-partial-measurement-losses-impl/"
    )

    /// R39
    static let walker = Citation(
        reportNumber: 39,
        reference: "Walker J. The Hacker's Diet (online edition, Fourmilab). Unreviewed.",
        url: "https://fourmilab.ch/hackdiet/www/subsubsection1_4_1_0_8_3.html",
        isPeerReviewed: false
    )

    /// R40
    static let martins2020 = Citation(
        reportNumber: 40,
        reference: "Martins C, et al. (2020). Metabolic adaptation is an illusion, only present when participants are in negative energy balance. Am J Clin Nutr 112(5):1212–1218.",
        doi: "10.1093/ajcn/nqaa220"
    )

    /// R41
    static let rauch1965 = Citation(
        reportNumber: 41,
        reference: "Rauch HE, Tung F, Striebel CT (1965). Maximum likelihood estimates of linear dynamic systems. AIAA J 3(8):1445–1450.",
        doi: "10.2514/3.3166"
    )

    /// R42
    static let macrofactor = Citation(
        reportNumber: 42,
        reference: "MacroFactor help centre, \"How should I interpret changes to my energy expenditure?\" (Unreviewed).",
        url: "https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure",
        isPeerReviewed: false
    )

    /// R43
    static let martin2015 = Citation(
        reportNumber: 43,
        reference: "Martin CK, et al. (2015). Efficacy of SmartLoss, a smartphone-based weight loss intervention: results from a randomized controlled trial. Obesity 23(5):935–942.",
        doi: "10.1002/oby.21063"
    )

    /// R44
    static let riveraMPC = Citation(
        reportNumber: 44,
        reference: "Rivera DE and colleagues, control-systems formulation of adaptive behavioural interventions (gestational weight gain, model-predictive control). The article at PMC3856197 was not identified by search; it is probably one of the Dong/Rivera hybrid-MPC papers. DOI not found — locate manually.",
        url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC3856197/"
    )

    /// R45
    static let guo2018 = Citation(
        reportNumber: 45,
        reference: "Guo J, Brager DC, Hall KD (2018). Simulating long-term human weight-loss dynamics in response to calorie restriction. Am J Clin Nutr 107(4):558–565.",
        doi: "10.1093/ajcn/nqx080"
    )

    /// R46
    static let thomas2014 = Citation(
        reportNumber: 46,
        reference: "Thomas DM, Martin CK, Redman LM, Heymsfield SB, Lettieri S, Levine JA, Bouchard C, Schoeller DA (2014). Effect of dietary adherence on the body weight plateau: a mathematical model incorporating intermittent compliance with energy intake prescription. Am J Clin Nutr 100(3):787–795.",
        doi: "10.3945/ajcn.113.079822"
    )

    /// R47
    static let morton2018 = Citation(
        reportNumber: 47,
        reference: "Morton RW, et al. (2018). A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength in healthy adults. Br J Sports Med 52(6):376–384.",
        doi: "10.1136/bjsports-2017-097608"
    )

    /// R48
    static let nunes2022 = Citation(
        reportNumber: 48,
        reference: "Nunes EA, et al. (2022). Systematic review and meta-analysis of protein intake to support muscle mass and function in healthy adults. J Cachexia Sarcopenia Muscle 13(2):795–810.",
        doi: "10.1002/jcsm.12922"
    )

    /// R49
    static let helms2014 = Citation(
        reportNumber: 49,
        reference: "Helms ER, Zinn C, Rowlands DS, Brown SR (2014). A systematic review of dietary protein during caloric restriction in resistance trained lean athletes: a case for higher intakes. Int J Sport Nutr Exerc Metab 24(2):127–138.",
        doi: "10.1123/ijsnem.2013-0054"
    )

    /// R50
    static let devries2018 = Citation(
        reportNumber: 50,
        reference: "Devries MC, Sithamparapillai A, Brimble KS, Banfield L, Morton RW, Phillips SM (2018). Changes in kidney function do not differ between healthy adults consuming higher- compared with lower- or normal-protein diets: a systematic review and meta-analysis. J Nutr 148(11):1760–1775.",
        doi: "10.1093/jn/nxy197"
    )

    /// R51
    static let weijs2025 = Citation(
        reportNumber: 51,
        reference: "Weijs PJM (2025). Protein requirement in obesity. Curr Opin Clin Nutr Metab Care 28(1).",
        doi: "10.1097/MCO.0000000000001087"
    )

    /// R52
    static let dekker2022 = Citation(
        reportNumber: 52,
        reference: "Dekker IM, van Rijssen NM, Verreijen A, Weijs PJM, de Boer WB, Terpstra D, Kruizenga HM (2022). Calculation of protein requirements: a comparison of calculations based on bodyweight and fat free mass. Clin Nutr ESPEN 48:378–385.",
        doi: "10.1016/j.clnesp.2022.01.014"
    )

    /// R53
    static let bauer2013 = Citation(
        reportNumber: 53,
        reference: "Bauer J, et al. (2013). Evidence-based recommendations for optimal dietary protein intake in older people: a position paper from the PROT-AGE Study Group. J Am Med Dir Assoc 14(8):542–559.",
        doi: "10.1016/j.jamda.2013.05.021"
    )

    /// R54
    static let nunes2022b = Citation(
        reportNumber: 54,
        reference: "Nunes CL, et al. (2022). Adaptive thermogenesis after moderate weight loss: magnitude and methodological issues. Eur J Nutr 61(3):1405–1416.",
        doi: "10.1007/s00394-021-02742-6"
    )

    /// R55
    static let thomas2016 = Citation(
        reportNumber: 55,
        reference: "Thomas DT, Erdman KA, Burke LM (2016). Position of the Academy of Nutrition and Dietetics, Dietitians of Canada, and the American College of Sports Medicine: nutrition and athletic performance. J Acad Nutr Diet 116(3):501–528.",
        doi: "10.1016/j.jand.2015.12.006"
    )
}
// swiftlint:enable line_length
