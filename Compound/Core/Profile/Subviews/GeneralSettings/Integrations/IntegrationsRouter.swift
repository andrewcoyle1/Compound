import SwiftUI

@MainActor
protocol IntegrationsRouter: GlobalRouter {

    /// Restated from `GlobalRouter`, which only provides it as an extension. Everything this screen
    /// reports — a refused Strava authorisation, a failed or successful test upload — is told to the
    /// user through this one call and nowhere else, so it needs to be a requirement to dispatch
    /// dynamically rather than statically.
    func showSimpleAlert(title: String, subtitle: String?)
}

extension CoreRouter: IntegrationsRouter { }
