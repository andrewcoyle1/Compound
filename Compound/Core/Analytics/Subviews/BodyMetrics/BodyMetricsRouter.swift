import SwiftUI

@MainActor
protocol BodyMetricsRouter: GlobalRouter {
    func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?)
    func showVisualBodyFatView(delegate: VisualBodyFatDelegate, themeColor: Color?)
    func showBodyRatioView(delegate: BodyRatioDelegate, themeColor: Color?)
    func showBodyMeasurementDetailView(kind: BodyMeasurementKind, themeColor: Color?)
    
    func showLogMeasurementView(kind: BodyMeasurementKind)
    func showProgressPhotosView()
}

extension CoreRouter: BodyMetricsRouter { }
