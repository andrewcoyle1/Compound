//
//  PickableItem.swift
//  Compound
//

/// An enum offered as a menu of options, with a name and an optional line of explanation.
protocol PickableItem: CaseIterable, Hashable where AllCases: RandomAccessCollection {
    var name: String { get }
    var description: String? { get }
}
