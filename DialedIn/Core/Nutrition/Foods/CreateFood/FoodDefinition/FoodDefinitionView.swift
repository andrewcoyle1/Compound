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
        List {
            Section {
                Picker("Nutrition information", selection: $presenter.foodDefinitionOption) {
                    ForEach(FoodDefinitionOption.allCases, id: \.self) { option in
                        Text(option.name).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .removeListRowFormatting()
            } header: {
                Text("What will you be entering nutrition information for?")
            }

            switch presenter.foodDefinitionOption {
            case .usLabel: Text("US Label")
            case .nonUsLabel: Text("Non-US Label")
            case .foodDetail: foodDetailSections
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
        .bottomCTA {
            if presenter.canAddToPlate(delegate: delegate) {
                CallToActionButton {
                    presenter.onCreateAndAddPressed(delegate: delegate)
                } label: {
                    Text("Create & Add")
                }
            }
            CallToActionButton(isPrimaryAction: !presenter.canAddToPlate(delegate: delegate)) {
                presenter.onCreatePressed(delegate: delegate)
            } label: {
                Text("Create")
            }
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
            if row.picksUnit {
                NumberField(
                    "0",
                    value: $presenter[dynamicMember: row.value],
                    units: Array(NutritionWeightUnit.allCases),
                    selection: $presenter.nutritionWeightUnit,
                    label: row.label
                )
            } else {
                NumberField("0", value: $presenter[dynamicMember: row.value], unit: presenter.nutritionWeightUnit.acronym, label: row.label)
            }
        }
    }

    // MARK: - Fields

    /// A nutrient field: its label, the presenter property it edits, and whether it offers the
    /// unit picker (which, as before, sets the unit every weight field shares).
    private struct Row {
        let label: String
        let value: ReferenceWritableKeyPath<FoodDefinitionPresenter, Double?>
        var picksUnit: Bool = false

        init(_ label: String.LocalizationValue, _ value: ReferenceWritableKeyPath<FoodDefinitionPresenter, Double?>, picksUnit: Bool = false) {
            self.label = String(localized: label)
            self.value = value
            self.picksUnit = picksUnit
        }
    }

    private static let macros: [Row] = [
        Row("Protein", \.protein),
        Row("Carbs", \.carbs),
        Row("Fats", \.fats)
    ]

    private static let carbs: [Row] = [
        Row("Fiber", \.fiber),
        Row("Starch", \.starch),
        Row("Sugars", \.sugars),
        Row("Sugars (Added)", \.addedSugars)
    ]

    private static let fats: [Row] = [
        Row("Monounsaturated Fat", \.monounsaturatedFats),
        Row("Polyunsaturated Fat", \.polyunsaturatedFats),
        Row("Omega-3", \.omega3),
        Row("Omega-3 ALA", \.omega3Ala),
        Row("Omega-3 DHA", \.omega3Dha),
        Row("Omega-3 EPA", \.omega3Epa),
        Row("Omega-6", \.omega6),
        Row("Saturated Fat", \.saturatedFats),
        Row("Trans Fat", \.transFats)
    ]

    private static let proteins: [Row] = [
        Row("Cysteine", \.cysteine),
        Row("Histidine", \.histidine),
        Row("Isoleucine", \.isoleucine),
        Row("Leucine", \.leucine),
        Row("Lysine", \.lysine),
        Row("Methionine", \.methionine),
        Row("Phenylalanine", \.phenylalinine),
        Row("Threonine", \.threonine),
        Row("Tryptophan", \.tryptophan),
        Row("Tyrosine", \.tyrosine),
        Row("Valine", \.valine)
    ]

    private static let vitamins: [Row] = [
        Row("B1, Thiamine", \.b1Thiamine),
        Row("B2, Riboflavin", \.b2Riboflavin),
        Row("B3, Niacin", \.b3Niacin),
        Row("B5, Pantothenic Acid", \.b5PantothenicAcid),
        Row("B6, Pyridoxine", \.b6Pyridoxine),
        Row("B12, Cobalamin", \.b12Cobalamin),
        Row("Folate", \.folate),
        Row("Vitamin A", \.vitaminA, picksUnit: true),
        Row("Vitamin C", \.vitaminC),
        Row("Vitamin D", \.vitaminD, picksUnit: true),
        Row("Vitamin E", \.vitaminE, picksUnit: true),
        Row("Vitamin K", \.vitaminK)
    ]

    private static let minerals: [Row] = [
        Row("Calcium", \.calcium),
        Row("Copper", \.copper),
        Row("Iron", \.iron),
        Row("Magnesium", \.magnesium),
        Row("Manganese", \.manganese),
        Row("Phosphorus", \.phosphorus),
        Row("Potassium", \.potassium),
        Row("Selenium", \.selenium),
        Row("Sodium", \.sodium, picksUnit: true),
        Row("Zinc", \.zinc)
    ]

    private static let other: [Row] = [
        Row("Alcohol", \.alcohol),
        Row("Caffeine", \.caffeine),
        Row("Cholesterol", \.cholesterol),
        Row("Water", \.water)
    ]
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
