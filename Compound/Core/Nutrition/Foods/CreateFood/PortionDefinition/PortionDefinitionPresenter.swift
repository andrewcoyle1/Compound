import SwiftUI

@Observable
@MainActor
class PortionDefinitionPresenter {
    
    private let interactor: PortionDefinitionInteractor
    private let router: PortionDefinitionRouter
    
    var nutritionDefinitionOption: NutritionDefinitionOption = .serving
    
    var preferredWeightUnit: NutritionWeightUnit = .grams
    var preferredVolumeUnit: NutritionVolumeUnit = .millileter
    
    var servingWeight: Double?
    var portionSize: Double? = 1
    var portionName: String = "portion"
    
    var portionWeight: Double?
    var weightPortionSize: Double?
    var weightPortionName: String = ""
    
    var portionVolume: Double?
    var volumePortionSize: Double?
    var volumePortionName: String = ""
    
    var canSave: Bool {
        switch nutritionDefinitionOption {
        case .serving:
            return (portionSize != nil && portionSize != 0 && !portionName.isEmpty)
        default:
            return true
        }
    }
    
    init(interactor: PortionDefinitionInteractor, router: PortionDefinitionRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: PortionDefinitionDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: PortionDefinitionDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onNextPressed(delegate: PortionDefinitionDelegate) {
        if case .serving = nutritionDefinitionOption {
            guard portionSize != nil, portionSize != 0, !portionName.isEmpty else { return }
        }

        // The three branches used to repeat the same eight shared arguments. Build the shared
        // delegate once, then fill in only the fields the chosen option actually carries.
        var foodDelegate = FoodDefinitionDelegate(
            mealItems: delegate.mealItems,
            nutritionDefinitionOption: nutritionDefinitionOption,
            image: delegate.image,
            name: delegate.name,
            brandName: delegate.brandName,
            barcode: delegate.barcode,
            imageFront: delegate.productFront,
            nutritionImage: delegate.nutritionPhoto
        )

        switch nutritionDefinitionOption {
        case .serving:
            foodDelegate.servingWeight = servingWeight
            foodDelegate.portionSize = portionSize
            foodDelegate.portionName = portionName
        case .standardMass:
            foodDelegate.portionWeight = portionWeight
            foodDelegate.weightPortionSize = weightPortionSize
            foodDelegate.weightPortionName = weightPortionName
        case .standardVolume:
            foodDelegate.portionVolume = portionVolume
            foodDelegate.volumePortionSize = volumePortionSize
            foodDelegate.volumePortionName = volumePortionName
        }

        router.showFoodDefinitionView(delegate: foodDelegate)
    }
}

extension PortionDefinitionPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: PortionDefinitionDelegate)
        case onDisappear(delegate: PortionDefinitionDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "PortionDefinitionView_Appear"
            case .onDisappear:              return "PortionDefinitionView_Disappear"
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
