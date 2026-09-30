//
//  Macrocycle.swift
//  DialedIn
//
//  An ordered list of blocks (mesocycles) and where the user is in it. Every active mesocycle runs
//  through a plan; a standalone mesocycle is a plan of one block. Finishing a block's microcycles
//  moves the plan to the next block, and after the last one it is `completed` until the user
//  repeats it or starts something else.
//

import Foundation

struct Macrocycle: DataSyncModelProtocol, Hashable {

    enum Status: String, Codable, Sendable {
        case active
        /// Every block is done; the user is offered a repeat.
        case completed
        /// Replaced by another plan.
        case ended
    }

    let id: String
    let authorId: String
    var name: String
    /// The blocks, in order.
    var mesocycleIds: [String]
    var status: Status
    var mesocycleIndex: Int
    /// Only sessions finished after this count towards the current block.
    var mesocycleStartedAt: Date
    var skips: [CycleSkip]
    /// How many times the plan has been started, from 1.
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
        self.skips = skips
        self.iteration = iteration
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case name
        case mesocycleIds = "program_ids"
        case status
        case mesocycleIndex = "block_index"
        case mesocycleStartedAt = "block_started_at"
        case skips
        case iteration
        case dateCreated = "date_created"
        case dateModified = "date_modified"
    }

    var eventParameters: [String: Any] {
        [
            "plan_id": id,
            "plan_block_count": mesocycleIds.count,
            "plan_block_index": mesocycleIndex,
            "plan_status": status.rawValue,
            "plan_iteration": iteration
        ]
    }

    var currentMesocycleId: String? {
        mesocycleIds.indices.contains(mesocycleIndex) ? mesocycleIds[mesocycleIndex] : nil
    }

    var isLastMesocycle: Bool {
        mesocycleIndex >= mesocycleIds.count - 1
    }

    /// The skips made in the current block.
    var currentSkips: [CycleSkip] {
        skips.filter { $0.mesocycleIndex == mesocycleIndex }
    }

    /// The next block, from a clean start, or the plan marked completed after the last one.
    func advanced(now: Date = Date()) -> Macrocycle {
        var plan = self
        plan.dateModified = now
        if isLastMesocycle {
            plan.status = .completed
        } else {
            plan.mesocycleIndex += 1
            plan.mesocycleStartedAt = now
        }
        return plan
    }

    /// Back to the first block with no history counted.
    func repeated(now: Date = Date()) -> Macrocycle {
        var plan = self
        plan.status = .active
        plan.mesocycleIndex = 0
        plan.mesocycleStartedAt = now
        plan.skips = []
        plan.iteration += 1
        plan.dateModified = now
        return plan
    }

    static var mock: Macrocycle {
        Macrocycle(authorId: UserModel.mock.userId, name: Mesocycle.mock.name, mesocycleIds: [Mesocycle.mock.id])
    }
}
