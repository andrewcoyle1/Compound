import SwiftUI
import PhotosUI

struct FoodPackagingDelegate {
    let mealItems: Binding<[MealItemModel]>?
    let name: String
    let brandName: String?
    let barcode: String?
    let image: PlatformImage?
    
    init(
        mealItems: Binding<[MealItemModel]>? = nil,
        name: String,
        brandName: String?,
        barcode: String?,
        image: PlatformImage?
    ) {
        self.mealItems = mealItems
        self.name = name
        self.brandName = brandName
        self.barcode = barcode
        self.image = image
    }
    var eventParameters: [String: Any]? {
        nil
    }
}

struct FoodPackagingView: View {
    
    @State var presenter: FoodPackagingPresenter
    let delegate: FoodPackagingDelegate
    
    var body: some View {
        List {
            // Header-only by design, as a title above the three photo sections below — hence the
            // zero section spacing. Not an unfinished section.
            Section { } header: {
                Text("Photos of Food Packaging")
            }
            .listSectionSpacing(0)
            Section {
                Button {
                    presenter.onFrontImageSelectorPressed()
                } label: {
                    Image(systemName: Symbol.camera)
                        .iconSize(.medium)
                        .padding(Spacing.xl)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Add product front photo")
            } header: {
                Text("Product Front")
            }
            Section {
                Button {
                    presenter.onRearImageSelectorPressed()
                } label: {
                    Image(systemName: Symbol.camera)
                        .iconSize(.medium)
                        .padding(Spacing.xl)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Add nutrition facts photo")
            } header: {
                Text("Nutrition Facts")
            }
            Section {
                Text("How these photos are used.")
                    .font(.sectionTitle)
                Text(usageAttributedText)
            } footer: {
                HStack {
                    Text("Don't ask for product images again")
                    Spacer()
                    Image(systemName: "checkmark.circle")
                }
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
            CallToActionButton {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Next")
            }
        }
        .photosPicker(isPresented: $presenter.isFrontImagePickerPresented, selection: $presenter.selectedFrontPhotoItem, matching: .images)
        .photosPicker(isPresented: $presenter.isRearImagePickerPresented, selection: $presenter.selectedRearPhotoItem, matching: .images)
    }
    
    private var usageAttributedText: AttributedString {
        var attributed = AttributedString(" Photos for each new product submission and edit are used by Compound and Open Food Facts to increase the quality of the global barcode database. Photos will be made public, but won't be stored in your custom food.")
        if let range = attributed.range(of: "Open Food Facts") {
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodPackagingDelegate(
        name: "Coke Zero",
        brandName: "Coca Cola",
        barcode: "5000112633320",
        image: nil
    )
    
    return RouterView { router in
        builder.foodPackagingView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func foodPackagingView(router: AnyRouter, delegate: FoodPackagingDelegate) -> some View {
        FoodPackagingView(
            presenter: FoodPackagingPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showFoodPackagingView(delegate: FoodPackagingDelegate) {
        router.showScreen(.push) { router in
            builder.foodPackagingView(router: router, delegate: delegate)
        }
    }
    
}
