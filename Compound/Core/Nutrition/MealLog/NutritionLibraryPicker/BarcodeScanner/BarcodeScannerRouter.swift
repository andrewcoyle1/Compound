import SwiftUI

@MainActor
protocol BarcodeScannerRouter: GlobalRouter {
    
}

extension CoreRouter: BarcodeScannerRouter { }
