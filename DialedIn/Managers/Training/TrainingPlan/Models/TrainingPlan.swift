//
//  TrainingPlan.swift
//  DialedIn
//
//  An ordered list of blocks (programs) and where the user is in it. Every active program runs
//  through a plan; a standalone program is a plan of one block. Finishing a block's microcycles
//  moves the plan to the next block, and after the last one it is `completed` until the user
//  repeats it or starts something else.
//

import Foundation

struct TrainingPlan: DataSyncModelProtocol, Hashable {

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
    var programIds: [String]
    var status: Status
    var blockIndex: Int
    /// Only sessions finished after this count towards the current block.
    var blockStartedAt: Date
    var skips: [PlanSkip]
    /// How many times the plan has been started, from 1.
    var iteration: Int
    let dateCreated: Date
    var dateModified: Date

    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String,
        programIds: [String],
        status: Status = .active,
        blockIndex: Int = 0,
        blockStartedAt: Date = Date(),
        skips: [PlanSkip] = [],
        iteration: Int = 1,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.programIds = programIds
        self.status = status
        self.blockIndex = blockIndex
        self.blockStartedAt = blockStartedAt
        self.skips = skips
        self.iteration = iteration
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case name
        case programIds = "program_ids"
        case status
        case blockIndex = "block_index"
        case blockStartedAt = "block_started_at"
        case skips
        case iteration
        case dateCreated = "date_created"
        case dateModified = "date_modified"
    }

    var eventParameters: [String: Any] {
        [
            "plan_id": id,
            "plan_block_count": programIds.count,
            "plan_block_index": blockIndex,
            "plan_status": status.rawValue,
            "plan_iteration": iteration
        ]
    }

    var currentProgramId: String? {
        programIds.indices.contains(blockIndex) ? programIds[blockIndex] : nil
    }

    var isLastBlock: Bool {
        blockIndex >= programIds.count - 1
    }

    /// The skips made in the current block.
    var currentSkips: [PlanSkip] {
        skips.filter { $0.blockIndex == blockIndex }
    }

    /// The next block, from a clean start, or the plan marked completed after the last one.
    func advanced(now: Date = Date()) -> TrainingPlan {
        var plan = self
        plan.dateModified = now
        if isLastBlock {
            plan.status = .completed
        } else {
            plan.blockIndex += 1
            plan.blockStartedAt = now
        }
        return plan
    }

    /// Back to the first block with no history counted.
    func repeated(now: Date = Date()) -> TrainingPlan {
        var plan = self
        plan.status = .active
        plan.blockIndex = 0
        plan.blockStartedAt = now
        plan.skips = []
        plan.iteration += 1
        plan.dateModified = now
        return plan
    }

    static var mock: TrainingPlan {
        TrainingPlan(authorId: UserModel.mock.userId, name: TrainingProgram.mock.name, programIds: [TrainingProgram.mock.id])
    }
}
