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
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State var presenter: FoodDefinitionPresenter
    let delegate: FoodDefinitionDelegate
    
    var body: some View {
        List {
            Section {
                Picker("", selection: $presenter.foodDefinitionOption) {
                    ForEach(FoodDefinitionOption.allCases, id: \.self) { option in
                        Text(option.name).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .removeListRowFormatting()
            } header: {
                Text("What will you be entering nutrition information for?")
                    .font(.subheadline)
            }
            
            switch presenter.foodDefinitionOption {
            case .usLabel: Text("US Label")
            case .nonUsLabel: Text("Non-US Label")
            case .foodDetail: foodDetailSection
            }
        }
        .navigationTitle("Create Food")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                CallToActionButton(isPrimaryAction: true) {
                    presenter.onCreateAndAddPressed(delegate: delegate)
                } label: {
                    Text("Create & Add")
                }
                CallToActionButton(isPrimaryAction: false) {
                    presenter.onCreatePressed(delegate: delegate)
                } label: {
                    Text("Create")
                }
            }
            .padding(.bottom)
        }
    }
    
    @ViewBuilder
    private var foodDetailSection: some View {
        Section {
            caloriesAndMacrosSection
            carbsSection
            fatsSection
            proteinSection
            vitaminsSection
            mineralsSection
            otherSection
        } header: {
            VStack(alignment: .leading) {
                Text("Provide nutrition facts for \(delegate.nutritionDefinitionOption.name.lowercased())")
                if let portionSize = delegate.portionSize, let portionName = delegate.portionName {
                    Text("Serving Size: \(portionSize) \(portionName)")
                        .font(.caption)
                }
            }
        }
    }
    
    private var caloriesAndMacrosSection: some View {
        DisclosureGroup(isExpanded: $presenter.isShowingMacros) {
            Group {
                LabeledTextFieldWithUnitPicker<EnergyUnit>(
                    label: "Energy",
                    value: $presenter.energy,
                    unit: $presenter.energyUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Protein",
                    value: $presenter.protein,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Carbs",
                    value: $presenter.carbs,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Fats",
                    value: $presenter.fats,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Calories & Macros")
                .font(.headline)
        }
    }
    
    private var carbsSection: some View {
        DisclosureGroup {
            Group {
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Fiber",
                    value: $presenter.fiber,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Starch",
                    value: $presenter.starch,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Sugars",
                    value: $presenter.sugars,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Sugars (Added)",
                    value: $presenter.addedSugars,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Carbs Breakdown")
                .font(.headline)
        }
    }
    
    private var fatsSection: some View {
        DisclosureGroup {
            Group {
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Monounsaturated Fat",
                    value: $presenter.monounsaturatedFats,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Polyunsaturated Fat",
                    value: $presenter.polyunsaturatedFats,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Omega-3",
                    value: $presenter.omega3,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Omega-3 ALA",
                    value: $presenter.omega3Ala,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Omega-3 DHA",
                    value: $presenter.omega3Dha,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Omega-3 EPA",
                    value: $presenter.omega3Epa,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Omega-6",
                    value: $presenter.omega6,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Saturated Fat",
                    value: $presenter.saturatedFats,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Trans Fat",
                    value: $presenter.transFats,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Fats Breakdown")
                .font(.headline)
        }
    }
    
    private var proteinSection: some View {
        DisclosureGroup {
            Group {
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Cysteine",
                    value: $presenter.cysteine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Histidine",
                    value: $presenter.histidine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Isoleucine",
                    value: $presenter.isoleucine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Leucine",
                    value: $presenter.leucine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Lysine",
                    value: $presenter.lysine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Methionine",
                    value: $presenter.methionine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Phenylalanine",
                    value: $presenter.phenylalinine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Threonine",
                    value: $presenter.threonine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Tryptophan",
                    value: $presenter.tryptophan,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Tyrosine",
                    value: $presenter.tyrosine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Valine",
                    value: $presenter.valine,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Protein Breakdown")
                .font(.headline)
        }
    }
    
    private var vitaminsSection: some View {
        DisclosureGroup {
            Group {
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "B1, Thiamine",
                    value: $presenter.b1Thiamine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "B2, Riboflavin",
                    value: $presenter.b2Riboflavin,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "B3, Niacin",
                    value: $presenter.b3Niacin,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "B5, Pantothenic Acid",
                    value: $presenter.b5PantothenicAcid,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "B6, Pyridoxine",
                    value: $presenter.b6Pyridoxine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "B12, Cobalamin",
                    value: $presenter.b12Cobalamin,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Folate",
                    value: $presenter.folate,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnitPicker<NutritionWeightUnit>(
                    label: "Vitamin A",
                    value: $presenter.vitaminA,
                    unit: $presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Vitamin C",
                    value: $presenter.vitaminC,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnitPicker<NutritionWeightUnit>(
                    label: "Vitamin D",
                    value: $presenter.vitaminD,
                    unit: $presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnitPicker<NutritionWeightUnit>(
                    label: "Vitamin E",
                    value: $presenter.vitaminE,
                    unit: $presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Vitamin K",
                    value: $presenter.vitaminK,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Vitamins Breakdown")
                .font(.headline)
        }
    }
    
    private var mineralsSection: some View {
        DisclosureGroup {
            Group {
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Calcium",
                    value: $presenter.calcium,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Copper",
                    value: $presenter.copper,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Iron",
                    value: $presenter.iron,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Magnesium",
                    value: $presenter.magnesium,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Manganese",
                    value: $presenter.manganese,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Phosphorus",
                    value: $presenter.phosphorus,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Potassium",
                    value: $presenter.potassium,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Selenium",
                    value: $presenter.selenium,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnitPicker<NutritionWeightUnit>(
                    label: "Sodium",
                    value: $presenter.sodium,
                    unit: $presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Zinc",
                    value: $presenter.zinc,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Minerals Breakdown")
                .font(.headline)
        }
    }
    private var otherSection: some View {
        DisclosureGroup {
            Group {
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Alcohol",
                    value: $presenter.alcohol,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Caffeine",
                    value: $presenter.caffeine,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Cholesterol",
                    value: $presenter.cholesterol,
                    unit: presenter.nutritionWeightUnit)
                LabeledTextFieldWithUnit<NutritionWeightUnit>(
                    label: "Water",
                    value: $presenter.water,
                    unit: presenter.nutritionWeightUnit)
            }
            .padding(.bottom)
            .listRowSeparator(.hidden)
            .listRowInsets(.vertical, 0)
            .listRowInsets(.leading, 0)
        } label: {
            Text("Other")
                .font(.headline)
        }
    }
}

enum FoodDefinitionOption: CaseIterable {
    case usLabel
    case nonUsLabel// (preferredWeightUnit: NutritionWeightUnit)
    case foodDetail
    
    var name: String {
        switch self {
        case .usLabel:
            return String(localized: "US Label")
        case .nonUsLabel:
            return String(localized: "Non-US Label")
        case .foodDetail:
            return String(localized: "Food Detail")
        }
    }
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
