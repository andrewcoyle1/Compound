//
//  Citations.swift
//  Compound
//
//  Every published source the app's calculations rest on. Generated from the reference list of
//  reports/Defensible fitness app algorithms.md (R1–R113); `reportNumber` is the R-number there, and
//  reports/Citation verification checklist.md records how each DOI was checked. References are not
//  localized: a paper keeps its own title.
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

    /// R56
    static let whittaker2021 = Citation(
        reportNumber: 56,
        reference: "Whittaker J, Wu K (2021). Low-fat diets and testosterone in men: systematic review and meta-analysis of intervention studies. J Steroid Biochem Mol Biol 210:105878.",
        doi: "10.1016/j.jsbmb.2021.105878"
    )

    /// R57
    static let iraki2019 = Citation(
        reportNumber: 57,
        reference: "Iraki J, Fitschen P, Espinar S, Helms E (2019). Nutrition recommendations for bodybuilders in the off-season: a narrative review. Sports 7(7):154.",
        doi: "10.3390/sports7070154"
    )

    /// R58
    static let feinman2015 = Citation(
        reportNumber: 58,
        reference: "Feinman RD, et al. (2015). Dietary carbohydrate restriction as the first approach in diabetes management: critical review and evidence base. Nutrition 31(1):1–13.",
        doi: "10.1016/j.nut.2014.06.011"
    )

    /// R59
    static let henselmans2022 = Citation(
        reportNumber: 59,
        reference: "Henselmans M, Bjørnsen T, Hedderman R, Vårvik FT (2022). The effect of carbohydrate intake on strength and resistance training performance: a systematic review. Nutrients 14(4):856.",
        doi: "10.3390/nu14040856"
    )

    /// R60
    static let fao2003 = Citation(
        reportNumber: 60,
        reference: "FAO (2003). Food energy – methods of analysis and conversion factors. FAO Food and Nutrition Paper 77. Rome: FAO.",
        url: "https://www.fao.org/4/y5022e/y5022e00.htm"
    )

    /// R61
    static let campbell2020 = Citation(
        reportNumber: 61,
        reference: "Campbell BI, et al. (2020). Intermittent energy restriction attenuates the loss of fat free mass in resistance trained individuals: a randomized controlled trial. J Funct Morphol Kinesiol 5(1):19.",
        doi: "10.3390/jfmk5010019"
    )

    /// R62
    static let peos2021 = Citation(
        reportNumber: 62,
        reference: "Peos JJ, Helms ER, Fournier PA, Krieger J, Sainsbury A (2021). A 1-week diet break improves muscle endurance during an intermittent dieting regime in adult athletes: a pre-specified secondary analysis of the ICECAP trial. PLoS One 16(2):e0247292.",
        doi: "10.1371/journal.pone.0247292"
    )

    /// R63
    static let helms2014b = Citation(
        reportNumber: 63,
        reference: "Helms ER, Aragon AA, Fitschen PJ (2014). Evidence-based recommendations for natural bodybuilding contest preparation: nutrition and supplementation. J Int Soc Sports Nutr 11:20.",
        doi: "10.1186/1550-2783-11-20"
    )

    /// R64
    static let garthe2011 = Citation(
        reportNumber: 64,
        reference: "Garthe I, Raastad T, Refsnes PE, Koivisto A, Sundgot-Borgen J (2011). Effect of two different weight-loss rates on body composition and strength and power-related performance in elite athletes. Int J Sport Nutr Exerc Metab 21(2):97–104.",
        doi: "10.1123/ijsnem.21.2.97"
    )

    /// R65
    static let purcell2014 = Citation(
        reportNumber: 65,
        reference: "Purcell K, Sumithran P, Prendergast LA, Bouniu CJ, Delbridge E, Proietto J (2014). The effect of rate of weight loss on long-term weight management: a randomised controlled trial. Lancet Diabetes Endocrinol 2(12):954–962.",
        doi: "10.1016/S2213-8587(14)70200-1"
    )

    /// R66
    static let helms2023 = Citation(
        reportNumber: 66,
        reference: "Helms ER, et al. (2023). Effect of small and large energy surpluses on strength, muscle, and skinfold thickness in resistance-trained individuals: a parallel groups design. Sports Med Open 9:102.",
        doi: "10.1186/s40798-023-00651-y"
    )

    /// R67
    static let niddk = Citation(
        reportNumber: 67,
        reference: "National Institute of Diabetes and Digestive and Kidney Diseases. \"Very-low-calorie diet\" (health dictionary).",
        url: "https://www.niddk.nih.gov/Dictionary/V/very-low-calorie-diet"
    )

    /// R68
    static let niddk2025 = Citation(
        reportNumber: 68,
        reference: "National Institute for Health and Care Excellence (2025). Overweight and obesity management (NICE guideline NG246).",
        url: "https://www.nice.org.uk/guidance/NG246"
    )

    /// R69
    static let jensen2014 = Citation(
        reportNumber: 69,
        reference: "Jensen MD, et al. (2014; online 2013). 2013 AHA/ACC/TOS guideline for the management of overweight and obesity in adults. Circulation 129(25 Suppl 2):S102–S138.",
        doi: "10.1161/01.cir.0000437739.71477.ee"
    )

    /// R70
    static let loucks2003 = Citation(
        reportNumber: 70,
        reference: "Loucks AB, Thuma JR (2003). Luteinizing hormone pulsatility is disrupted at a threshold of energy availability in regularly menstruating women. J Clin Endocrinol Metab 88(1):297–311.",
        doi: "10.1210/jc.2002-020369"
    )

    /// R71
    static let mountjoy2023 = Citation(
        reportNumber: 71,
        reference: "Mountjoy M, et al. (2023). 2023 International Olympic Committee's (IOC) consensus statement on Relative Energy Deficiency in Sport (REDs). Br J Sports Med 57(17):1073–1097.",
        doi: "10.1136/bjsports-2023-106994"
    )

    /// R72
    static let cfr21 = Citation(
        reportNumber: 72,
        reference: "US Code of Federal Regulations, Title 21, §101.9(g)(4)–(5) (nutrition labelling compliance).",
        url: "https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9"
    )

    /// R73
    static let reynolds2006 = Citation(
        reportNumber: 73,
        reference: "Reynolds JM, Gordon TJ, Robergs RA (2006). Prediction of one repetition maximum strength from multiple repetition maximum testing and anthropometry. J Strength Cond Res 20(3):584–592.",
        doi: "10.1519/00124278-200608000-00020"
    )

    /// R74
    static let ribeiro2024 = Citation(
        reportNumber: 74,
        reference: "Ribeiro AS, et al. (2024). Accuracy of 1RM prediction equations before and after resistance training in three different lifts. Int J Strength Cond. DOI not found — locate manually.",
        url: "https://doaj.org/article/248a0c4089a641d5b87f1ca3f9770895"
    )

    /// R75
    static let richens2014 = Citation(
        reportNumber: 75,
        reference: "Richens B, Cleather DJ (2014). The relationship between the number of repetitions performed at given intensities is different in endurance and strength trained athletes. Biol Sport 31(2):157–161.",
        doi: "10.5604/20831862.1099047"
    )

    /// R76
    static let halperin2022 = Citation(
        reportNumber: 76,
        reference: "Halperin I, et al. (2022). Accuracy in predicting repetitions to task failure in resistance exercise: a scoping review and exploratory meta-analysis. Sports Med 52(2):377–390.",
        doi: "10.1007/s40279-021-01559-x"
    )

    /// R77
    static let zourdos2016 = Citation(
        reportNumber: 77,
        reference: "Zourdos MC, et al. (2016). Novel resistance training-specific rating of perceived exertion scale measuring repetitions in reserve. J Strength Cond Res 30(1):267–275.",
        doi: "10.1519/JSC.0000000000001049"
    )

    /// R78
    static let epley1985 = Citation(
        reportNumber: 78,
        reference: "Epley B (1985). Poundage Chart. Boyd Epley Workout. Lincoln, NE: Body Enterprises. No DOI; Unreviewed (practitioner chart, cited via Reynolds 2006 [R73]).",
        isPeerReviewed: false
    )

    /// R79
    static let plotkin2022 = Citation(
        reportNumber: 79,
        reference: "Plotkin D, et al. (2022). Progressive overload without progressing load? The effects of load or repetition progression on muscular adaptations. PeerJ 10:e14142.",
        doi: "10.7717/peerj.14142"
    )

    /// R80
    static let helms2018 = Citation(
        reportNumber: 80,
        reference: "Helms ER, et al. (2018). RPE vs. percentage 1RM loading in periodized programs matched for sets and repetitions. Front Physiol 9:247.",
        doi: "10.3389/fphys.2018.00247"
    )

    /// R81
    static let robinson2024 = Citation(
        reportNumber: 81,
        reference: "Robinson ZP, Pelland JC, Remmert JF, Refalo MC, Jukic I, Steele J, Zourdos MC (2024). Exploring the dose–response relationship between estimated resistance training proximity to failure, strength gain, and muscle hypertrophy: a series of meta-regressions. Sports Med 54(9):2209–2231.",
        doi: "10.1007/s40279-024-02069-2"
    )

    /// R82
    static let refalo2023 = Citation(
        reportNumber: 82,
        reference: "Refalo MC, et al. (2023). Influence of resistance training proximity-to-failure on skeletal muscle hypertrophy: a systematic review with meta-analysis. Sports Med 53(3):649–665.",
        doi: "10.1007/s40279-022-01784-y"
    )

    /// R83
    static let acsm2009 = Citation(
        reportNumber: 83,
        reference: "American College of Sports Medicine (2009). Progression models in resistance training for healthy adults (position stand). Med Sci Sports Exerc 41(3):687–708.",
        doi: "10.1249/MSS.0b013e3181915670"
    )

    /// R84
    static let bell2023 = Citation(
        reportNumber: 84,
        reference: "Bell L, Strafford BW, Coleman M, Androulakis Korakakis P, Nolan D (2023). Integrating deloading into strength and physique sports training programmes: an international Delphi consensus approach. Sports Med Open 9:87.",
        doi: "10.1186/s40798-023-00633-0"
    )

    /// R85
    static let rogerson2024 = Citation(
        reportNumber: 85,
        reference: "Rogerson D, Nolan D, Androulakis Korakakis P, Immonen V, Wolf M, Bell L (2024). Deloading practices in strength and physique sports: a cross-sectional survey. Sports Med Open 10.",
        doi: "10.1186/s40798-024-00691-y"
    )

    /// R86
    static let bell2022 = Citation(
        reportNumber: 86,
        reference: "Bell L, Nolan D, Androulakis Korakakis P, et al. (2022). \"You can't shoot another bullet until you've reloaded the gun\": coaches' perceptions, practices and experiences of deloading in strength and physique sports. Front Sports Act Living 4:1073223.",
        doi: "10.3389/fspor.2022.1073223"
    )

    /// R87
    static let coleman2024 = Citation(
        reportNumber: 87,
        reference: "Coleman M, et al. (2024). Gaining more from doing less? The effects of a one-week deload period during supervised resistance training on muscular adaptations. PeerJ 12:e16777.",
        doi: "10.7717/peerj.16777"
    )

    /// R88
    static let rippetoe2011 = Citation(
        reportNumber: 88,
        reference: "Rippetoe M. Starting Strength: Basic Barbell Training, 3rd ed. Wichita Falls, TX: Aasgaard, 2011. No DOI; Unreviewed (practitioner book).",
        isPeerReviewed: false
    )

    /// R89
    static let wendler2009 = Citation(
        reportNumber: 89,
        reference: "Wendler J. 5/3/1: The Simplest and Most Effective Training System for Raw Strength. Jim Wendler LLC, 2009. No DOI; Unreviewed (practitioner book).",
        isPeerReviewed: false
    )

    /// R90
    static let ribeiro2020 = Citation(
        reportNumber: 90,
        reference: "Ribeiro B, et al. (2020). [Specific warm-up load and squat/bench press velocity; title to confirm]. Int J Environ Res Public Health 17(18):6882.",
        doi: "10.3390/ijerph17186882"
    )

    /// R91
    static let ribeiro2021 = Citation(
        reportNumber: 91,
        reference: "Ribeiro B, et al. (2021). [Specific warm-up and first-set velocity; title to confirm]. J Mens Health 17(4):226–233.",
        doi: "10.31083/jomh.2021.069"
    )

    /// R92
    static let singer2024 = Citation(
        reportNumber: 92,
        reference: "Singer A, et al. (2024). Give it a rest: a systematic review with Bayesian meta-analysis on the effect of inter-set rest interval duration on muscle hypertrophy. Front Sports Act Living 6:1429789.",
        doi: "10.3389/fspor.2024.1429789"
    )

    /// R93
    static let ebben2011 = Citation(
        reportNumber: 93,
        reference: "Ebben WP, Wurm B, et al. (2011). Kinetic analysis of several variations of push-ups. ISBS Conference Proceedings Archive,.",
        doi: "10.1519/JSC.0b013e31820c8587"
    )

    /// R94
    static let suprak2011 = Citation(
        reportNumber: 94,
        reference: "Suprak DN, Dawes J, Stephenson MD (2011). The effect of position on the percentage of body mass supported during traditional and modified push-up variants. J Strength Cond Res 25(2):497–503.",
        doi: "10.1519/JSC.0b013e3181bde2cf"
    )

    /// R95
    static let pelland2026 = Citation(
        reportNumber: 95,
        reference: "Pelland JC, Remmert JF, Robinson ZP, Hinson SR, Zourdos MC (2026; online Dec 2025). The resistance training dose response: meta-regressions exploring the effects of weekly volume and frequency on muscle hypertrophy and strength gains. Sports Med 56(2):481–505.",
        doi: "10.1007/s40279-025-02344-w"
    )

    /// R96
    static let pelland = Citation(
        reportNumber: 96,
        reference: "Pelland JC, et al. SportRxiv preprints 460 (v2, the above meta-regression) and 537 (follow-up). Unreviewed preprints.",
        url: "https://sportrxiv.org/index.php/server/preprint/view/460",
        isPeerReviewed: false
    )

    /// R97
    static let schoenfeld2017 = Citation(
        reportNumber: 97,
        reference: "Schoenfeld BJ, Ogborn D, Krieger JW (2017; online 2016). Dose-response relationship between weekly resistance training volume and increases in muscle mass: a systematic review and meta-analysis. J Sports Sci 35(11):1073–1082.",
        doi: "10.1080/02640414.2016.1210197"
    )

    /// R98
    static let bazvalle2022 = Citation(
        reportNumber: 98,
        reference: "Baz-Valle E, Balsalobre-Fernández C, Alix-Fages C, Santos-Concejero J (2022). A systematic review of the effects of different resistance training volumes on muscle hypertrophy. J Hum Kinet 81:199–210.",
        doi: "10.2478/hukin-2022-0017"
    )

    /// R99
    static let schoenfeld2017b = Citation(
        reportNumber: 99,
        reference: "Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW (2017). Strength and hypertrophy adaptations between low- vs. high-load resistance training: a systematic review and meta-analysis. J Strength Cond Res 31(12):3508–3523.",
        doi: "10.1519/JSC.0000000000002200"
    )

    /// R100
    static let schoenfeld2021 = Citation(
        reportNumber: 100,
        reference: "Schoenfeld BJ, Grgic J, Van Every DW, Plotkin DL (2021). Loading recommendations for muscle strength, hypertrophy, and local endurance: a re-examination of the repetition continuum. Sports 9(2):32.",
        doi: "10.3390/sports9020032"
    )

    /// R101
    static let schoenfeld2019 = Citation(
        reportNumber: 101,
        reference: "Schoenfeld BJ, Grgic J, Krieger J (2019). How many times per week should a muscle be trained to maximize muscle hypertrophy? A systematic review and meta-analysis of studies examining the effects of resistance training frequency. J Sports Sci 37(11):1286–1295.",
        doi: "10.1080/02640414.2018.1555906"
    )

    /// R102
    static let currier2026 = Citation(
        reportNumber: 102,
        reference: "Currier BS, et al. (2026). American College of Sports Medicine position stand. Resistance training prescription for muscle function, hypertrophy, and physical performance in healthy adults: an overview of reviews. Med Sci Sports Exerc 58(4):851–872.",
        doi: "10.1249/MSS.0000000000003897"
    )

    /// R103
    static let scarpelli2022 = Citation(
        reportNumber: 103,
        reference: "Scarpelli MC, Nóbrega SR, Santanielo N, Alvarez IF, Otoboni GB, Ugrinowitsch C, Libardi CA (2022; online 2020). Muscle hypertrophy response is affected by previous resistance training volume in trained individuals. J Strength Cond Res 36(4):1153–1157.",
        doi: "10.1519/JSC.0000000000003558"
    )

    /// R104
    static let camargo2026 = Citation(
        reportNumber: 104,
        reference: "Camargo JBB, et al. (2026). Large increases in resistance training volume do not impair muscle hypertrophy or anabolic–catabolic molecular signaling in trained individuals. J Appl Physiol (online 16 July 2026).",
        doi: "10.1152/japplphysiol.00284.2026"
    )

    /// R105
    static let spiering2021 = Citation(
        reportNumber: 105,
        reference: "Spiering BA, Mujika I, Sharp MA, Foulis SA (2021). Maintaining physical performance: the minimal dose of exercise needed to preserve endurance and strength over time. J Strength Cond Res 35(5):1449–1458.",
        doi: "10.1519/JSC.0000000000003964"
    )

    /// R106
    static let israetel2015 = Citation(
        reportNumber: 106,
        reference: "Israetel M, Hoffmann J, Smith CW. Scientific Principles of Strength Training. Renaissance Periodization, 2015 (source of the MEV/MAV/MRV volume landmarks). No DOI; Unreviewed.",
        isPeerReviewed: false
    )

    /// R107
    static let bull2020 = Citation(
        reportNumber: 107,
        reference: "Bull FC, et al. (2020). World Health Organization 2020 guidelines on physical activity and sedentary behaviour. Br J Sports Med 54(24):1451–1462.",
        doi: "10.1136/bjsports-2020-102955"
    )

    /// R108
    static let lally2010 = Citation(
        reportNumber: 108,
        reference: "Lally P, van Jaarsveld CHM, Potts HWW, Wardle J (2010). How are habits formed: modelling habit formation in the real world. Eur J Soc Psychol 40(6):998–1009.",
        doi: "10.1002/ejsp.674"
    )

    /// R109
    static let milkman2021 = Citation(
        reportNumber: 109,
        reference: "Milkman KL, et al. (2021). Megastudies improve the impact of applied behavioural science. Nature 600:478–483.",
        doi: "10.1038/s41586-021-04128-4"
    )

    /// R110
    static let kaushal2015 = Citation(
        reportNumber: 110,
        reference: "Kaushal N, Rhodes RE (2015). Exercise habit formation in new gym members: a longitudinal study. J Behav Med 38(4):652–663.",
        doi: "10.1007/s10865-015-9640-7"
    )

    /// R111
    static let paluch2022 = Citation(
        reportNumber: 111,
        reference: "Paluch AE, et al. (2022). Daily steps and all-cause mortality: a meta-analysis of 15 international cohorts. Lancet Public Health 7(3):e219–e228.",
        doi: "10.1016/S2468-2667(21)00302-9"
    )

    /// R112
    static let ding2025 = Citation(
        reportNumber: 112,
        reference: "Ding D, et al. (2025). Daily steps and health outcomes in adults: a systematic review and dose-response meta-analysis. Lancet Public Health 10(8):e668–e681.",
        doi: "10.1016/S2468-2667(25)00164-1"
    )

    /// R113
    static let who2011 = Citation(
        reportNumber: 113,
        reference: "World Health Organization (2011). Waist circumference and waist–hip ratio: report of a WHO expert consultation, Geneva, 8–11 December 2008. ISBN 9789241501491.",
        url: "https://iris.who.int/handle/10665/44583"
    )

}
// swiftlint:enable line_length
