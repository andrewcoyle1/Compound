//
//  Macrocycle.swift
//  DialedIn
//
//  An ordered list of mesocycles and where the user is in it. Every active mesocycle runs through
//  a macrocycle; a standalone mesocycle is a macrocycle of one. Finishing a mesocycle's microcycles
//  moves on to the next, and after the last the macrocycle is `completed` until the user repeats
//  it or starts something else.
//

import Foundation

struct Macrocycle: DataSyncModelProtocol, Hashable {

    enum Status: String, Codable, Sendable {
        /// Saved but never followed.
        case notStarted
        case active
        /// Every mesocycle is done; the user is offered a repeat.
        case completed
        /// Replaced by another macrocycle.
        case ended
    }

    let id: String
    let authorId: String
    var name: String
    /// The mesocycles, in order.
    var mesocycleIds: [String]
    var status: Status
    var mesocycleIndex: Int
    /// Only sessions finished after this count towards the current mesocycle.
    var mesocycleStartedAt: Date
    /// The microcycle the current mesocycle was joined at, 0-based; the ones before it were done
    /// outside the app. Nil from the first microcycle, and after moving to the next mesocycle.
    var startMicrocycleIndex: Int?
    var skips: [CycleSkip]
    /// How many times the macrocycle has been started, from 1.
    var iteration: Int
    let dateCreated: Date
    var dateModified: Date

    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String,
        mesocycleIds: [String],
        status: Status = .active,
        mesocycleIndex: Int = 0,
        mesocycleStartedAt: Date = Date(),
        startMicrocycleIndex: Int? = nil,
        skips: [CycleSkip] = [],
        iteration: Int = 1,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.mesocycleIds = mesocycleIds
        self.status = status
        self.mesocycleIndex = mesocycleIndex
        self.mesocycleStartedAt = mesocycleStartedAt
        self.startMicrocycleIndex = startMicrocycleIndex
        self.skips = skips
        self.iteration = iteration
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case name
        case mesocycleIds = "mesocycle_ids"
        case status
        case mesocycleIndex = "mesocycle_index"
        case mesocycleStartedAt = "mesocycle_started_at"
        case startMicrocycleIndex = "start_microcycle_index"
        case skips
        case iteration
        case dateCreated = "date_created"
        case dateModified = "date_modified"
    }

    var eventParameters: [String: Any] {
        [
            "macrocycle_id": id,
            "macrocycle_mesocycle_count": mesocycleIds.count,
            "macrocycle_mesocycle_index": mesocycleIndex,
            "macrocycle_status": status.rawValue,
            "macrocycle_iteration": iteration
        ]
    }

    var currentMesocycleId: String? {
        mesocycleIds.indices.contains(mesocycleIndex) ? mesocycleIds[mesocycleIndex] : nil
    }

    var isLastMesocycle: Bool {
        mesocycleIndex >= mesocycleIds.count - 1
    }

    /// The skips made in the current mesocycle.
    var currentSkips: [CycleSkip] {
        skips.filter { $0.mesocycleIndex == mesocycleIndex }
    }

    /// The next mesocycle, from its first microcycle, or the macrocycle marked completed after the
    /// last one.
    func advanced(now: Date = Date()) -> Macrocycle {
        var macrocycle = self
        macrocycle.dateModified = now
        if isLastMesocycle {
            macrocycle.status = .completed
        } else {
            macrocycle.mesocycleIndex += 1
            macrocycle.mesocycleStartedAt = now
            macrocycle.startMicrocycleIndex = nil
        }
        return macrocycle
    }

    /// Followed from `mesocycleIndex` and `microcycleIndex` (both 0-based) with no history counted.
    /// Someone joining part-way picks where they are; the microcycles before it count as done.
    func started(atMesocycle mesocycleIndex: Int = 0, microcycle microcycleIndex: Int = 0, now: Date = Date()) -> Macrocycle {
        var macrocycle = self
        if status != .notStarted { macrocycle.iteration += 1 }
        macrocycle.status = .active
        macrocycle.mesocycleIndex = min(max(mesocycleIndex, 0), max(mesocycleIds.count - 1, 0))
        macrocycle.mesocycleStartedAt = now
        macrocycle.startMicrocycleIndex = microcycleIndex > 0 ? microcycleIndex : nil
        macrocycle.skips = []
        macrocycle.dateModified = now
        return macrocycle
    }

    /// Back to the first mesocycle with no history counted.
    func repeated(now: Date = Date()) -> Macrocycle {
        started(now: now)
    }

    static var mock: Macrocycle {
        Macrocycle(authorId: UserModel.mock.userId, name: Mesocycle.mock.name, mesocycleIds: [Mesocycle.mock.id])
    }
}
