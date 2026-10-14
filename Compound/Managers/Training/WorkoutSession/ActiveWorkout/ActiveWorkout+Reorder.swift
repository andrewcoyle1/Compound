//
//  ActiveWorkout+Reorder.swift
//  Compound
//
//  Moving a block along the workout, as the strip's drag, its Move Earlier/Later and VoiceOver's
//  actions all do: a superset is one block and travels as one.
//

import Foundation

extension ActiveWorkout {

    /// The workout with the block whose first exercise is `blockId` put at `index` among the other
    /// blocks (clamped, so `blocks.count - 1` is the end). A superset moves as one and, flattened
    /// back through `blocks(_:)`, comes out together even if its members had drifted apart. An
    /// unknown id leaves the workout as it is.
    static func movingBlock(_ blockId: String, toBlockIndex index: Int, in exercises: [WorkoutExerciseModel]) -> [WorkoutExerciseModel] {
        var order = blocks(exercises)
        guard let from = order.firstIndex(where: { $0.first == blockId }) else { return exercises }
        let block = order.remove(at: from)
        order.insert(block, at: max(0, min(index, order.count)))
        let byId = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.flatMap { $0 }.compactMap { byId[$0] }
    }
}
