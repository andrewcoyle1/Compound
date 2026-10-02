import SwiftUI

@MainActor
protocol CustomiseAnalyticsInteractor: GlobalInteractor {
    var analyticsSettings: AnalyticsSettings { get }
    func saveAnalyticsSettings(_ settings: AnalyticsSettings) async throws
}

extension CoreInteractor: CustomiseAnalyticsInteractor { }
