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
        /// A set, with the badge its circle shows: "B1·1", "B2·1", "B1·2L", "B1W" for a warm-up.
        case set(id: String, badge: String)
    }

    let exerciseId: String
    let kind: Kind
    /// The last row of its round, warm-ups being round 0: the card draws a separator under it
    /// and none between the rows of one round.
    var endsRound = false

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

    // MARK: - Letters

    /// "A" for 0, "B" for 1…, `nil` past "Z".
    static func letter(_ index: Int) -> String? {
        guard (0..<26).contains(index), let scalar = UnicodeScalar(65 + index) else { return nil }
        return String(Character(scalar))
    }

    /// The superset's own letter, by `supersetGroupId`: "A" for the first superset in workout
    /// order, "B" for the second… as the strip and the templates letter them.
    static func supersetLetters(_ exercises: [WorkoutExerciseModel]) -> [String: String] {
        let byId = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var letters: [String: String] = [:]
        for block in blocks(exercises) where block.count > 1 {
            guard let groupId = block.first.flatMap({ byId[$0]?.supersetGroupId }) else { continue }
            letters[groupId] = letter(letters.count)
        }
        return letters
    }

    /// A member's label on the card: the superset's letter and the member's place in it, "B2".
    static func memberLabel(letter: String, index: Int) -> String {
        "\(letter)\(index + 1)"
    }

    /// A row's badge as VoiceOver reads it: "B1, set 2L" for "B1·2L", "B1 warm-up" for "B1W",
    /// rather than "B1 dot 2".
    static func spokenBadge(_ badge: String) -> String {
        let parts = badge.split(separator: "·", maxSplits: 1)
        if parts.count == 2 { return String(localized: "\(String(parts[0])), set \(String(parts[1]))") }
        if badge.count > 1, badge.hasSuffix("W") { return String(localized: "\(String(badge.dropLast())) warm-up") }
        return badge
    }

    // MARK: - Rows

    /// The superset card's table, top to bottom. First each member's warm-ups, grouped by member
    /// (logged ones folded into one line), since warm-ups are round 0. Then the working sets in
    /// rounds: B1·1, B2·1, B1·2, B2·2…, both halves of a left/right pair together. Badges name the
    /// member (`memberLabel`) and number the set within it.
    static func blockRows(_ members: [WorkoutExerciseModel], letter: String) -> [SupersetBlockRow] {
        var rows: [SupersetBlockRow] = []
        let labels = members.indices.map { memberLabel(letter: letter, index: $0) }

        for (member, label) in zip(members, labels) {
            if member.sets.contains(where: { $0.isWarmup && $0.completedAt != nil }) {
                rows.append(SupersetBlockRow(exerciseId: member.id, kind: .loggedWarmups))
            }
            for set in member.sets where set.isWarmup && set.completedAt == nil {
                rows.append(SupersetBlockRow(exerciseId: member.id, kind: .set(id: set.id, badge: "\(label)W")))
            }
        }
        rows.indices.last.map { rows[$0].endsRound = true }

        let working = members.map { member in
            member.sets.filter { !$0.isWarmup }.map { (set: $0, round: round(of: $0, in: member)) }
        }
        let lastRound = working.flatMap { $0.map(\.round) }.max() ?? 0
        guard lastRound > 0 else { return rows }
        for round in 1...lastRound {
            for (index, member) in members.enumerated() {
                for entry in working[index] where entry.round == round {
                    let side = entry.set.side?.initial ?? ""
                    rows.append(SupersetBlockRow(
                        exerciseId: member.id,
                        kind: .set(id: entry.set.id, badge: "\(labels[index])·\(round)\(side)")
                    ))
                }
            }
            rows.indices.last.map { rows[$0].endsRound = true }
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
    /// unit for it. Otherwise each member gets its own row of headings.
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
