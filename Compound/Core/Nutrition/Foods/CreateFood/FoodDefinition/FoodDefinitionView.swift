import SwiftUI

struct FoodDefinitionDelegate {
    
    let mealItems: Binding<[MealItemModel]>?
    let nutritionDefinitionOption: NutritionDefinitionOption
    
    let image: PlatformImage?
    let name: String
    let brandName: String?
    let barcode: String?
    
    let imageFront: PlatformImage?
    let nutritionImage: PlatformImage?
    
    var servingWeight: Double?
    var portionSize: Double?
    var portionName: String?
    
    var portionWeight: Double?
    var weightPortionSize: Double?
    var weightPortionName: String?
    
    var portionVolume: Double?
    var volumePortionSize: Double?
    var volumePortionName: String?

    init(
        mealItems: Binding<[MealItemModel]>? = nil,
        nutritionDefinitionOption: NutritionDefinitionOption,
        image: PlatformImage?,
        name: String,
        brandName: String?,
        barcode: String?,
        imageFront: PlatformImage?,
        nutritionImage: PlatformImage?,
        servingWeight: Double? = nil,
        portionSize: Double? = nil,
        portionName: String? = nil,
        portionWeight: Double? = nil,
        weightPortionSize: Double? = nil,
        weightPortionName: String? = nil,
        portionVolume: Double? = nil,
        volumePortionSize: Double? = nil,
        volumePortionName: String? = nil
    ) {
        self.mealItems = mealItems
        self.nutritionDefinitionOption = nutritionDefinitionOption
        self.image = image
        self.name = name
        self.brandName = brandName
        self.barcode = barcode
        self.imageFront = imageFront
        self.nutritionImage = nutritionImage
        self.servingWeight = servingWeight
        self.portionSize = portionSize
        self.portionName = portionName
        self.portionWeight = portionWeight
        self.weightPortionSize = weightPortionSize
        self.weightPortionName = weightPortionName
        self.portionVolume = portionVolume
        self.volumePortionSize = volumePortionSize
        self.volumePortionName = volumePortionName
    }
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct FoodDefinitionView: View {

    @State var presenter: FoodDefinitionPresenter
    let delegate: FoodDefinitionDelegate

    var body: some View {
        Form {
            foodDetailSections
        }
        .navigationTitle("Create Food")
        // A name was entered to get here, so a swipe would throw it away; Back leads to Close,
        // which asks first.
        .interactiveDismissDisabled()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .bottomCTA {
            if presenter.canAddToPlate(delegate: delegate) {
                CallToActionButton(isLoading: presenter.isSaving) {
                    presenter.onCreateAndAddPressed(delegate: delegate)
                } label: {
                    Text("Create & Add")
                }
                .disabled(!presenter.canCreate)
            }
            CallToActionButton(isPrimaryAction: !presenter.canAddToPlate(delegate: delegate), isLoading: presenter.isSaving) {
                presenter.onCreatePressed(delegate: delegate)
            } label: {
                Text("Create")
            }
            .disabled(!presenter.canCreate)
        }
    }

    // MARK: - Food detail

    /// One section per nutrient group, each a disclosure of labelled number fields. Only calories
    /// and macros start open.
    @ViewBuilder
    private var foodDetailSections: some View {
        Section {
            DisclosureGroup(isExpanded: $presenter.isShowingMacros) {
                NumberField(
                    "0",
                    value: $presenter.energy,
                    units: Array(EnergyUnit.allCases),
                    selection: $presenter.energyUnit,
                    label: String(localized: "Energy")
                )
                fields(Self.macros)
            } label: {
                Text("Calories & Macros")
                    .font(.sectionTitle)
            }
        } header: {
            VStack(alignment: .leading) {
                Text("Provide nutrition facts for \(delegate.nutritionDefinitionOption.name.lowercased())")
                if let portionSize = delegate.portionSize, let portionName = delegate.portionName {
                    Text("Serving Size: \(portionSize.formatted()) \(portionName)")
                        .font(.label)
                }
            }
        }
        group("Carbs Breakdown", Self.carbs)
        group("Fats Breakdown", Self.fats)
        group("Protein Breakdown", Self.proteins)
        group("Vitamins Breakdown", Self.vitamins)
        group("Minerals Breakdown", Self.minerals)
        group("Other", Self.other)
    }

    private func group(_ title: LocalizedStringKey, _ rows: [Row]) -> some View {
        Section {
            DisclosureGroup {
                fields(rows)
            } label: {
                Text(title)
                    .font(.sectionTitle)
            }
        }
    }

    private func fields(_ rows: [Row]) -> some View {
        ForEach(rows, id: \.label) { row in
            NumberField("0", value: $presenter[dynamicMember: row.value], unit: row.key.unit, label: row.label)
        }
    }

    // MARK: - Fields

    /// A nutrient field: its label, the presenter property it edits, and the nutrient it is stored
    /// as. The unit shown is the one that nutrient is stored in, so sodium reads "mg" and vitamin D
    /// "mcg"; one shared "g" label used to store 0.4 typed as grams of sodium as 0.4 mg.
    private struct Row {
        let label: String
        let value: ReferenceWritableKeyPath<FoodDefinitionPresenter, Double?>
        let key: NutrientKey

        init(_ label: String.LocalizationValue, _ value: ReferenceWritableKeyPath<FoodDefinitionPresenter, Double?>, _ key: NutrientKey) {
            self.label = String(localized: label)
            self.value = value
            self.key = key
        }
    }

    private static let macros: [Row] = [
        Row("Protein", \.protein, .protein),
        Row("Carbs", \.carbs, .carbs),
        Row("Fats", \.fats, .fatTotal)
    ]

    private static let carbs: [Row] = [
        Row("Fiber", \.fiber, .fiber),
        Row("Starch", \.starch, .starch),
        Row("Sugars", \.sugars, .sugar),
        Row("Sugars (Added)", \.addedSugars, .addedSugars)
    ]

    private static let fats: [Row] = [
        Row("Monounsaturated Fat", \.monounsaturatedFats, .fatMonounsaturated),
        Row("Polyunsaturated Fat", \.polyunsaturatedFats, .fatPolyunsaturated),
        Row("Omega-3", \.omega3, .omega3),
        Row("Omega-3 ALA", \.omega3Ala, .omega3Ala),
        Row("Omega-3 DHA", \.omega3Dha, .omega3Dha),
        Row("Omega-3 EPA", \.omega3Epa, .omega3Epa),
        Row("Omega-6", \.omega6, .omega6),
        Row("Saturated Fat", \.saturatedFats, .fatSaturated),
        Row("Trans Fat", \.transFats, .fatTrans)
    ]

    private static let proteins: [Row] = [
        Row("Cysteine", \.cysteine, .cysteine),
        Row("Histidine", \.histidine, .histidine),
        Row("Isoleucine", \.isoleucine, .isoleucine),
        Row("Leucine", \.leucine, .leucine),
        Row("Lysine", \.lysine, .lysine),
        Row("Methionine", \.methionine, .methionine),
        Row("Phenylalanine", \.phenylalinine, .phenylalanine),
        Row("Threonine", \.threonine, .threonine),
        Row("Tryptophan", \.tryptophan, .tryptophan),
        Row("Tyrosine", \.tyrosine, .tyrosine),
        Row("Valine", \.valine, .valine)
    ]

    private static let vitamins: [Row] = [
        Row("B1, Thiamine", \.b1Thiamine, .thiaminMg),
        Row("B2, Riboflavin", \.b2Riboflavin, .riboflavinMg),
        Row("B3, Niacin", \.b3Niacin, .niacinMg),
        Row("B5, Pantothenic Acid", \.b5PantothenicAcid, .pantothenicAcidMg),
        Row("B6, Pyridoxine", \.b6Pyridoxine, .vitaminB6Mg),
        Row("B12, Cobalamin", \.b12Cobalamin, .vitaminB12Mcg),
        Row("Folate", \.folate, .folateMcg),
        Row("Vitamin A", \.vitaminA, .vitaminAMcg),
        Row("Vitamin C", \.vitaminC, .vitaminCMg),
        Row("Vitamin D", \.vitaminD, .vitaminDMcg),
        Row("Vitamin E", \.vitaminE, .vitaminEMg),
        Row("Vitamin K", \.vitaminK, .vitaminKMcg)
    ]

    private static let minerals: [Row] = [
        Row("Calcium", \.calcium, .calciumMg),
        Row("Copper", \.copper, .copperMg),
        Row("Iron", \.iron, .ironMg),
        Row("Magnesium", \.magnesium, .magnesiumMg),
        Row("Manganese", \.manganese, .manganeseMg),
        Row("Phosphorus", \.phosphorus, .phosphorusMg),
        Row("Potassium", \.potassium, .potassiumMg),
        Row("Selenium", \.selenium, .seleniumMcg),
        Row("Sodium", \.sodium, .sodiumMg),
        Row("Zinc", \.zinc, .zincMg)
    ]

    private static let other: [Row] = [
        Row("Alcohol", \.alcohol, .alcohol),
        Row("Caffeine", \.caffeine, .caffeineMg),
        Row("Cholesterol", \.cholesterol, .cholesterolMg),
        Row("Water", \.water, .water)
    ]
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodDefinitionDelegate(
        nutritionDefinitionOption: .serving,
        image: nil,
        name: "Sample Food",
        brandName: nil,
        barcode: nil,
        imageFront: nil,
        nutritionImage: nil,
        servingWeight: nil,
        portionSize: 1,
        portionName: "portion",
        portionWeight: nil,
        weightPortionSize: nil,
        weightPortionName: nil,
        portionVolume: nil,
        volumePortionSize: nil,
        volumePortionName: nil
    )
    
    return RouterView { router in
        builder.foodDefinitionView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func foodDefinitionView(router: AnyRouter, delegate: FoodDefinitionDelegate) -> some View {
        FoodDefinitionView(
            presenter: FoodDefinitionPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showFoodDefinitionView(delegate: FoodDefinitionDelegate) {
        router.showScreen(.push) { router in
            builder.foodDefinitionView(router: router, delegate: delegate)
        }
    }
    
}
