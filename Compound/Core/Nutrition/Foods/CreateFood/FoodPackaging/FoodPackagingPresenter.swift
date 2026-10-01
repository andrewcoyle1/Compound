import SwiftUI
import PhotosUI

@Observable
@MainActor
class FoodPackagingPresenter {
    
    private let interactor: FoodPackagingInteractor
    private let router: FoodPackagingRouter
    
    var selectedFrontPhotoItem: PhotosPickerItem?
    var selectedRearPhotoItem: PhotosPickerItem?
    var isFrontImagePickerPresented: Bool = false
    var isRearImagePickerPresented: Bool = false
    var selectedFrontImageData: Data?
    var selectedNutritionImageData: Data?

    var imageFront: PlatformImage?
    var imageNutrition: PlatformImage?
    
    init(interactor: FoodPackagingInteractor, router: FoodPackagingRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onFrontImageSelectorPressed() {
        isFrontImagePickerPresented = true
    }

    func onRearImageSelectorPressed() {
        isRearImagePickerPresented = true
    }

    func onViewAppear(delegate: FoodPackagingDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: FoodPackagingDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onNextPressed(delegate: FoodPackagingDelegate) {
        #if canImport(UIKit)
        let frontImage = selectedFrontImageData.flatMap { UIImage(data: $0) }
        let nutritionImage = selectedNutritionImageData.flatMap { UIImage(data: $0) }
        #elseif canImport(AppKit)
        let frontImage = selectedFrontImageData.flatMap { NSImage(data: $0) }
        let nutritionImage = selectedNutritionImageData.flatMap { NSImage(data: $0) }
        #endif
        router.showPortionDefinitionView(
            delegate: PortionDefinitionDelegate(
                mealItems: delegate.mealItems,
                name: delegate.name,
                brandName: delegate.brandName,
                barcode: delegate.barcode,
                image: delegate.image,
                productFront: frontImage,
                nutritionPhoto: nutritionImage
            )
        )
    }
}

extension FoodPackagingPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: FoodPackagingDelegate)
        case onDisappear(delegate: FoodPackagingDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "FoodPackagingView_Appear"
            case .onDisappear:              return "FoodPackagingView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
//            default:
//                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
