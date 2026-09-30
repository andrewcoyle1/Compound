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
                foodItemSearch(FoodItemSearchDelegate(
                    onFoodSelected: { food in
                        presenter.navToIngredientAmount(food, onPick: delegate.onPick)
                    },
                    mealItems: delegate.items
                ))
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
        // A count, not a control: as a toolbar item it drew as a greyed-out button.
        .navigationSubtitle(Text("\(delegate.items.wrappedValue.count) on plate"))
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

    /// One chip per mode, in the pinned bar's `BarChip` style that the exercise picker's filter
    /// bar uses. They were content `Chip`s, a third the height of every other chip bar's.
    private var modeChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        ForEach(NutritionPickerMode.allCases) { mode in
                            Button {
                                presenter.onModePressed(mode)
                            } label: {
                                BarChip(title: mode.title, systemImage: mode.systemName, isActive: mode == presenter.mode)
                            }
                            .buttonStyle(.plain)
                            .id(mode)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .scrollIndicators(.hidden)
            // The bar is rebuilt with each mode's content and starts from the leading edge again,
            // which left a chosen mode past the edge (Library, Describe) scrolled out of sight.
            .onAppear { proxy.scrollTo(presenter.mode, anchor: .center) }
            .onChange(of: presenter.mode) { _, mode in
                withReducedMotionAnimation(.standard) { proxy.scrollTo(mode, anchor: .center) }
            }
        }
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
