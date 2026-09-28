import SwiftUI

protocol FoodItem {

    var imageURL: String? { get }
    var name: String { get }
    var calories: Double? { get }
    var carbs: Double? { get }
    var protein: Double? { get }
    var fats: Double? { get }
    var portionQuantityCalculated: Double? { get }
    var portionNameCalculated: String? { get }
}

struct FoodLibraryPickerRowDelegate<T: FoodItem> {

    let item: T
    let onAdd: (() -> Void)?
    let onQuickAdd: (() -> Void)?
    var showImage: Bool
    var showCalories: Bool
    var showMacros: Bool
    var showPortion: Bool

    init(
        item: T,
        onAdd: (() -> Void)? = nil,
        onQuickAdd: (() -> Void)? = nil,
        showImage: Bool = true,
        showCalories: Bool = true,
        showMacros: Bool = true,
        showPortion: Bool = true
    ) {
        self.item = item
        self.onAdd = onAdd
        self.onQuickAdd = onQuickAdd
        self.showImage = showImage
        self.showCalories = showCalories
        self.showMacros = showMacros
        self.showPortion = showPortion
    }

    var eventParameters: [String: Any]? {
        nil
    }

    /// The row's second line: whichever of calories, macros and portion the logger settings show,
    /// separated by middle dots. Nil when all three are off.
    var detail: String? {
        var parts: [String] = []
        if showCalories {
            parts.append(Format.kcal(item.calories ?? 0))
        }
        if showMacros {
            parts.append(String(localized: "\(Format.grams(item.protein ?? 0)) P"))
            parts.append(String(localized: "\(Format.grams(item.fats ?? 0)) F"))
            parts.append(String(localized: "\(Format.grams(item.carbs ?? 0)) C"))
        }
        if showPortion, let quantity = item.portionQuantityCalculated, let name = item.portionNameCalculated {
            parts.append("\(quantity.formatted()) \(name)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct FoodLibraryPickerRowView<T: FoodItem>: View {

    let delegate: FoodLibraryPickerRowDelegate<T>

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button {
                delegate.onAdd?()
            } label: {
                row
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Button {
                delegate.onQuickAdd?()
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Quick add \(delegate.item.name)")
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    @ViewBuilder
    private var row: some View {
        if delegate.showImage {
            ListRow(title: delegate.item.name, subtitle: delegate.detail, imageName: delegate.item.imageURL)
        } else {
            ListRow(title: delegate.item.name, subtitle: delegate.detail)
        }
    }
}

#Preview {
    List {
        ForEach(FoodModel.mocks) { food in
            let delegate = FoodLibraryPickerRowDelegate<FoodModel>(
                item: food,
                onAdd: { print("On Add") },
                onQuickAdd: { print("On Quick Add") }
            )

            return FoodLibraryPickerRowView(delegate: delegate)
        }
    }
}
