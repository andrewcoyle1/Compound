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
    /// What the row's calories and macros are multiplied by, so they describe `rowPortionText`.
    var rowNutrientScale: Double { get }
    /// The amount the row's figures are for, e.g. "0.5 cup" or "100 g".
    var rowPortionText: String? { get }
}

extension FoodItem {

    /// A recipe's figures are already per serving.
    var rowNutrientScale: Double { 1 }

    var rowPortionText: String? {
        guard let quantity = portionQuantityCalculated, let name = portionNameCalculated else { return nil }
        return "\(quantity.formatted()) \(name)"
    }
}

struct FoodLibraryPickerRowDelegate<T: FoodItem> {

    let item: T
    let onAdd: (() -> Void)?
    let onQuickAdd: (() -> Void)?
    var showImage: Bool
    var showCalories: Bool
    var showMacros: Bool
    var showPortion: Bool
    /// How many times this item is already on the plate. Above zero, the quick-add "+" becomes a
    /// checkmark with this count, so a second tap doesn't look like it did nothing.
    var addedCount: Int

    init(
        item: T,
        onAdd: (() -> Void)? = nil,
        onQuickAdd: (() -> Void)? = nil,
        showImage: Bool = true,
        showCalories: Bool = true,
        showMacros: Bool = true,
        showPortion: Bool = true,
        addedCount: Int = 0
    ) {
        self.item = item
        self.onAdd = onAdd
        self.onQuickAdd = onQuickAdd
        self.showImage = showImage
        self.showCalories = showCalories
        self.showMacros = showMacros
        self.showPortion = showPortion
        self.addedCount = addedCount
    }

    var eventParameters: [String: Any]? {
        nil
    }

    /// The row's second line: whichever of calories, macros and portion the logger settings show,
    /// separated by middle dots. Nil when all three are off.
    var detail: String? {
        var parts: [String] = []
        let scale = item.rowNutrientScale
        if showCalories {
            parts.append(Format.kcal((item.calories ?? 0) * scale))
        }
        if showMacros {
            parts.append(String(localized: "\(Format.grams((item.protein ?? 0) * scale)) P"))
            parts.append(String(localized: "\(Format.grams((item.fats ?? 0) * scale)) F"))
            parts.append(String(localized: "\(Format.grams((item.carbs ?? 0) * scale)) C"))
        }
        if showPortion, let portion = item.rowPortionText {
            parts.append(portion)
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
                if delegate.addedCount > 0 {
                    Label("\(delegate.addedCount)", systemImage: "checkmark")
                } else {
                    Image(systemName: Symbol.add)
                }
            }
            .accessibilityLabel(
                delegate.addedCount > 0
                    ? "\(delegate.addedCount) \(delegate.item.name) on plate"
                    : "Quick add \(delegate.item.name)"
            )
            .buttonStyle(.bordered)
            .buttonBorderShape(delegate.addedCount > 0 ? .capsule : .circle)
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
