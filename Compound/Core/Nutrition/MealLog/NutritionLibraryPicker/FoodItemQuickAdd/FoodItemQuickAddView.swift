import SwiftUI

struct FoodItemQuickAddDelegate {
    /// Hands the composed item back to the picker, the same way every other picker mode does.
    var onPick: (MealItemModel) -> Void = { _ in }
    /// The plate's Log: adds these macros and logs the meal in one step.
    var onLog: (() -> Void)?

    var eventParameters: [String: Any]? {
        nil
    }
}

struct FoodItemQuickAddView: View {

    @State var presenter: FoodItemQuickAddPresenter
    let delegate: FoodItemQuickAddDelegate

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $presenter.quickAddName)
            }
            Section {
                NumberField("0", value: $presenter.energyValue, units: Array(EnergyUnit.allCases), selection: $presenter.unitOfEnergy, label: String(localized: "Energy"))
            } footer: {
                Text("Macros add up to \(presenter.macroEnergyInSelectedUnit) \(presenter.unitOfEnergy.acronym)")
            }
            Section("Macros") {
                macroField("Protein", value: $presenter.proteinValue)
                macroField("Carbs", value: $presenter.carbsValue)
                macroField("Fats", value: $presenter.fatsValue)
                macroField("Alcohol", value: $presenter.alcoholValue)
            }
        }
        .bottomCTA {
            if let onLog = delegate.onLog {
                CallToActionButton {
                    presenter.onLogPressed(delegate: delegate, onLog: onLog)
                } label: {
                    Text("Log")
                }
                .disabled(!presenter.canSubmit)
            }
            CallToActionButton(isPrimaryAction: delegate.onLog == nil) {
                presenter.onQuickAddPressed(delegate: delegate)
            } label: {
                Text("Add to Plate")
            }
            .disabled(!presenter.canSubmit)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private func macroField(_ label: String.LocalizationValue, value: Binding<Double?>) -> some View {
        NumberField("0", value: value, units: Array(NutritionWeightUnit.allCases), selection: $presenter.weightUnit, label: String(localized: label))
    }
}

enum NutritionWeightUnit: String, PickableUnit {
    
    var id: String { self.rawValue }
    case grams
    case ounces
    
    var name: String {
        switch self {
        case .grams: return String(localized: "grams")
        case .ounces: return String(localized: "ounces")
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
        case .millileter: return String(localized: "milliliters")
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
        case .kjoule: return "kJ"
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
