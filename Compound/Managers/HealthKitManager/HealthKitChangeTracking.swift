//
//  HealthKitChangeTracking.swift
//  Compound
//
//  Created by Andrew Coyle on 01/10/2026.
//
#if canImport(HealthKit)
import HealthKit
import UIKit

/// The pieces the weight and steps imports share: they fetch what changed since a stored anchor,
/// and run again whenever Health reports a change.
extension HKHealthStore {

    /// Samples this app wrote are logged here already, so imports leave them out.
    static var notFromThisApp: NSPredicate {
        NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: .default()))
    }

    static func anchor(from data: Data?) -> HKQueryAnchor? {
        data.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
    }

    static func data(from anchor: HKQueryAnchor) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    /// Observer queries for `types`, plus the app becoming active: without the background
    /// delivery entitlement, nothing reports changes made while the app was suspended. Ends, and
    /// stops the queries, when the consuming task is cancelled.
    func changeNotifications(for types: [HKSampleType]) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let queries = types.map { type in
            HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, _ in
                continuation.yield()
                completionHandler()
            }
        }
        queries.forEach(execute)
        let activeTask = Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                continuation.yield()
            }
        }
        continuation.onTermination = { [self] _ in
            queries.forEach(stop)
            activeTask.cancel()
        }
        return stream
    }
}
#endif
