//
//  ActiveWorkout+SupersetBlock.swift
//  Compound
//
//  A superset on the card: which exercises share it, the letter each superset and each member
//  goes by, and the order its rows are drawn in. The rows follow the log button's rounds
//  (`nextSet(inBlock:)`), so the table reads top to bottom in the order the sets are done.
//

import Foundation

/// One line of a superset card's set table.
struct SupersetBlockRow: Identifiable, Equatable {
    enum Kind: Equatable {
        /// A member's logged warm-ups, folded into one line as on a single exercise's card.
        case loggedWarmups
        /// A set, with the badge its circle shows: "A1", "B2", "A1L", "AW" for a warm-up.
        case set(id: String, badge: String)
    }

    let exerciseId: String
    let kind: Kind

    var id: String {
        switch kind {
        case .loggedWarmups: "warmups-\(exerciseId)"
        case .set(let id, _): id
        }
    }
}

extension ActiveWorkout {

    // MARK: - Which card

    /// The members of the superset `exerciseId` belongs to, in workout order, when it has more
    /// than one: the card shows them together. `nil` for an exercise on its own.
    static func supersetBlock(containing exerciseId: String?, in exercises: [WorkoutExerciseModel]) -> [WorkoutExerciseModel]? {
        guard let exerciseId,
              let block = blocks(exercises).first(where: { $0.contains(exerciseId) }),
              block.count > 1 else { return nil }
        return block.compactMap { id in exercises.first { $0.id == id } }
    }

    /// The exercises on the card with `current`: its whole superset, or it alone. Up Next and
    /// Completed leave these out.
    static func cardExerciseIds(current: String?, in exercises: [WorkoutExerciseModel]) -> Set<String> {
        if let block = supersetBlock(containing: current, in: exercises) { return Set(block.map(\.id)) }
        return current.map { [$0] } ?? []
    }

    // MARK: - Letters

    /// "A" for 0, "B" for 1…, `nil` past "Z".
    static func letter(_ index: Int) -> String? {
        guard (0..<26).contains(index), let scalar = UnicodeScalar(65 + index) else { return nil }
        return String(Character(scalar))
    }

    /// "Superset A", "Circuit B": the superset's letter among the workout's supersets, in the
    /// order they come, so two supersets never share one. `nil` outside a superset of two or more.
    static func supersetLabel(for exercise: WorkoutExerciseModel, in exercises: [WorkoutExerciseModel]) -> String? {
        guard let block = supersetBlock(containing: exercise.id, in: exercises) else { return nil }
        let supersets = blocks(exercises).filter { $0.count > 1 }
        guard let index = supersets.firstIndex(where: { $0.contains(exercise.id) }), let letter = letter(index) else { return nil }
        let prefix = block.count > 2 ? String(localized: "Circuit") : String(localized: "Superset")
        return "\(prefix) \(letter)"
    }

    // MARK: - Rows

    /// The superset card's table, top to bottom. First each member's warm-ups, grouped by member
    /// (logged ones folded into one line), since warm-ups are round 0. Then the working sets in
    /// rounds: A1, B1, A2, B2…, both halves of a left/right pair together. Badges letter the
    /// member and number the set within it.
    static func blockRows(_ members: [WorkoutExerciseModel]) -> [SupersetBlockRow] {
        var rows: [SupersetBlockRow] = []
        let letters = members.indices.map { letter($0) ?? "" }

        for (member, letter) in zip(members, letters) {
            if member.sets.contains(where: { $0.isWarmup && $0.completedAt != nil }) {
                rows.append(SupersetBlockRow(exerciseId: member.id, kind: .loggedWarmups))
            }
            for set in member.sets where set.isWarmup && set.completedAt == nil {
                rows.append(SupersetBlockRow(exerciseId: member.id, kind: .set(id: set.id, badge: "\(letter)W")))
            }
        }

        let working = members.map { member in
            member.sets.filter { !$0.isWarmup }.map { (set: $0, round: round(of: $0, in: member)) }
        }
        let lastRound = working.flatMap { $0.map(\.round) }.max() ?? 0
        guard lastRound > 0 else { return rows }
        for round in 1...lastRound {
            for (index, member) in members.enumerated() {
                for entry in working[index] where entry.round == round {
                    let badge = "\(letters[index])\(round)\(entry.set.side?.initial ?? "")"
                    rows.append(SupersetBlockRow(exerciseId: member.id, kind: .set(id: entry.set.id, badge: badge)))
                }
            }
        }
        return rows
    }

    /// The set the log button logs next on a superset's card, walking the rounds from the member
    /// the card is on, as `primaryAction` does.
    static func nextSetId(inBlock members: [WorkoutExerciseModel], current: String?) -> String? {
        let start = members.firstIndex { $0.id == current } ?? 0
        return nextSet(inBlock: members.map(\.id), of: members, from: start)?.setId
    }

    /// A row's state on a superset's card. One row is current, the set the log button logs
    /// next; a partner's own next set reads as upcoming until the round reaches it.
    static func blockRowState(of set: WorkoutSetModel, in exercise: WorkoutExerciseModel, isNext: Bool) -> SetRowState {
        let state = rowState(of: set, in: exercise)
        return state == .current && !isNext ? .upcoming : state
    }

    /// Whether one row of column headings fits every member: the same tracking mode and the same
    /// unit for it. Otherwise the headings are left off and each field names itself.
    static func blockSharesColumns(_ members: [WorkoutExerciseModel], units: (WorkoutExerciseModel) -> ExerciseUnitPreference) -> Bool {
        let columns = members.map { member -> String in
            let preference = units(member)
            switch member.trackingMode {
            case .weightReps: return "\(member.trackingMode.rawValue)|\(preference.weightUnit)"
            case .distanceTime: return "\(member.trackingMode.rawValue)|\(preference.distanceUnit)"
            case .repsOnly, .timeOnly: return member.trackingMode.rawValue
            }
        }
        return Set(columns).count <= 1
    }
}
