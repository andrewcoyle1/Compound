//
//  DataAccessLog.swift
//  DialedIn
//
//  A Development-only tally of Firestore listeners started and documents read, per app launch and
//  per screen. It sits in the dev `LogManager` beside the console, so it sees what every sync
//  engine logs (each engine is handed that `LogManager`) and every `trackScreenEvent`, and
//  attributes each read to the screen most recently shown. Calls made straight to Firestore —
//  `FirebaseUserQueryService`, notifications, comments — bypass the engines and are not counted.
//
//  How the engines' events map to cost:
//  - A collection or collection-group engine logs `_bulkLoad_start` once per `startListening`, then
//    `_bulkLoad_success` with the documents the bulk get read, then `_listener_success` with the
//    collection's size when its snapshot listener first delivers. Firestore bills that initial
//    snapshot as well, so a start reads the matching documents twice.
//  - A document engine logs `_listener_start` (with a `document_id`) and one read per delivery,
//    `_listener_success` or, for a missing document, `_listener_empty`.
//  - One-off reads log `_getDocumentsQuery_success` / `_getCollection_success` with a count, and
//    `_getDocument_success` for one document.
//

import Foundation

enum DataAccessLogging {
    /// Added to the dev `LogManager`'s services; empty outside Debug builds.
    static var devServices: [LogService] {
        #if DEBUG
        [DataAccessLog.shared]
        #else
        []
        #endif
    }
}

#if DEBUG
final class DataAccessLog: LogService, @unchecked Sendable {

    static let shared = DataAccessLog(printsSummaries: true)

    struct Tally: Equatable {
        var listenersStarted = 0
        var documentsRead = 0
    }

    static let launchScope = "launch"

    private let lock = NSLock()
    private var scope = DataAccessLog.launchScope
    private var scopeOrder: [String] = [DataAccessLog.launchScope]
    private var tallies: [String: [String: Tally]] = [:]
    private let printsSummaries: Bool

    init(printsSummaries: Bool = false) {
        self.printsSummaries = printsSummaries
    }

    /// Totals for one scope — `launchScope`, or a screen event's name — across every manager key.
    func total(for scope: String) -> Tally {
        lock.withLock {
            (tallies[scope] ?? [:]).values.reduce(into: Tally()) { sum, tally in
                sum.listenersStarted += tally.listenersStarted
                sum.documentsRead += tally.documentsRead
            }
        }
    }

    /// Per manager key within one scope.
    func tallies(for scope: String) -> [String: Tally] {
        lock.withLock { tallies[scope] ?? [:] }
    }

    /// One line per scope, then one per manager key, in the order the scopes were first seen.
    func summary() -> String {
        let scopes = lock.withLock { scopeOrder }
        return scopes.map { scope in
            let total = total(for: scope)
            let keys = tallies(for: scope)
                .sorted { $0.value.documentsRead > $1.value.documentsRead }
                .map { "  \($0.key): \($0.value.listenersStarted) listeners, \($0.value.documentsRead) reads" }
            let header = "[DataAccess] \(scope): \(total.listenersStarted) listeners, \(total.documentsRead) reads"
            return ([header] + keys).joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    // MARK: - LogService

    func identifyUser(userId: String, name: String?, email: String?) { }
    func addUserProperties(dict: [String: Any], isHighPriority: Bool) { }
    func deleteUserProfile() { }

    func trackScreenView(event: LoggableEvent) {
        let previous: String = lock.withLock {
            let previous = scope
            scope = event.eventName
            if !scopeOrder.contains(scope) { scopeOrder.append(scope) }
            return previous
        }
        if printsSummaries {
            let total = total(for: previous)
            print("[DataAccess] \(previous): \(total.listenersStarted) listeners, \(total.documentsRead) reads")
        }
    }

    func trackEvent(event: LoggableEvent) {
        guard let (key, delta) = Self.cost(of: event.eventName, parameters: event.parameters) else { return }
        lock.withLock {
            var tally = tallies[scope, default: [:]][key, default: Tally()]
            tally.listenersStarted += delta.listenersStarted
            tally.documentsRead += delta.documentsRead
            tallies[scope, default: [:]][key] = tally
        }
    }

    /// The manager key and cost an engine event stands for, or nil for an event that costs nothing.
    static func cost(of eventName: String, parameters: [String: Any]?) -> (key: String, tally: Tally)? {
        let count = parameters?["count"] as? Int ?? 0
        let isDocumentEngine = parameters?["document_id"] != nil
        let rules: [(suffix: String, tally: Tally?)] = [
            ("_bulkLoad_start", Tally(listenersStarted: 1)),
            ("_bulkLoad_success", Tally(documentsRead: count)),
            ("_listener_start", isDocumentEngine ? Tally(listenersStarted: 1) : nil),
            ("_listener_success", Tally(documentsRead: isDocumentEngine ? 1 : count)),
            ("_listener_empty", Tally(documentsRead: 1)),
            ("_getDocumentsQuery_success", Tally(documentsRead: count)),
            ("_getCollection_success", Tally(documentsRead: count)),
            ("_getDocument_success", Tally(documentsRead: 1))
        ]
        for rule in rules where eventName.hasSuffix(rule.suffix) {
            guard let tally = rule.tally else { return nil }
            return (String(eventName.dropLast(rule.suffix.count)), tally)
        }
        return nil
    }
}
#endif
