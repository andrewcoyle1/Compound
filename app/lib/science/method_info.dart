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

  /// R68.
  static const niddk2025 = Citation(
    reference:
        'National Institute for Health and Care Excellence (2025). Overweight '
        'and obesity management (NICE guideline NG246).',
    url: 'https://www.nice.org.uk/guidance/NG246',
  );

  /// R113.
  static const who2011 = Citation(
    reference:
        'World Health Organization (2011). Waist circumference and waist–hip '
        'ratio: report of a WHO expert consultation, Geneva, 8–11 December '
        '2008. ISBN 9789241501491.',
    url: 'https://iris.who.int/handle/10665/44583',
  );

  /// R93.
  static const ebben2011 = Citation(
    reference:
        'Ebben WP, Wurm B, et al. (2011). Kinetic analysis of several '
        'variations of push-ups. ISBS Conference Proceedings Archive,.',
    doi: '10.1519/JSC.0b013e31820c8587',
  );

  /// R94.
  static const suprak2011 = Citation(
    reference:
        'Suprak DN, Dawes J, Stephenson MD (2011). The effect of position on '
        'the percentage of body mass supported during traditional and '
        'modified push-up variants. J Strength Cond Res 25(2):497–503.',
    doi: '10.1519/JSC.0b013e3181bde2cf',
  );

  /// R84.
  static const bell2023 = Citation(
    reference:
        'Bell L, Strafford BW, Coleman M, Androulakis Korakakis P, Nolan D '
        '(2023). Integrating deloading into strength and physique sports '
        'training programmes: an international Delphi consensus approach. '
        'Sports Med Open 9:87.',
    doi: '10.1186/s40798-023-00633-0',
  );

  /// R85.
  static const rogerson2024 = Citation(
    reference:
        'Rogerson D, Nolan D, Androulakis Korakakis P, Immonen V, Wolf M, '
        'Bell L (2024). Deloading practices in strength and physique sports: '
        'a cross-sectional survey. Sports Med Open 10.',
    doi: '10.1186/s40798-024-00691-y',
  );

  /// R86.
  static const bell2022 = Citation(
    reference:
        'Bell L, Nolan D, Androulakis Korakakis P, et al. (2022). "You can\'t '
        "shoot another bullet until you've reloaded the gun\": coaches' "
        'perceptions, practices and experiences of deloading in strength and '
        'physique sports. Front Sports Act Living 4:1073223.',
    doi: '10.3389/fspor.2022.1073223',
  );

  /// R87.
  static const coleman2024 = Citation(
    reference:
        'Coleman M, et al. (2024). Gaining more from doing less? The effects '
        'of a one-week deload period during supervised resistance training on '
        'muscular adaptations. PeerJ 12:e16777.',
    doi: '10.7717/peerj.16777',
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

  /// R73.
  static const reynolds2006 = Citation(
    reference:
        'Reynolds JM, Gordon TJ, Robergs RA (2006). Prediction of one '
        'repetition maximum strength from multiple repetition maximum testing '
        'and anthropometry. J Strength Cond Res 20(3):584–592.',
    doi: '10.1519/00124278-200608000-00020',
  );

  /// R74.
  static const ribeiro2024 = Citation(
    reference:
        'Ribeiro AS, et al. (2024). Accuracy of 1RM prediction equations '
        'before and after resistance training in three different lifts. Int J '
        'Strength Cond. DOI not found — locate manually.',
    url: 'https://doaj.org/article/248a0c4089a641d5b87f1ca3f9770895',
  );

  /// R75.
  static const richens2014 = Citation(
    reference:
        'Richens B, Cleather DJ (2014). The relationship between the number '
        'of repetitions performed at given intensities is different in '
        'endurance and strength trained athletes. Biol Sport 31(2):157–161.',
    doi: '10.5604/20831862.1099047',
  );

  /// R76.
  static const halperin2022 = Citation(
    reference:
        'Halperin I, et al. (2022). Accuracy in predicting repetitions to task '
        'failure in resistance exercise: a scoping review and exploratory '
        'meta-analysis. Sports Med 52(2):377–390.',
    doi: '10.1007/s40279-021-01559-x',
  );

  /// R77.
  static const zourdos2016 = Citation(
    reference:
        'Zourdos MC, et al. (2016). Novel resistance training-specific rating '
        'of perceived exertion scale measuring repetitions in reserve. J '
        'Strength Cond Res 30(1):267–275.',
    doi: '10.1519/JSC.0000000000001049',
  );

  /// R78.
  static const epley1985 = Citation(
    reference:
        'Epley B (1985). Poundage Chart. Boyd Epley Workout. Lincoln, NE: Body '
        'Enterprises. No DOI; Unreviewed (practitioner chart, cited via '
        'Reynolds 2006 [R73]).',
    isPeerReviewed: false,
  );

  /// R81.
  static const robinson2024 = Citation(
    reference:
        'Robinson ZP, Pelland JC, Remmert JF, Refalo MC, Jukic I, Steele J, '
        'Zourdos MC (2024). Exploring the dose–response relationship between '
        'estimated resistance training proximity to failure, strength gain, '
        'and muscle hypertrophy: a series of meta-regressions. Sports Med '
        '54(9):2209–2231.',
    doi: '10.1007/s40279-024-02069-2',
  );

  /// R82.
  static const refalo2023 = Citation(
    reference:
        'Refalo MC, et al. (2023). Influence of resistance training '
        'proximity-to-failure on skeletal muscle hypertrophy: a systematic '
        'review with meta-analysis. Sports Med 53(3):649–665.',
    doi: '10.1007/s40279-022-01784-y',
  );

  /// R96.
  static const pelland = Citation(
    reference:
        'Pelland JC, et al. SportRxiv preprints 460 (v2, the above '
        'meta-regression) and 537 (follow-up). Unreviewed preprints.',
    url: 'https://sportrxiv.org/index.php/server/preprint/view/460',
    isPeerReviewed: false,
  );

  /// R97.
  static const schoenfeld2017 = Citation(
    reference:
        'Schoenfeld BJ, Ogborn D, Krieger JW (2017; online 2016). '
        'Dose-response relationship between weekly resistance training volume '
        'and increases in muscle mass: a systematic review and meta-analysis. '
        'J Sports Sci 35(11):1073–1082.',
    doi: '10.1080/02640414.2016.1210197',
  );

  /// R98.
  static const bazvalle2022 = Citation(
    reference:
        'Baz-Valle E, Balsalobre-Fernández C, Alix-Fages C, Santos-Concejero J '
        '(2022). A systematic review of the effects of different resistance '
        'training volumes on muscle hypertrophy. J Hum Kinet 81:199–210.',
    doi: '10.2478/hukin-2022-0017',
  );

  /// R99.
  static const schoenfeld2017b = Citation(
    reference:
        'Schoenfeld BJ, Grgic J, Ogborn D, Krieger JW (2017). Strength and '
        'hypertrophy adaptations between low- vs. high-load resistance '
        'training: a systematic review and meta-analysis. J Strength Cond Res '
        '31(12):3508–3523.',
    doi: '10.1519/JSC.0000000000002200',
  );

  /// R100.
  static const schoenfeld2021 = Citation(
    reference:
        'Schoenfeld BJ, Grgic J, Van Every DW, Plotkin DL (2021). Loading '
        'recommendations for muscle strength, hypertrophy, and local '
        'endurance: a re-examination of the repetition continuum. Sports '
        '9(2):32.',
    doi: '10.3390/sports9020032',
  );

  /// R103.
  static const scarpelli2022 = Citation(
    reference:
        'Scarpelli MC, Nóbrega SR, Santanielo N, Alvarez IF, Otoboni GB, '
        'Ugrinowitsch C, Libardi CA (2022; online 2020). Muscle hypertrophy '
        'response is affected by previous resistance training volume in '
        'trained individuals. J Strength Cond Res 36(4):1153–1157.',
    doi: '10.1519/JSC.0000000000003558',
  );

  /// R104.
  static const camargo2026 = Citation(
    reference:
        'Camargo JBB, et al. (2026). Large increases in resistance training '
        'volume do not impair muscle hypertrophy or anabolic–catabolic '
        'molecular signaling in trained individuals. J Appl Physiol (online '
        '16 July 2026).',
    doi: '10.1152/japplphysiol.00284.2026',
  );

  /// R105.
  static const spiering2021 = Citation(
    reference:
        'Spiering BA, Mujika I, Sharp MA, Foulis SA (2021). Maintaining '
        'physical performance: the minimal dose of exercise needed to '
        'preserve endurance and strength over time. J Strength Cond Res '
        '35(5):1449–1458.',
    doi: '10.1519/JSC.0000000000003964',
  );

  /// R34.
  static const hall2011b = Citation(
    reference:
        'Hall KD, Chow CC (2011). Estimating changes in free-living energy '
        'intake and its confidence interval. Am J Clin Nutr 94(1):66–74.',
    doi: '10.3945/ajcn.111.014399',
  );

  /// R35.
  static const sanghvi2015 = Citation(
    reference:
        'Sanghvi A, Redman LM, Martin CK, Ravussin E, Hall KD (2015). '
        'Validation of an inexpensive and accurate mathematical method to '
        'measure long-term changes in free-living energy intake. Am J Clin '
        'Nutr 102(2):353–358.',
    doi: '10.3945/ajcn.115.111070',
  );

  /// R37.
  static const guo2020 = Citation(
    reference:
        'Guo P, Rivera DE, Savage JS, Hohman EE, Pauley AM, Leonard KS, Downs '
        'DS (2020; online 2018). System identification approaches for energy '
        'intake estimation: enhancing interventions for managing gestational '
        'weight gain. IEEE Trans Control Syst Technol 28(1):63–78.',
    doi: '10.1109/TCST.2018.2871871',
  );

  /// R38.
  static const guo2017 = Citation(
    reference:
        'Guo P, Rivera DE, Savage JS, Downs DS (2017). State estimation under '
        'correlated partial measurement losses: implications for weight '
        'control interventions. IFAC-PapersOnLine 50(1):13532–13537 (20th '
        'IFAC World Congress). DOI not found — locate manually. Record:.',
    url: 'https://asu.elsevierpure.com/en/publications/state-estimation-under-correlated-partial-measurement-losses-impl/',
  );

  /// R14.
  static const nasem2023 = Citation(
    reference:
        'National Academies of Sciences, Engineering, and Medicine (2023). '
        'Dietary Reference Intakes for Energy. Washington, DC: National '
        'Academies Press.',
    doi: '10.17226/26818',
  );

  /// R36.
  static const lichtman1992 = Citation(
    reference:
        'Lichtman SW, et al. (1992). Discrepancy between self-reported and '
        'actual caloric intake and exercise in obese subjects. N Engl J Med '
        '327(27):1893–1898.',
    doi: '10.1056/NEJM199212313272701',
  );

  /// R40.
  static const martins2020 = Citation(
    reference:
        'Martins C, et al. (2020). Metabolic adaptation is an illusion, only '
        'present when participants are in negative energy balance. Am J Clin '
        'Nutr 112(5):1212–1218.',
    doi: '10.1093/ajcn/nqaa220',
  );

  /// R54.
  static const nunes2022b = Citation(
    reference:
        'Nunes CL, et al. (2022). Adaptive thermogenesis after moderate '
        'weight loss: magnitude and methodological issues. Eur J Nutr '
        '61(3):1405–1416.',
    doi: '10.1007/s00394-021-02742-6',
  );

  /// R21.
  static const acsm2021 = Citation(
    reference:
        "American College of Sports Medicine. ACSM's Guidelines for Exercise "
        'Testing and Prescription, 11th ed. Philadelphia: Wolters Kluwer, '
        '2021 (metabolic equations for walking). No DOI.',
  );

  /// R43.
  static const martin2015 = Citation(
    reference:
        'Martin CK, et al. (2015). Efficacy of SmartLoss, a smartphone-based '
        'weight loss intervention: results from a randomized controlled '
        'trial. Obesity 23(5):935–942.',
    doi: '10.1002/oby.21063',
  );

  /// R46.
  static const thomas2014 = Citation(
    reference:
        'Thomas DM, Martin CK, Redman LM, Heymsfield SB, Lettieri S, Levine '
        'JA, Bouchard C, Schoeller DA (2014). Effect of dietary adherence on '
        'the body weight plateau: a mathematical model incorporating '
        'intermittent compliance with energy intake prescription. Am J Clin '
        'Nutr 100(3):787–795.',
    doi: '10.3945/ajcn.113.079822',
  );

  /// R42.
  static const macrofactor = Citation(
    reference:
        'MacroFactor help centre, "How should I interpret changes to my '
        'energy expenditure?" (Unreviewed).',
    url: 'https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure',
    isPeerReviewed: false,
  );

  /// R25.
  static const hall2011 = Citation(
    reference:
        'Hall KD, Sacks G, Chandramohan D, Chow CC, Wang YC, Gortmaker SL, '
        'Swinburn BA (2011). Quantification of the effect of energy '
        'imbalance on bodyweight. Lancet 378(9793):826–837.',
    doi: '10.1016/S0140-6736(11)60812-X',
  );

  /// R17.
  static const iom2005 = Citation(
    reference:
        'Institute of Medicine (2005). Dietary Reference Intakes for Energy, '
        'Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and '
        'Amino Acids. Washington, DC: National Academies Press.',
    doi: '10.17226/10490',
  );

  /// R55.
  static const thomas2016 = Citation(
    reference:
        'Thomas DT, Erdman KA, Burke LM (2016). Position of the Academy of '
        'Nutrition and Dietetics, Dietitians of Canada, and the American '
        'College of Sports Medicine: nutrition and athletic performance. J '
        'Acad Nutr Diet 116(3):501–528.',
    doi: '10.1016/j.jand.2015.12.006',
  );

  /// R56.
  static const whittaker2021 = Citation(
    reference:
        'Whittaker J, Wu K (2021). Low-fat diets and testosterone in men: '
        'systematic review and meta-analysis of intervention studies. J '
        'Steroid Biochem Mol Biol 210:105878.',
    doi: '10.1016/j.jsbmb.2021.105878',
  );

  /// R57.
  static const iraki2019 = Citation(
    reference:
        'Iraki J, Fitschen P, Espinar S, Helms E (2019). Nutrition '
        'recommendations for bodybuilders in the off-season: a narrative '
        'review. Sports 7(7):154.',
    doi: '10.3390/sports7070154',
  );

  /// R58.
  static const feinman2015 = Citation(
    reference:
        'Feinman RD, et al. (2015). Dietary carbohydrate restriction as the '
        'first approach in diabetes management: critical review and evidence '
        'base. Nutrition 31(1):1–13.',
    doi: '10.1016/j.nut.2014.06.011',
  );

  /// R59.
  static const henselmans2022 = Citation(
    reference:
        'Henselmans M, Bjørnsen T, Hedderman R, Vårvik FT (2022). The effect '
        'of carbohydrate intake on strength and resistance training '
        'performance: a systematic review. Nutrients 14(4):856.',
    doi: '10.3390/nu14040856',
  );

  /// R60.
  static const fao2003 = Citation(
    reference:
        'FAO (2003). Food energy – methods of analysis and conversion '
        'factors. FAO Food and Nutrition Paper 77. Rome: FAO.',
    url: 'https://www.fao.org/4/y5022e/y5022e00.htm',
  );

  /// R10.
  static const fao2004 = Citation(
    reference:
        'FAO/WHO/UNU (2004). Human energy requirements: report of a joint '
        'FAO/WHO/UNU expert consultation, Rome, 17–24 October 2001. FAO '
        'Food and Nutrition Technical Report Series 1. Rome: FAO.',
    url: 'https://www.fao.org/4/y5686e/y5686e00.htm',
  );

  /// R11.
  static const pontzer2016 = Citation(
    reference:
        'Pontzer H, et al. (2016). Constrained total energy expenditure '
        'and metabolic adaptation to physical activity in adult humans. '
        'Curr Biol 26(3):410–417.',
    doi: '10.1016/j.cub.2015.12.046',
  );

  /// R12.
  static const pontzer2012 = Citation(
    reference:
        'Pontzer H, Raichlen DA, Wood BM, Mabulla AZP, Racette SB, Marlowe '
        'FW (2012). Hunter-gatherer energetics and human obesity. PLoS One '
        '7(7):e40503.',
    doi: '10.1371/journal.pone.0040503',
  );

  /// R13.
  static const boning2018 = Citation(
    reference:
        'Böning D (2018). Fat in spite of exercise? An alleged paradigm '
        'change results from calculation mistakes (editorial). Dtsch Z '
        'Sportmed 69(1):3–4.',
    doi: '10.5960/dzsm.2017.311',
  );

  /// R19.
  static const pontzer2021 = Citation(
    reference:
        'Pontzer H, et al. (2021). Daily energy expenditure through the '
        'human life course. Science 373(6556):808–812.',
    doi: '10.1126/science.abe5017',
  );

  /// R4.
  static const frankenfield2005 = Citation(
    reference:
        'Frankenfield D, Roth-Yousey L, Compher C (2005). Comparison of '
        'predictive equations for resting metabolic rate in healthy '
        'nonobese and obese adults: a systematic review. J Am Diet Assoc '
        '105(5):775–789.',
    doi: '10.1016/j.jada.2005.02.005',
  );

  /// R5.
  static const madden2016 = Citation(
    reference:
        'Madden AM, Mulrooney HM, Shah S (2016). Estimation of energy '
        'expenditure using prediction equations in overweight and obese '
        'adults: a systematic review. J Hum Nutr Diet 29(4):458–476.',
    doi: '10.1111/jhn.12355',
  );

  /// R47.
  static const morton2018 = Citation(
    reference:
        'Morton RW, et al. (2018). A systematic review, meta-analysis and '
        'meta-regression of the effect of protein supplementation on '
        'resistance training-induced gains in muscle mass and strength in '
        'healthy adults. Br J Sports Med 52(6):376–384.',
    doi: '10.1136/bjsports-2017-097608',
  );

  /// R48.
  static const nunes2022 = Citation(
    reference:
        'Nunes EA, et al. (2022). Systematic review and meta-analysis of '
        'protein intake to support muscle mass and function in healthy '
        'adults. J Cachexia Sarcopenia Muscle 13(2):795–810.',
    doi: '10.1002/jcsm.12922',
  );

  /// R49.
  static const helms2014 = Citation(
    reference:
        'Helms ER, Zinn C, Rowlands DS, Brown SR (2014). A systematic '
        'review of dietary protein during caloric restriction in '
        'resistance trained lean athletes: a case for higher intakes. Int '
        'J Sport Nutr Exerc Metab 24(2):127–138.',
    doi: '10.1123/ijsnem.2013-0054',
  );

  /// R50.
  static const devries2018 = Citation(
    reference:
        'Devries MC, Sithamparapillai A, Brimble KS, Banfield L, Morton '
        'RW, Phillips SM (2018). Changes in kidney function do not differ '
        'between healthy adults consuming higher- compared with lower- or '
        'normal-protein diets: a systematic review and meta-analysis. J '
        'Nutr 148(11):1760–1775.',
    doi: '10.1093/jn/nxy197',
  );

  /// R51.
  static const weijs2025 = Citation(
    reference:
        'Weijs PJM (2025). Protein requirement in obesity. Curr Opin Clin '
        'Nutr Metab Care 28(1).',
    doi: '10.1097/MCO.0000000000001087',
  );

  /// R52.
  static const dekker2022 = Citation(
    reference:
        'Dekker IM, van Rijssen NM, Verreijen A, Weijs PJM, de Boer WB, '
        'Terpstra D, Kruizenga HM (2022). Calculation of protein '
        'requirements: a comparison of calculations based on bodyweight '
        'and fat free mass. Clin Nutr ESPEN 48:378–385.',
    doi: '10.1016/j.clnesp.2022.01.014',
  );

  /// R53.
  static const bauer2013 = Citation(
    reference:
        'Bauer J, et al. (2013). Evidence-based recommendations for '
        'optimal dietary protein intake in older people: a position paper '
        'from the PROT-AGE Study Group. J Am Med Dir Assoc 14(8):542–559.',
    doi: '10.1016/j.jamda.2013.05.021',
  );

  /// R69.
  static const jensen2014 = Citation(
    reference:
        'Jensen MD, et al. (2014; online 2013). 2013 AHA/ACC/TOS guideline '
        'for the management of overweight and obesity in adults. '
        'Circulation 129(25 Suppl 2):S102–S138.',
    doi: '10.1161/01.cir.0000437739.71477.ee',
  );

  /// R67.
  static const niddk = Citation(
    reference:
        'National Institute of Diabetes and Digestive and Kidney Diseases. '
        '"Very-low-calorie diet" (health dictionary).',
    url: 'https://www.niddk.nih.gov/Dictionary/V/very-low-calorie-diet',
  );

  /// R61.
  static const campbell2020 = Citation(
    reference:
        'Campbell BI, et al. (2020). Intermittent energy restriction '
        'attenuates the loss of fat free mass in resistance trained '
        'individuals: a randomized controlled trial. J Funct Morphol '
        'Kinesiol 5(1):19.',
    doi: '10.3390/jfmk5010019',
  );

  /// R62.
  static const peos2021 = Citation(
    reference:
        'Peos JJ, Helms ER, Fournier PA, Krieger J, Sainsbury A (2021). A '
        '1-week diet break improves muscle endurance during an '
        'intermittent dieting regime in adult athletes: a pre-specified '
        'secondary analysis of the ICECAP trial. PLoS One 16(2):e0247292.',
    doi: '10.1371/journal.pone.0247292',
  );

  /// R63.
  static const helms2014b = Citation(
    reference:
        'Helms ER, Aragon AA, Fitschen PJ (2014). Evidence-based '
        'recommendations for natural bodybuilding contest preparation: '
        'nutrition and supplementation. J Int Soc Sports Nutr 11:20.',
    doi: '10.1186/1550-2783-11-20',
  );

  /// R64.
  static const garthe2011 = Citation(
    reference:
        'Garthe I, Raastad T, Refsnes PE, Koivisto A, Sundgot-Borgen J '
        '(2011). Effect of two different weight-loss rates on body '
        'composition and strength and power-related performance in elite '
        'athletes. Int J Sport Nutr Exerc Metab 21(2):97–104.',
    doi: '10.1123/ijsnem.21.2.97',
  );

  /// R65.
  static const purcell2014 = Citation(
    reference:
        'Purcell K, Sumithran P, Prendergast LA, Bouniu CJ, Delbridge E, '
        'Proietto J (2014). The effect of rate of weight loss on long-term '
        'weight management: a randomised controlled trial. Lancet Diabetes '
        'Endocrinol 2(12):954–962.',
    doi: '10.1016/S2213-8587(14)70200-1',
  );

  /// R66.
  static const helms2023 = Citation(
    reference:
        'Helms ER, et al. (2023). Effect of small and large energy '
        'surpluses on strength, muscle, and skinfold thickness in '
        'resistance-trained individuals: a parallel groups design. Sports '
        'Med Open 9:102.',
    doi: '10.1186/s40798-023-00651-y',
  );

  /// R23.
  static const wishnofsky1958 = Citation(
    reference:
        'Wishnofsky M (1958). Caloric equivalents of gained or lost '
        'weight. Am J Clin Nutr 6(5):542–546.',
    doi: '10.1093/ajcn/6.5.542',
  );

  /// R24.
  static const hall2008 = Citation(
    reference:
        'Hall KD (2008). What is the required energy deficit per unit '
        'weight loss? Int J Obes 32(3):573–576.',
    doi: '10.1038/sj.ijo.0803720',
  );

  /// R45.
  static const guo2018 = Citation(
    reference:
        'Guo J, Brager DC, Hall KD (2018). Simulating long-term human '
        'weight-loss dynamics in response to calorie restriction. Am J '
        'Clin Nutr 107(4):558–565.',
    doi: '10.1093/ajcn/nqx080',
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

  /// The estimated one-rep max (Swift `MethodInfo.estimatedOneRepMax`),
  /// computed by `compound_maths`' `estimatedOneRepMax`.
  factory estimatedOneRepMax(AppLocalizations l10n) => MethodInfo(
    title: l10n.e1rmMethodTitle,
    summary: l10n.e1rmMethodSummary,
    formula:
        'n = reps + (10 − RPE)   (RPE logged)\n'
        'n = reps                (no RPE)\n'
        'e1RM = weight                 if n ≤ 1\n'
        'e1RM = weight × (1 + n / 30)  if 1 < n ≤ 10\n'
        'no estimate                   if n > 10',
    limitations: l10n.e1rmMethodLimitations,
    ownChoices: l10n.e1rmMethodOwnChoices,
    citations: const [
      Citation.reynolds2006,
      Citation.epley1985,
      Citation.zourdos2016,
      Citation.halperin2022,
      Citation.richens2014,
      Citation.ribeiro2024,
    ],
  );

  /// What counts as a hard set (Swift `MethodInfo.weeklyHardSets`),
  /// computed by `compound_maths`' `hardSets`.
  factory weeklyHardSets(AppLocalizations l10n) => MethodInfo(
    title: l10n.hardSetsMethodTitle,
    summary: l10n.hardSetsMethodSummary,
    formula:
        'hard set = completed AND not warm-up AND (RPE missing OR RPE ≥ 6)\n'
        'set credit = min(2, 1 + 0.5 × finished drops or myo/rest-pause '
        'mini-sets)\n'
        'muscle sets = Σ set credit × (1 if primary, 0.5 if secondary)\n'
        'left + right pair = one set, worth its better half',
    limitations: l10n.hardSetsMethodLimitations,
    ownChoices: l10n.hardSetsMethodOwnChoices,
    citations: const [
      Citation.pelland2026,
      Citation.robinson2024,
      Citation.refalo2023,
      Citation.schoenfeld2021,
      Citation.schoenfeld2017b,
    ],
  );

  /// The weekly volume tiers (Swift `MethodInfo.weeklyVolumeTiers`),
  /// computed by `compound_maths`' `VolumeTier.of`.
  factory weeklyVolumeTiers(AppLocalizations l10n) => MethodInfo(
    title: l10n.volumeTiersMethodTitle,
    summary: l10n.volumeTiersMethodSummary,
    formula:
        '< 4 sets/week    below maintenance\n'
        '4 to < 10        maintaining\n'
        '10–20            productive\n'
        '> 20             high',
    limitations: l10n.volumeTiersMethodLimitations,
    ownChoices: l10n.volumeTiersMethodOwnChoices,
    citations: const [
      Citation.pelland2026,
      Citation.schoenfeld2017,
      Citation.bazvalle2022,
      Citation.spiering2021,
      Citation.pelland,
    ],
  );

  /// The per-muscle volume suggestion (Swift
  /// `MethodInfo.volumeRecommendation`), computed by `compound_maths`'
  /// `recommendVolume`.
  factory volumeRecommendation(AppLocalizations l10n) => MethodInfo(
    title: l10n.volumeRecommendationTitle,
    summary: l10n.volumeRecommendationMethodSummary,
    formula:
        'baseline = median weekly hard sets, last 4 weeks\n'
        '  (fewer than 4 trained weeks: clamped into 10–20)\n'
        'trend = median over primary exercises of\n'
        '        least-squares slope of e1RM ÷ mean e1RM × 7 × 100  (%/week)\n'
        'adherence < 80%                  → be consistent first\n'
        'trend < −0.5 OR RPE drift ≥ +1   → reduce 20–33%\n'
        'trend > +0.5                     → keep\n'
        'otherwise                        → add max(10%, 1 set) to 20%\n'
        'floor 4 sets (6 from age 60); suggestions rounded to whole sets',
    limitations: l10n.volumeRecommendationMethodLimitations,
    ownChoices: l10n.volumeRecommendationMethodOwnChoices,
    citations: const [
      Citation.scarpelli2022,
      Citation.camargo2026,
      Citation.spiering2021,
      Citation.pelland2026,
    ],
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

  /// A mesocycle's deload week (Swift `MethodInfo.mesocycleDeload`),
  /// applied by `training_session`'s `deloadedSession`.
  factory mesocycleDeload(AppLocalizations l10n) => MethodInfo(
    title: l10n.programDeloadWeek,
    summary: l10n.deloadMethodSummary,
    formula:
        'sets kept = max(1, ⌈planned working sets × 0.5⌉)\n'
        'weight = planned weight × 0.90, rounded down to equipment\n'
        'assistance = planned assistance × 1.10\n'
        'progression afterwards reads past the deload week',
    limitations: l10n.deloadMethodLimitations,
    ownChoices: l10n.deloadMethodOwnChoices,
    citations: const [
      Citation.bell2023,
      Citation.rogerson2024,
      Citation.bell2022,
      Citation.coleman2024,
    ],
  );

  /// The adaptive expenditure estimate (Swift
  /// `MethodInfo.adaptiveExpenditure`), computed by `compound_maths`'
  /// `expenditureHistory`.
  factory adaptiveExpenditure(AppLocalizations l10n) => MethodInfo(
    title: l10n.adaptiveExpenditureMethodTitle,
    summary: l10n.adaptiveExpenditureMethodSummary,
    formula: _adaptiveExpenditureFormula,
    limitations: l10n.adaptiveExpenditureMethodLimitations,
    ownChoices: l10n.adaptiveExpenditureMethodOwnChoices,
    citations: const [
      Citation.hall2011b,
      Citation.sanghvi2015,
      Citation.guo2020,
      Citation.guo2017,
      Citation.nasem2023,
      Citation.lichtman1992,
      Citation.martins2020,
      Citation.nunes2022b,
      Citation.acsm2021,
    ],
  );

  /// The energy balance (Swift `MethodInfo.energyBalance`), computed by
  /// `expenditureOn` and `loggedAverage`.
  factory energyBalance(AppLocalizations l10n) => MethodInfo(
    title: l10n.energyBalanceTitle,
    summary: l10n.energyBalanceMethodSummary,
    formula:
        'balance = expenditure − mean(intake over logged days)\n'
        'positive → deficit, negative → surplus\n'
        "expenditure on a day = that day's adaptive estimate\n"
        '  (last estimate after the history stops; formula before it starts)',
    limitations: l10n.energyBalanceMethodLimitations,
    ownChoices: l10n.energyBalanceMethodOwnChoices,
    citations: const [
      Citation.sanghvi2015,
      Citation.lichtman1992,
      Citation.hall2011b,
    ],
  );

  /// Target suggestions (Swift `MethodInfo.targetProposal`), computed by
  /// `evaluateTarget`.
  factory targetProposal(AppLocalizations l10n) => MethodInfo(
    title: l10n.targetProposalMethodTitle,
    summary: l10n.targetProposalMethodSummary,
    formula: _targetProposalFormula,
    limitations: l10n.targetProposalMethodLimitations,
    ownChoices: l10n.targetProposalMethodOwnChoices,
    citations: const [
      Citation.martin2015,
      Citation.thomas2014,
      Citation.macrofactor,
      Citation.hall2011,
    ],
  );

  /// The weekly check-in's rules (Swift `MethodInfo.checkInRules`), applied
  /// by `CheckInFlow` and `expenditureSamples`.
  factory checkInRules(AppLocalizations l10n) => MethodInfo(
    title: l10n.checkInRulesMethodTitle,
    summary: l10n.checkInRulesMethodSummary,
    formula:
        'incomplete or in a break → intake not read; weigh-in still used\n'
        'fast → intake read as logged (0 kcal if nothing logged)\n'
        'logged < 0.5 × expenditure and not a fast → treated as partial\n'
        'weigh-in step shown when the latest weigh-in is > 3 days old',
    limitations: l10n.checkInRulesMethodLimitations,
    ownChoices: l10n.checkInRulesMethodOwnChoices,
    citations: const [
      Citation.lichtman1992,
      Citation.guo2017,
      Citation.hall2011b,
    ],
  );

  /// The fat and carbohydrate split (Swift `MethodInfo.macroSplit`),
  /// computed by `dailyMacros`.
  factory macroSplit(AppLocalizations l10n) => MethodInfo(
    title: l10n.macroSplitMethodTitle,
    summary: l10n.macroSplitMethodSummary,
    formula:
        'remaining = calories − 4 × protein g\n'
        'fat kcal: balanced 0.30 × calories, low fat 0.20 × calories,\n'
        '  low carb remaining − 0.20 × calories, keto remaining − '
        'min(4 × 30, remaining)\n'
        'fat kcal = min(remaining, max(fat kcal, 9 × 0.5 × reference kg, '
        '0.20 × calories))\n'
        'carb g = (remaining − fat kcal) ÷ 4\n'
        'Atwater factors: protein 4, carbs 4, fat 9 kcal/g',
    limitations: l10n.macroSplitMethodLimitations,
    ownChoices: l10n.macroSplitMethodOwnChoices,
    citations: const [
      Citation.iom2005,
      Citation.thomas2016,
      Citation.whittaker2021,
      Citation.iraki2019,
      Citation.feinman2015,
      Citation.henselmans2022,
      Citation.fao2003,
    ],
  );

  /// Waist-to-height (Swift `MethodInfo.waistToHeightRatio`), computed by
  /// `compound_maths`' `bodyRatio` and banded by `bodyRatioBand`.
  factory waistToHeightRatio(AppLocalizations l10n) => MethodInfo(
    title: l10n.waistToHeightMethodTitle,
    summary: l10n.waistToHeightMethodSummary,
    formula:
        'ratio = waist (cm) ÷ height (cm)\n'
        '< 0.50       under half your height (0.40–0.49 healthy)\n'
        '0.50–0.59    increased risk\n'
        '≥ 0.60       high risk',
    limitations: l10n.waistToHeightMethodLimitations,
    citations: const [Citation.niddk2025],
  );

  /// Waist-to-hip (Swift `MethodInfo.waistToHipRatio`), computed by
  /// `compound_maths`' `bodyRatio` and banded by `bodyRatioBand`.
  factory waistToHipRatio(AppLocalizations l10n) => MethodInfo(
    title: l10n.waistToHipMethodTitle,
    summary: l10n.waistToHipMethodSummary,
    formula:
        'ratio = waist (cm) ÷ hip (cm)\n'
        'substantially increased risk: ≥ 0.90 (men), ≥ 0.85 (women)',
    limitations: l10n.waistToHipMethodLimitations,
    citations: const [Citation.who2011, Citation.niddk2025],
  );

  /// Goal progress (Swift `MethodInfo.goalProgress`), computed by
  /// `goalFraction` over the trend weight.
  factory goalProgress(AppLocalizations l10n) => MethodInfo(
    title: l10n.progressGoalProgress,
    summary: l10n.goalProgressMethodSummary,
    formula:
        'progress = clamp(|start − trend weight| ÷ |start − target|, 0, 1)',
    limitations: l10n.goalProgressMethodLimitations,
    citations: const [Citation.schneditz2023],
  );

  /// Volume, or tonnage (Swift `MethodInfo.tonnage`), computed by
  /// `WorkoutSetStats.volumeKg`.
  factory tonnage(AppLocalizations l10n) => MethodInfo(
    title: l10n.tonnageMethodTitle,
    summary: l10n.tonnageMethodSummary,
    formula:
        'volume = Σ (external load × weights held + bodyweight × share − '
        'assistance) × reps × sides\n'
        "bodyweight share = exercise's bodyweight contribution (setting on, "
        'your own workouts)',
    limitations: l10n.tonnageMethodLimitations,
    ownChoices: l10n.tonnageMethodOwnChoices,
    citations: const [Citation.ebben2011, Citation.suprak2011],
  );

  /// Formula Expenditure Estimate (Swift `MethodInfo.formulaExpenditure`).
  factory formulaExpenditure(AppLocalizations l10n) => MethodInfo(
    title: l10n.formulaExpenditureMethodTitle,
    summary: l10n.formulaExpenditureMethodSummary,
    formula:
        'TDEE = RMR × PAL\n'
        'PAL: sedentary 1.40, light 1.55, moderate 1.70, active 1.85, '
        'very active 2.00\n'
        'TDEE ≥ 1,000 kcal\n'
        '(FAO/WHO/UNU bands: sedentary or light 1.40–1.69, active '
        '1.70–1.99, vigorous 2.00–2.40)',
    limitations: l10n.formulaExpenditureMethodLimitations,
    ownChoices: l10n.formulaExpenditureMethodOwnChoices,
    citations: const [
      Citation.fao2004,
      Citation.pontzer2016,
      Citation.pontzer2012,
      Citation.boning2018,
      Citation.pontzer2021,
      Citation.frankenfield2005,
      Citation.madden2016,
    ],
  );

  /// Protein Target (Swift `MethodInfo.proteinTarget`).
  factory proteinTarget(AppLocalizations l10n) => MethodInfo(
    title: l10n.proteinTargetMethodTitle,
    summary: l10n.proteinTargetMethodSummary,
    formula:
        'g/kg: low 1.6, moderate 2.0, high 2.2, very high 2.6\n'
        'protein = g/kg × reference weight\n'
        'reference weight = weight, if BMI < 30\n'
        '  otherwise min(weight, max(30 × height(m)², goal weight))\n'
        'age ≥ 65: g/kg ≥ 1.2',
    limitations: l10n.proteinTargetMethodLimitations,
    ownChoices: l10n.proteinTargetMethodOwnChoices,
    citations: const [
      Citation.morton2018,
      Citation.nunes2022,
      Citation.helms2014,
      Citation.devries2018,
      Citation.weijs2025,
      Citation.dekker2022,
      Citation.bauer2013,
      Citation.thomas2016,
    ],
  );

  /// Calorie Floor (Swift `MethodInfo.calorieFloor`).
  factory calorieFloor(AppLocalizations l10n) => MethodInfo(
    title: l10n.calorieFloorMethodTitle,
    summary: l10n.calorieFloorMethodSummary,
    formula:
        'floor = 1,200 (female), 1,500 (male), 1,350 (not stated)\n'
        'target = max(floor, expenditure − min(goal deficit, '
        '0.25 × expenditure))',
    limitations: l10n.calorieFloorMethodLimitations,
    ownChoices: l10n.calorieFloorMethodOwnChoices,
    citations: const [Citation.jensen2014, Citation.niddk, Citation.niddk2025],
  );

  /// Calorie Distribution (Swift `MethodInfo.calorieCycling`).
  factory calorieCycling(AppLocalizations l10n) => MethodInfo(
    title: l10n.calorieCyclingMethodTitle,
    summary: l10n.calorieCyclingMethodSummary,
    formula:
        'N = training days in the program (1–6)\n'
        'bonus = min(0.10, 0.15 × (7 − N) ÷ N)\n'
        'high day = target × (1 + bonus)\n'
        'other days = target × (1 − bonus × N ÷ (7 − N))\n'
        'weekly total = 7 × target',
    limitations: l10n.calorieCyclingMethodLimitations,
    ownChoices: l10n.calorieCyclingMethodOwnChoices,
    citations: const [Citation.campbell2020, Citation.peos2021],
  );

  /// Weekly Rate (Swift `MethodInfo.weightChangeRate`).
  factory weightChangeRate(AppLocalizations l10n) => MethodInfo(
    title: l10n.weightChangeRateMethodTitle,
    summary: l10n.weightChangeRateMethodSummary,
    formula:
        'lose: 0.25% to min(1% × weight, 1.5 kg) a week\n'
        '  default 0.5% (BMI < 25) or 0.75%; warning above 0.75% if BMI < 25\n'
        'gain: 0.1% to min(1% × weight, 1.5 kg) a week\n'
        '  default 0.25%; warning above 0.5%\n'
        'daily kcal = weekly kg × 7,700 ÷ 7',
    limitations: l10n.weightChangeRateMethodLimitations,
    ownChoices: l10n.weightChangeRateMethodOwnChoices,
    citations: const [
      Citation.helms2014b,
      Citation.garthe2011,
      Citation.purcell2014,
      Citation.iraki2019,
      Citation.helms2023,
      Citation.wishnofsky1958,
      Citation.hall2008,
    ],
  );

  /// Goal Timeline (Swift `MethodInfo.goalTimeline`).
  factory goalTimeline(AppLocalizations l10n) => MethodInfo(
    title: l10n.goalTimelineMethodTitle,
    summary: l10n.goalTimelineMethodSummary,
    formula:
        'weeks = ⌈|target weight − current weight| ÷ weekly rate⌉\n'
        'target change by goal ≈ 24 kcal/day × kg to go',
    limitations: l10n.goalTimelineMethodLimitations,
    citations: const [
      Citation.hall2011,
      Citation.guo2018,
      Citation.martins2020,
      Citation.thomas2014,
    ],
  );

  /// Every method ported so far, keyed by its Swift `MethodInfo.id`, in
  /// Swift's order (`MethodInfo.all`: energy, nutrition, training, volume,
  /// habits), for Settings › Methods & Sources. Add each new method here.
  static Map<String, MethodInfo> all(AppLocalizations l10n) => {
    'weight-trend': MethodInfo.weightTrend(l10n),
    'training.e1rm': MethodInfo.estimatedOneRepMax(l10n),
    'volume.hardSets': MethodInfo.weeklyHardSets(l10n),
    'volume.tiers': MethodInfo.weeklyVolumeTiers(l10n),
    'adaptive-expenditure': MethodInfo.adaptiveExpenditure(l10n),
    'energy-balance': MethodInfo.energyBalance(l10n),
    'target-proposal': MethodInfo.targetProposal(l10n),
    'check-in-rules': MethodInfo.checkInRules(l10n),
    'formula-expenditure': MethodInfo.formulaExpenditure(l10n),
    'protein-target': MethodInfo.proteinTarget(l10n),
    'macro-split': MethodInfo.macroSplit(l10n),
    'calorie-floor': MethodInfo.calorieFloor(l10n),
    'calorie-cycling': MethodInfo.calorieCycling(l10n),
    'weight-change-rate': MethodInfo.weightChangeRate(l10n),
    'goal-timeline': MethodInfo.goalTimeline(l10n),
    'volume.plannedSets': MethodInfo.plannedSetsPerMuscle(l10n),
    'volume.recommendation': MethodInfo.volumeRecommendation(l10n),
    'habits.weeklyGoal': MethodInfo.weeklySessionGoal(l10n),
    'habits.stepGoal': MethodInfo.dailyStepGoal(l10n),
    'habits.adherenceBand': MethodInfo.calorieAdherenceBand(l10n),
    'habits.waistToHeight': MethodInfo.waistToHeightRatio(l10n),
    'habits.waistToHip': MethodInfo.waistToHipRatio(l10n),
    'goal-progress': MethodInfo.goalProgress(l10n),
    'training.tonnage': MethodInfo.tonnage(l10n),
  };

  static const _adaptiveExpenditureFormula = '''
State x = [L (kg), E (kcal/d), T (kcal/d)], one step per day:
  L ← L + (E − T)/ρ        ρ = energy per kg (see Energy in a kilogram)
  process SDs per day: L 0.05 kg, E 30 kcal, T 13 kcal
Weigh-in observes L (weight trend rules); complete logged day observes E:
  σ_I = SD of your logged days in the last 28, held in 300–500 kcal
        (400 with fewer than 7), ×2 if under 60% of days are logged
  a day below 0.5·T is skipped unless marked as a fast
Start: T = E = formula, SD(T) = max(0.15·formula, 340), SD(E) = 500
Calibrating until: ≥21 days, ≥14 weigh-ins, √P_TT < 200 kcal and ≥80% of the
  last 28 days logged. Until then the formula figure is shown.
Shown: clamp(T, 0.6·formula, 1.6·formula) + step nowcast
80% interval: T ± 1.28·√P_TT
Step nowcast (optional): (mean steps last 7 d − mean steps last 28 d)
  × 0.0004 kcal/step/kg × trend weight, capped at ±300 kcal''';

  static const _targetProposalFormula = '''
target = T + ρ·r/7                 r = goal rate, kg/week (negative to lose)
target = max(target, calorie floor)
suggest if |target − current| > max(50, SD of T)
       and the plan is ≥ 7 days old and the estimate is calibrated
new target = current + clamp(target − current, −150, +150)
adherence first: if lowering, last week's mean logged intake > 1.10 × current
       and the trend rate is above the goal rate → no change, a note instead''';

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
