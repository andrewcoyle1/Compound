//
//  CreateFoodPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI
import PhotosUI

@Observable
@MainActor
class CreateFoodPresenter {

    private let interactor: CreateFoodInteractor
    private let router: CreateFoodRouter

    var selectedPhotoItem: PhotosPickerItem?
    var selectedImageData: Data?
    var isImagePickerPresented: Bool = false
    var name: String = ""
    var brandName: String?
    var barcode: String?
    var contributeToPublicDatabase: Bool = false

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(
        interactor: CreateFoodInteractor,
        router: CreateFoodRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onImageSelectorPressed() {
        // Show the image picker sheet for selecting a profile image
        interactor.trackEvent(event: Event.imageSelectorStart)
        isImagePickerPresented = true
    }

    func onImageSelectorChanged(_ newItem: PhotosPickerItem) async {
        do {
            if let data = try await newItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    selectedImageData = data
                    interactor.trackEvent(event: Event.imageSelectorSuccess)
                }
            } else {
                await MainActor.run {
                    interactor.trackEvent(event: Event.imageSelectorCancel)
                }
            }
        } catch {
            await MainActor.run {
                interactor.trackEvent(event: Event.imageSelectorFail(error: error))
            }
        }
    }
    
    func onCancelPressed() {
        router.dismissScreen()
    }
    
    func onNextPressed(delegate: CreateFoodDelegate) {
        // `PlatformImage` already resolves to UIImage or NSImage, so this no longer needs a
        // `#if canImport` pair duplicating each navigation call.
        let image = selectedImageData.flatMap { PlatformImage(data: $0) }

        if contributeToPublicDatabase {
            router.showFoodPackagingView(
                delegate: FoodPackagingDelegate(
                    mealItems: delegate.mealItems,
                    name: name,
                    brandName: brandName,
                    barcode: barcode,
                    image: image
                )
            )
        } else {
            router.showPortionDefinitionView(
                delegate: PortionDefinitionDelegate(
                    mealItems: delegate.mealItems,
                    name: name,
                    brandName: brandName,
                    barcode: barcode,
                    image: image,
                    productFront: nil,
                    nutritionPhoto: nil
                )
            )
        }
    }
    
    /// Explains the "Submit Foods to the Public Database?" toggle it sits beside. Shown inline rather
    /// than linked out: the app knows what the toggle does, and there is no hosted help to point at.
    func onLearnMorePressed() {
        interactor.trackEvent(event: Event.learnMorePressed)
        router.showSimpleAlert(
            title: String(localized: "Contributing Foods"),
            subtitle: """
            With this on, foods you create are shared to the public database so other people can find \
            and log them. Your name is not attached, and the food stays in your own library either way. \
            With it off, the food is yours alone.
            """
        )
    }
    
    func onBarcodeScannerPressed() {
        
        router.showBarcodeScannerView(
            delegate: BarcodeScannerDelegate(
                onBarcodeScanned: { barcode in
                    self.barcode = barcode
                }
            )
        )
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case imageSelectorStart
        case imageSelectorSuccess
        case imageSelectorCancel
        case imageSelectorFail(error: Error)
        case learnMorePressed

        var eventName: String {
            switch self {
            case .onAppear:                         return "CreateFoodView_Appear"
            case .onDisappear:                      return "CreateFoodView_Disappear"
            case .imageSelectorStart:               return "IngredientImageSelector_Start"
            case .imageSelectorSuccess:             return "IngredientImageSelector_Success"
            case .imageSelectorCancel:              return "IngredientImageSelector_Cancel"
            case .learnMorePressed:     return "CreateFoodView_LearnMore_Press"
            case .imageSelectorFail:                return "IngredientImageSelector_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .imageSelectorFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .imageSelectorFail:
                return .severe
            default:
                return .analytic

            }
        }
    }
}
