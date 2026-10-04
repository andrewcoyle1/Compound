//
//  NutritionLibraryPickerView.swift
//  Compound
//
//  Created by Andrew Coyle on 13/10/2025.
//

import SwiftUI

struct NutritionLibraryPickerDelegate {
    /// The plate as it stands, read fresh each time.
    var plate: () -> [MealItemModel]
    var onPick: (MealItemModel) -> Void
    /// Logs the plate as it stands and closes the logger, from here or from an amount screen.
    var onLog: () -> Void = {}
    /// Called once the picker is on screen. A presentation the system drops never calls it, but
    /// is still reported to `onDidDismiss`.
    var onAppear: () -> Void = {}
    /// Called once the picker has gone, however it was closed.
    var onDidDismiss: () -> Void = {}
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
        // Read through the getter on every render. A Binding made once by Add Meal and stored in
        // this delegate kept answering with the plate as it was when the sheet opened, so the
        // count, the rows' checkmarks and Log never moved however much was added.
        let plate = delegate.plate()
        let plateBinding = Binding(get: delegate.plate, set: { _ in })
        Group {
            switch presenter.mode {
#if !targetEnvironment(macCatalyst)
            case .barcode:
                barcodeScanner(BarcodeScannerDelegate(onFoodFound: { food in
                    presenter.navToIngredientAmount(food, onPick: delegate.onPick, onLog: delegate.onLog)
                }))
#endif
            case .search:
                foodItemSearch(FoodItemSearchDelegate(
                    onFoodSelected: { food in
                        presenter.navToIngredientAmount(food, onPick: delegate.onPick, onLog: delegate.onLog)
                    },
                    onFoodQuickAdded: { food in
                        presenter.quickAdd(food, onPick: delegate.onPick)
                    },
                    onRecipeSelected: { recipe in
                        presenter.navToRecipeAmount(recipe, onPick: delegate.onPick, onLog: delegate.onLog)
                    },
                    onRecipeQuickAdded: { recipe in
                        presenter.quickAdd(recipe, onPick: delegate.onPick)
                    },
                    mealItems: plateBinding
                ))
            case .aiScanner:
                foodPhotoScanner(FoodPhotoScannerDelegate(onPick: delegate.onPick))
            case .quickAdd:
                foodQuickAdd(FoodItemQuickAddDelegate(onPick: delegate.onPick))
            case .library:
                foodLibrary(
                    FoodLibraryDelegate(
                        mealItems: plateBinding,
                        onItemPick: delegate.onPick,
                        onLog: delegate.onLog
                    )
                )
            case .describe:
                mealDescribe(MealDescribeDelegate(onPick: delegate.onPick))
            }
        }
        .onAppear { delegate.onAppear() }
        .navigationTitle("Add Item")
        // A count, not a control: as a toolbar item it drew as a greyed-out button.
        .navigationSubtitle(Text("\(plate.count) on plate"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .top) {
            modeChips
        }
        .toolbar {
            // Picks land on the plate as they are made, so there is nothing to cancel: Close goes
            // back to the plate to review it.
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    presenter.dismissScreen()
                }
            }
        }
        // Log logs the plate without going back to it first. Pinned to the bottom rather than in
        // the toolbar, which search hides while it is active — right when "+" has just added.
        .bottomCTA {
            if !plate.isEmpty {
                CallToActionButton {
                    delegate.onLog()
                } label: {
                    Text("Log")
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
#if !targetEnvironment(macCatalyst)
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
        #else
        NutritionLibraryPickerView(
            presenter: NutritionLibraryPickerPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate,
            barcodeScanner: { _ in
                EmptyView()
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

        #endif
    }
}

extension CoreRouter {
    func showNutritionLibraryPickerView(delegate: NutritionLibraryPickerDelegate) {
        router.showScreen(.sheet, onDidDismiss: delegate.onDidDismiss) { router in
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
        plate: { items },
        onPick: { item in
            print(item.displayName)
        }
    )
    RouterView { router in
        builder.nutritionLibraryPickerView(router: router, delegate: delegate)
    }
    
}
