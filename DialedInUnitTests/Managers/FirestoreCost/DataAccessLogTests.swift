//
//  DataAccessLogTests.swift
//  DialedInUnitTests
//

#if DEBUG
import Foundation
import Testing
import SwiftfulDataManagers
@testable import DialedIn

@Suite("DataAccessLog")
@MainActor
struct DataAccessLogTests {

    private struct Screen: LoggableEvent {
        let eventName: String
        var parameters: [String: Any]? { nil }
        var type: LogType { .analytic }
    }

    @Test("A collection engine's start counts one listener and its bulk read, under launch")
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
        #expect((tally?.documentsRead ?? 0) >= steps.count)
        engine.stopListening()
    }

    @Test("Reads after a screen event are attributed to that screen")
    func readsAreScopedToTheLatestScreen() {
        let log = DataAccessLog()

        log.trackEvent(event: AnyLoggableEvent(eventName: "foods_bulkLoad_start", parameters: nil, type: .info))
        log.trackScreenView(event: Screen(eventName: "NutritionView_Appear"))
        log.trackEvent(event: AnyLoggableEvent(eventName: "meals_bulkLoad_start", parameters: nil, type: .info))
        log.trackEvent(event: AnyLoggableEvent(eventName: "meals_bulkLoad_success", parameters: ["count": 12], type: .info))

        #expect(log.total(for: DataAccessLog.launchScope) == DataAccessLog.Tally(listenersStarted: 1, documentsRead: 0))
        #expect(log.total(for: "NutritionView_Appear") == DataAccessLog.Tally(listenersStarted: 1, documentsRead: 12))
        #expect(log.summary().contains("NutritionView_Appear: 1 listeners, 12 reads"))
    }

    @Test("A document engine's listener counts once and a collection's duplicate listener_start does not")
    func listenerStartsAreNotDoubleCounted() {
        let document = DataAccessLog.cost(of: "goal_listener_start", parameters: ["document_id": "abc"])
        let collection = DataAccessLog.cost(of: "steps_listener_start", parameters: nil)

        #expect(document?.key == "goal")
        #expect(document?.tally == DataAccessLog.Tally(listenersStarted: 1))
        #expect(collection == nil)
        #expect(DataAccessLog.cost(of: "goal_listener_empty", parameters: ["document_id": "abc"])?.tally.documentsRead == 1)
        #expect(DataAccessLog.cost(of: "steps_save_success", parameters: nil) == nil)
    }
}
#endif
