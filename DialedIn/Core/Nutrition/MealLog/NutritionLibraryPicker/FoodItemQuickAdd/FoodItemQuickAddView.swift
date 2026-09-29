import SwiftUI

struct FoodItemQuickAddDelegate {
    /// Hands the composed item back to the picker, the same way every other picker mode does.
    var onPick: (MealItemModel) -> Void = { _ in }

    var eventParameters: [String: Any]? {
        nil
    }
}

struct FoodItemQuickAddView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State var presenter: FoodItemQuickAddPresenter
    let delegate: FoodItemQuickAddDelegate
    
    var body: some View {
        List {
            nameSection
            energySection
            macrosSection
            alcoholSection
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                CallToActionButton {
                    presenter.onQuickAddPressed(delegate: delegate)
                } label: {
                    Text("Quick Add")
                }
                .disabled(!presenter.canSubmit)
                CallToActionButton(isPrimaryAction: false) {
                    presenter.onLogFoodPressed()
                } label: {
                    Text("Log Food")
                }
                .disabled(!presenter.canSubmit)
            }
            .padding(.bottom)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    private var nameSection: some View {
        Section {
            TextField("", text: $presenter.quickAddName)
                .removeListRowFormatting()
                .padding()
                .background(colorScheme.backgroundPrimary, in: .containerRelative)
        } header: {
            Text("Name")
        }

    }
    
    private var energySection: some View {
        Section {
            TextFieldwUnitPicker<EnergyUnit>(
                value: $presenter.energyValue,
                unit: $presenter.unitOfEnergy
            )
                .removeListRowFormatting()
                .padding()
                .background(colorScheme.backgroundPrimary, in: .containerRelative)
        } header: {
            Text("Energy")
        } footer: {
            Text("Macro sum is \(presenter.computedTotalEnergy) \(presenter.unitOfEnergy.name)")
        }
    }
    
    private var macrosSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()]) {
                VStack(alignment: .leading) {
                    Text("Protein")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                    TextFieldwUnitPicker(
                        value: $presenter.proteinValue,
                        unit: $presenter.weightUnit
                    )
                    .padding(12)
                    .background(colorScheme.backgroundPrimary, in: .containerRelative)
                    
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading) {
                    Text("Carbs")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                    TextFieldwUnitPicker(
                        value: $presenter.carbsValue,
                        unit: $presenter.weightUnit
                    )
                    .padding(12)
                    .background(colorScheme.backgroundPrimary, in: .containerRelative)
                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading) {
                    Text("Fats")
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading)
                    TextFieldwUnitPicker(
                        value: $presenter.fatsValue,
                        unit: $presenter.weightUnit
                    )
                    .padding(12)
                    .background(colorScheme.backgroundPrimary, in: .containerRelative)

                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .removeListRowFormatting()
        }
    }
    
    private var alcoholSection: some View {
        Section {
            TextFieldwUnitPicker(
                value: $presenter.alcoholValue,
                unit: $presenter.weightUnit
            )
                .removeListRowFormatting()
                .padding()
                .background(colorScheme.backgroundPrimary, in: .containerRelative)
        } header: {
            Text("Alcohol")
        }
    }
}

enum NutritionWeightUnit: String, PickableUnit {
    
    var id: String { self.rawValue }
    case grams
    case ounces
    
    var name: String {
        switch self {
        case .grams: return "grams"
        case .ounces: return "ounces"
        }
    }
    
    var acronym: String {
        switch self {
        case .grams: return "g"
        case .ounces: return "oz"
        }
    }
}

enum NutritionVolumeUnit: String, PickableUnit {
    
    var id: String { self.rawValue }
    case millileter
    case flOunce
    
    var name: String {
        switch self {
        case .millileter: return "milliliters"
        case .flOunce: return String(localized: "fluid ounces")
        }
    }
    
    var acronym: String {
        switch self {
        case .millileter: return "ml"
        case .flOunce: return "fl oz"
        }
    }
}

enum EnergyUnit: String, PickableUnit {
    
    var id: String { self.rawValue }
    case kcal
    case kjoule
    
    var name: String {
        switch self {
        case .kcal: return String(localized: "Kilocalories")
        case .kjoule: return String(localized: "Kilojoules")
        }
    }
    
    var acronym: String {
        switch self {
        case .kcal: return "kcal"
        case .kjoule: return "kj"
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodItemQuickAddDelegate()
    
    return RouterView { router in
        builder.foodItemQuickAddView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func foodItemQuickAddView(router: AnyRouter, delegate: FoodItemQuickAddDelegate) -> some View {
        FoodItemQuickAddView(
            presenter: FoodItemQuickAddPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}
