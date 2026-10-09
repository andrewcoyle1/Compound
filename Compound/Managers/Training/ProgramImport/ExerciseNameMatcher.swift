//
//  ExerciseNameMatcher.swift
//  Compound
//
//  A sheet's exercise name to a library exercise, strictest rule first: the exact name, an
//  alternate name, the same words ignoring case and punctuation, the same words once common
//  abbreviations are spelled out ("DB" is "Dumbbell"), the same words in any order, a library
//  name that only adds a position or equipment word ("Machine Hip Adduction" is the library's
//  "Seated Machine Hip Adduction"), and a sheet name that only adds words to a library name
//  ("Chest-Supported T-Bar Row" is "T-Bar Row"). Never a fuzzy or partial-word guess, which could
//  pick the wrong lift: a rule that fits more than one exercise fits none, and a word that defines
//  the lift (incline, concentration, a grip) is never waved through. `suggestions(for:)` ranks the
//  nearest names for the review screen instead.
//

import Foundation

struct ExerciseNameMatcher {

    private let library: [ExerciseModel]
    /// Each exercise's name and alternates as word sets, parentheticals dropped.
    private let entries: [(exercise: ExerciseModel, forms: [Set<String>])]

    init(library: [ExerciseModel]) {
        self.library = library
        entries = library.map { exercise in
            (exercise, ([exercise.name] + exercise.alternateNames).map(Self.words))
        }
    }

    func match(_ name: String) -> ExerciseModel? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = library.first(where: { $0.name == name }) { return exact }
        if let alternate = library.first(where: { $0.alternateNames.contains(name) }) { return alternate }
        if let loose = unique(matching: Self.normalized(name), by: Self.normalized) { return loose }
        if let expanded = unique(matching: Self.expanded(name), by: Self.expanded) { return expanded }
        let words = Self.words(name)
        guard words.count >= 2 else { return nil }
        if let reordered = unique(where: { $0 == words }) { return reordered }
        if let qualified = unique(where: { $0.isSubset(of: words) == false && words.isSubset(of: $0) && $0.subtracting(words).isSubset(of: Self.qualifiers) }) {
            return qualified
        }
        return longestContained(in: words)
    }

    /// Up to `limit` exercises nearest to `name` by the words they share, best first, for the
    /// review screen to offer. Empty when nothing shares a word.
    func suggestions(for name: String, limit: Int = 3) -> [ExerciseModel] {
        let words = Self.words(name)
        guard !words.isEmpty else { return [] }
        let scored = entries.compactMap { entry -> (score: Double, exercise: ExerciseModel)? in
            let best = entry.forms.map { form -> Double in
                let shared = Double(form.intersection(words).count)
                return shared == 0 ? 0 : shared / Double(form.union(words).count)
            }.max() ?? 0
            return best > 0 ? (best, entry.exercise) : nil
        }
        return scored
            .sorted { $0.score == $1.score ? $0.exercise.name < $1.exercise.name : $0.score > $1.score }
            .prefix(limit)
            .map(\.exercise)
    }

    /// The one exercise whose name or an alternate name has `key` under `form`, or nil when none
    /// or several do.
    private func unique(matching key: String, by form: (String) -> String) -> ExerciseModel? {
        guard !key.isEmpty else { return nil }
        let matches = library.filter { exercise in
            ([exercise.name] + exercise.alternateNames).contains { form($0) == key }
        }
        return Set(matches.map(\.id)).count == 1 ? matches.first : nil
    }

    /// The one exercise with a name or alternate whose words satisfy `test`, or nil.
    private func unique(where test: (Set<String>) -> Bool) -> ExerciseModel? {
        let matches = entries.filter { $0.forms.contains(where: test) }.map(\.exercise)
        return Set(matches.map(\.id)).count == 1 ? matches.first : nil
    }

    /// The library name the sheet's name only adds words to, the longest such name when it is the
    /// only one of its length. A one-word library name is never taken: "Row" would fit every row.
    private func longestContained(in words: Set<String>) -> ExerciseModel? {
        var best: [(count: Int, exercise: ExerciseModel)] = []
        for entry in entries {
            for form in entry.forms where form.count >= 2 && form.isSubset(of: words) {
                best.append((form.count, entry.exercise))
            }
        }
        guard let longest = best.map(\.count).max() else { return nil }
        let top = Set(best.filter { $0.count == longest }.map(\.exercise.id))
        return top.count == 1 ? best.first { $0.count == longest }?.exercise : nil
    }

    // MARK: - Forms

    /// Lower-cased words with punctuation dropped: "Pull-Down (Wide)" is "pull down wide".
    static func normalized(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "°", with: " degree ")
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// `normalized`, with each abbreviation spelled out the same way on both sides.
    static func expanded(_ name: String) -> String {
        var words = " \(normalized(name)) "
        for (short, long) in expansions {
            words = words.replacingOccurrences(of: " \(short) ", with: " \(long) ")
        }
        return words.trimmingCharacters(in: .whitespaces)
    }

    /// `expanded` as a set of words, with the parenthetical qualifiers a library name carries
    /// ("(With Overhead Handles)", "(Cable)") and filler words left out.
    static func words(_ name: String) -> Set<String> {
        let unbracketed = name.replacing(#/\([^)]*\)/#, with: " ")
        return Set(expanded(unbracketed).split(separator: " ").map(String.init)).subtracting(fillers)
    }

    private static let fillers: Set<String> = ["the", "a", "of", "with", "on", "and", "w"]

    /// Words a library name may add to a sheet's and still be the same lift: where it is done and
    /// what it is loaded on. Never a word that makes a different lift (incline, concentration, a
    /// grip, an attachment).
    private static let qualifiers: Set<String> = [
        "seated", "standing", "kneeling", "lying", "cable", "machine", "lever", "pin", "loaded",
        "plate", "smith", "degree", "45"
    ]

    private static let expansions: [(String, String)] = [
        ("db", "dumbbell"),
        ("bb", "barbell"),
        ("sm", "smith machine"),
        ("1 arm", "single arm"),
        ("one arm", "single arm"),
        ("pulldown", "pull down"),
        ("flye", "fly"),
        ("rdl", "romanian deadlift"),
        ("ez barbell", "ez bar"),
        ("pressdown", "pushdown"),
        ("press down", "pushdown"),
        ("push down", "pushdown"),
        ("skullcrusher", "skull crusher"),
        ("hyperextension", "back extension"),
        ("hamstring curl", "leg curl")
    ]
}
