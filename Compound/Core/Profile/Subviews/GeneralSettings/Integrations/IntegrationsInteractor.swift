import SwiftUI

@MainActor
protocol IntegrationsInteractor: GlobalInteractor {
    var stravaAthlete: StravaAthlete? { get }
    var stravaPendingUploadCount: Int { get }
    var stravaBackfillCount: Int { get }
    func stravaAuthenticate() async throws
    func stravaDisconnect() async throws
    func stravaRefreshConnection() async
    func stravaQueueBackfill() -> Int
    func stravaSyncPendingUploads() async
    func stravaTestUpload() async throws
}

extension CoreInteractor: IntegrationsInteractor {
    var stravaIsConnected: Bool { stravaManager.isConnected }
    var stravaAthlete: StravaAthlete? { stravaManager.athlete }
    var stravaPendingUploadCount: Int { stravaManager.pendingSessionIds.count }
    var stravaBackfillCount: Int { stravaManager.backfillCandidates.count }

    func stravaAuthenticate() async throws {
        try await stravaManager.authenticate()
    }

    func stravaDisconnect() async throws {
        try await stravaManager.disconnect()
    }

    /// Best-effort: offline, the last known state stands.
    func stravaRefreshConnection() async {
        try? await stravaManager.refreshConnection()
    }

    func stravaQueueBackfill() -> Int {
        stravaManager.queueBackfill()
    }

    func stravaSyncPendingUploads() async {
        await stravaManager.syncPendingUploads()
    }

    func stravaTestUpload() async throws {
        try await stravaManager.uploadTestActivity()
    }
}
