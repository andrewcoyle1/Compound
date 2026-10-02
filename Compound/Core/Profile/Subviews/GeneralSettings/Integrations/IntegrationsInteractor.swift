import SwiftUI

@MainActor
protocol IntegrationsInteractor: GlobalInteractor {
    var stravaIsConnected: Bool { get }
    func stravaAuthenticate() async throws
    func stravaDisconnect()
    func stravaTestUpload() async throws
}

extension CoreInteractor: IntegrationsInteractor {
    var stravaIsConnected: Bool { stravaManager.isConnected }

    func stravaAuthenticate() async throws {
        try await stravaManager.authenticate()
    }

    func stravaDisconnect() {
        stravaManager.disconnect()
    }

    func stravaTestUpload() async throws {
        try await stravaManager.uploadTestActivity()
    }
}
