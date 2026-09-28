//
//  NutritionLibraryPickerView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 13/10/2025.
//

import SwiftUI

struct NutritionLibraryPickerDelegate {
    var items: Binding<[MealItemModel]>
    var onPick: (MealItemModel) -> Void
}

struct NutritionLibraryPickerView<
    FoodItemSearch: View,
    BarcodeScanner: View,
    FoodPhotoScanner: View,
    FoodQuickAdd: View,
    FoodLibrary: View,
    MealDescribe: View
>: View {

    @State var presenter: NutritionLibraryPickerPresenter

    var delegate: NutritionLibraryPickerDelegate

    @ViewBuilder var barcodeScanner: (BarcodeScannerDelegate) -> BarcodeScanner
    @ViewBuilder var foodItemSearch: (FoodItemSearchDelegate) -> FoodItemSearch
    @ViewBuilder var foodPhotoScanner: (FoodPhotoScannerDelegate) -> FoodPhotoScanner
    @ViewBuilder var foodQuickAdd: (FoodItemQuickAddDelegate) -> FoodQuickAdd
    @ViewBuilder var foodLibrary: (FoodLibraryDelegate) -> FoodLibrary
    @ViewBuilder var mealDescribe: (MealDescribeDelegate) -> MealDescribe

    var body: some View {
        Group {
            switch presenter.mode {
            case .barcode:
                barcodeScanner(BarcodeScannerDelegate(onFoodFound: { food in
                    presenter.navToIngredientAmount(food, onPick: delegate.onPick)
                }))
            case .search:
                foodItemSearch(FoodItemSearchDelegate(onFoodSelected: { food in
                    presenter.navToIngredientAmount(food, onPick: delegate.onPick)
                }))
            case .aiScanner:
                foodPhotoScanner(FoodPhotoScannerDelegate(onPick: delegate.onPick))
            case .quickAdd:
                foodQuickAdd(FoodItemQuickAddDelegate(onPick: delegate.onPick))
            case .library:
                foodLibrary(
                    FoodLibraryDelegate(
                        mealItems: delegate.items,
                        onItemPick: { item in
                            delegate.items.wrappedValue.append(item)
                        }
                    )
                )
            case .describe:
                mealDescribe(MealDescribeDelegate(onPick: delegate.onPick))
            }
        }
        .navigationTitle("Add Item")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .top) {
            modeChips
        }
        .toolbar {
            // Picks land on the plate as they are made, so there is nothing to confirm or cancel:
            // closing is the one honest action.
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.dismissScreen()
                }
            }
        }
    }

    /// One chip per mode. Each is a plain button around a `Chip`, which carries the selected look
    /// and the `.isSelected` trait.
    private var modeChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                ForEach(NutritionPickerMode.allCases) { mode in
                    Button {
                        presenter.onModePressed(mode)
                    } label: {
                        Chip(mode.title, systemImage: mode.systemName, isSelected: mode == presenter.mode)
                            .chipTapTarget()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

}

extension CoreBuilder {
    func nutritionLibraryPickerView(router: AnyRouter, delegate: NutritionLibraryPickerDelegate) -> some View {
        NutritionLibraryPickerView(
            presenter: NutritionLibraryPickerPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate,
            barcodeScanner: { scannerDelegate in
                self.barcodeScannerView(router: router, delegate: scannerDelegate)
            },
            foodItemSearch: { searchDelegate in
                self.foodItemSearchView(router: router, delegate: searchDelegate)
            },
            foodPhotoScanner: { photoDelegate in
                self.foodPhotoScannerView(router: router, delegate: photoDelegate)
            },
            foodQuickAdd: { quickAddDelegate in
                self.foodItemQuickAddView(router: router, delegate: quickAddDelegate)
            },
            foodLibrary: { foodLibraryDelegate in
                self.foodLibraryView(router: router, delegate: foodLibraryDelegate)
            },
            mealDescribe: { mealDescribeDelegate in
                self.mealDescribeView(router: router, delegate: mealDescribeDelegate)
            }
        )
    }
}

extension CoreRouter {
    func showNutritionLibraryPickerView(delegate: NutritionLibraryPickerDelegate) {
        router.showScreen(.sheet) { router in
            builder.nutritionLibraryPickerView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    @Previewable @State var items: [MealItemModel] = MealItemModel.mocks
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = NutritionLibraryPickerDelegate(
        items: $items,
        onPick: { item in
            print(item.displayName)
        }
    )
    RouterView { router in
        builder.nutritionLibraryPickerView(router: router, delegate: delegate)
    }
    
}
