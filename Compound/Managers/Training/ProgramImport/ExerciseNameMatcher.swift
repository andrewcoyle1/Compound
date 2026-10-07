//
//  ExerciseNameMatcher.swift
//  Compound
//
//  A sheet's exercise name to a library exercise, strictest rule first: the exact name, an
//  alternate name, the same words ignoring case and punctuation, then the same words once common
//  abbreviations are spelled out ("DB" is "Dumbbell"). Never a fuzzy or partial-word guess, which
//  could pick the wrong lift: a loose rule that matches more than one exercise matches none.
//

import Foundation

struct ExerciseNameMatcher {

    private let library: [ExerciseModel]

    init(library: [ExerciseModel]) {
        self.library = library
    }

    func match(_ name: String) -> ExerciseModel? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = library.first(where: { $0.name == name }) { return exact }
        if let alternate = library.first(where: { $0.alternateNames.contains(name) }) { return alternate }
        if let loose = unique(matching: Self.normalized(name), by: Self.normalized) { return loose }
        return unique(matching: Self.expanded(name), by: Self.expanded)
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

    /// Lower-cased words with punctuation dropped: "Pull-Down (Wide)" is "pull down wide".
    static func normalized(_ name: String) -> String {
        name.lowercased()
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

    private static let expansions: [(String, String)] = [
        ("db", "dumbbell"),
        ("bb", "barbell"),
        ("sm", "smith machine"),
        ("1 arm", "single arm"),
        ("one arm", "single arm"),
        ("pulldown", "pull down"),
        ("flye", "fly")
    ]
}
