//
//  DataAccessLogTests.swift
//  CompoundUnitTests
//

#if DEBUG
import Foundation
import Testing
import SwiftfulDataManagers
@testable import Compound

@Suite("DataAccessLog")
@MainActor
struct DataAccessLogTests {

    private struct Screen: LoggableEvent {
        let eventName: String
        var parameters: [String: Any]? { nil }
        var type: LogType { .analytic }
    }

    @Test("A collection engine's start counts one listener and one read of its documents, under launch")
    func collectionEngineStartIsCounted() async {
        let log = DataAccessLog()
        let steps = StepsModel.mocks
        let key = TestManagers.key("steps")
        let engine = CollectionSyncEngine<StepsModel>(
            remote: MockRemoteCollectionService(collection: steps),
            managerKey: key,
            enableLocalPersistence: false,
            logger: LogManager(services: [log])
        )

        await engine.startListening()

        let tally = log.tallies(for: DataAccessLog.launchScope)[key]
        #expect(tally?.listenersStarted == 1)
        // Once, not twice: the listener's first snapshot is the load, with no bulk get before it.
        #expect(tally?.documentsRead == steps.count)
        engine.stopListening()
    }

    @Test("Reads after a screen event are attributed to that screen")
    func readsAreScopedToTheLatestScreen() {
        let log = DataAccessLog()

        log.trackEvent(event: AnyLoggableEvent(eventName: "foods_listener_start", parameters: nil, type: .info))
        log.trackScreenView(event: Screen(eventName: "NutritionView_Appear"))
        log.trackEvent(event: AnyLoggableEvent(eventName: "meals_listener_start", parameters: nil, type: .info))
        log.trackEvent(event: AnyLoggableEvent(eventName: "meals_listener_success", parameters: ["count": 12], type: .info))

        #expect(log.total(for: DataAccessLog.launchScope) == DataAccessLog.Tally(listenersStarted: 1, documentsRead: 0))
        #expect(log.total(for: "NutritionView_Appear") == DataAccessLog.Tally(listenersStarted: 1, documentsRead: 12))
        #expect(log.summary().contains("NutritionView_Appear: 1 listeners, 12 reads"))
    }

    /// Every engine logs `_listener_start` once per listener it attaches, so document and
    /// collection engines count alike. A collection's read is its first delivery's size.
    @Test("Each engine's listener start counts once, and a collection's first delivery its reads")
    func listenerStartsCountOnce() {
        let document = DataAccessLog.cost(of: "goal_listener_start", parameters: ["document_id": "abc"])
        let collection = DataAccessLog.cost(of: "steps_listener_start", parameters: nil)

        #expect(document?.key == "goal")
        #expect(document?.tally == DataAccessLog.Tally(listenersStarted: 1))
        #expect(collection?.key == "steps")
        #expect(collection?.tally == DataAccessLog.Tally(listenersStarted: 1))
        #expect(DataAccessLog.cost(of: "steps_listener_success", parameters: ["count": 30])?.tally.documentsRead == 30)
        #expect(DataAccessLog.cost(of: "goal_listener_empty", parameters: ["document_id": "abc"])?.tally.documentsRead == 1)
        #expect(DataAccessLog.cost(of: "steps_save_success", parameters: nil) == nil)
    }
}
#endif
