//
//  Samples+Gym.swift
//  CompoundUnitTests
//
//  The fixed gym samples behind contracts/firestore/gym_profile, the eleven gym_<equipment>
//  folders, and contracts/firestore/gym_equipment_catalogue.json. See FirestoreContractTests.swift.
//
//  A profile's decoder appends every catalogue item its lists lack, so a profile only re-encodes
//  to itself when each list already holds the whole catalogue. The profile samples are therefore
//  built on the catalogue, with each item cut down to its required fields; the rich items that set
//  every optional field are appended after it and have folders of their own.
//

import Foundation
import FirebaseFirestore
import Testing
import UIKit
@testable import Compound

// MARK: - Equipment items

extension Samples {
    static let fullFreeWeights = FreeWeights(
        id: "free_weights_contract_full",
        typeId: "dumbbells",
        name: "Window Dumbbells",
        imageName: "dumbbells_icon",
        description: "The rack by the window",
        needsColour: true,
        isPlates: false,
        range: [
            FreeWeightsAvailable(
                id: "free_weights_contract_full_1", plateColour: "#FF3B30", availableWeights: 12.5,
                unit: .kilograms, isActive: true, count: 2
            ),
            FreeWeightsAvailable(
                id: "free_weights_contract_full_2", plateColour: nil, availableWeights: 27.5,
                unit: .pounds, isActive: false, count: nil
            )
        ],
        isActive: true
    )

    static let minimalFreeWeights = FreeWeights(
        id: "free_weights_contract_minimal", name: "Kettlebells", needsColour: false, range: [], isActive: false
    )

    static let fullBodyWeights = BodyWeights(
        id: "body_weights_contract_full",
        typeId: "weight_vest",
        name: "Loaded Vest",
        imageName: "weight_vest_icon",
        description: "Adjustable in small steps",
        range: [
            BodyWeightsAvailable(
                id: "body_weights_contract_full_1", plateColour: "#34C759", availableWeights: 2.5,
                unit: .kilograms, isActive: true
            )
        ],
        isActive: true
    )

    static let minimalBodyWeights = BodyWeights(id: "body_weights_contract_minimal", name: "Dip Belt", range: [], isActive: false)

    static let fullBands = Bands(
        id: "bands_contract_full",
        typeId: "long_elastic_bands",
        name: "Travel Bands",
        imageName: "bands_icon",
        description: "In the kit bag",
        range: [
            BandsAvailable(
                id: "bands_contract_full_1", name: "Light", bandColour: "#FF9500", availableResistance: 4.5,
                unit: .kilograms, isActive: true
            )
        ],
        isActive: true
    )

    static let minimalBands = Bands(id: "bands_contract_minimal", name: "Mini Bands", range: [], isActive: false)

    static let fullLoadableBars: LoadableBars = {
        var bar = LoadableBars(
            id: "loadable_bars_contract_full",
            typeId: "barbell",
            name: "Platform Barbell",
            imageName: "barbell_icon",
            description: "Platform two",
            baseWeights: [
                LoadableBarsBaseWeight(id: "loadable_bars_contract_full_1", baseWeight: 20.5, unit: .kilograms, isActive: true),
                LoadableBarsBaseWeight(id: "loadable_bars_contract_full_2", baseWeight: 44.5, unit: .pounds, isActive: false)
            ],
            collarWeight: 2.5,
            isActive: true
        )
        bar.chosenBaseWeightId = "loadable_bars_contract_full_2"
        return bar
    }()

    /// A collar weight of 0, the default, would be recorded as the integer 0.
    static let minimalLoadableBars = LoadableBars(
        id: "loadable_bars_contract_minimal", name: "Trap Bar", description: nil, baseWeights: [], collarWeight: 0.5, isActive: false
    )

    static let fullFixedWeightBars = FixedWeightBars(
        id: "fixed_weight_bars_contract_full",
        typeId: "fixed_weight_ez_bar",
        name: "Curl Bars",
        imageName: "ez_bar_icon",
        description: "On the wall rack",
        baseWeights: [
            FixedWeightBarsBaseWeight(id: "fixed_weight_bars_contract_full_1", baseWeight: 12.5, unit: .kilograms, isActive: true)
        ],
        isActive: true
    )

    static let minimalFixedWeightBars = FixedWeightBars(
        id: "fixed_weight_bars_contract_minimal", name: "Straight Bars", description: nil, baseWeights: [], isActive: false
    )

    static let fullSupportEquipment = SupportEquipment(
        id: "support_equipment_contract_full",
        typeId: "flat_bench",
        name: "Second Flat Bench",
        imageName: "flat_bench_icon",
        description: "By the mirrors",
        isActive: true
    )

    static let minimalSupportEquipment = SupportEquipment(id: "support_equipment_contract_minimal", name: "Plyo Box", isActive: false)

    static let fullAccessoryEquipment = AccessoryEquipment(
        id: "accessory_equipment_contract_full",
        typeId: "ab_wheel",
        name: "Spare Ab Wheel",
        imageName: "ab_wheel_icon",
        description: "In the stretching area",
        isActive: true
    )

    static let minimalAccessoryEquipment = AccessoryEquipment(id: "accessory_equipment_contract_minimal", name: "Foam Roller", isActive: false)

    static let fullLoadableAccessoryEquipment = LoadableAccessoryEquipment(
        id: "loadable_accessory_equipment_contract_full",
        typeId: "landmine",
        name: "Corner Landmine",
        imageName: "landmine_icon",
        description: "Bolted to the rack",
        baseWeight: 1.5,
        unit: .kilograms,
        isActive: true
    )

    static let minimalLoadableAccessoryEquipment = LoadableAccessoryEquipment(
        id: "loadable_accessory_equipment_contract_minimal", name: "Dip Belt Chain", baseWeight: 0.5, unit: .pounds, isActive: false
    )

    static let fullStack = WeightStack(
        id: "stack_contract_full", name: "Main Stack", minWeight: 2.5, maxWeight: 92.5, increment: 2.5,
        unit: .kilograms, isActive: true, addOns: [1.25, 2.5], weights: [2.5, 5.5, 8.5]
    )

    static let minimalStack = WeightStack(
        id: "stack_contract_minimal", name: "Range 1", minWeight: 4.5, maxWeight: 148.5, increment: 4.5,
        unit: .pounds, isActive: false
    )

    static let fullCableMachine: CableMachine = {
        var machine = CableMachine(
            id: "cable_machine_contract_full",
            typeId: "cable_crossover",
            name: "Left Crossover",
            imageName: "cable_crossover_icon",
            description: "Nearest the door",
            ranges: [fullStack, minimalStack],
            isActive: true
        )
        machine.defaultRangeId = minimalStack.id
        return machine
    }()

    static let minimalCableMachine = CableMachine(id: "cable_machine_contract_minimal", name: "Lat Tower", ranges: [], isActive: false)

    static let fullPinLoadedMachine: PinLoadedMachine = {
        var machine = PinLoadedMachine(
            id: "pin_loaded_machine_contract_full",
            typeId: "seated_leg_curl_machine",
            name: "Leg Curl Two",
            imageName: "leg_curl_icon",
            description: "The newer one",
            ranges: [fullStack],
            isActive: true
        )
        machine.defaultRangeId = fullStack.id
        return machine
    }()

    static let minimalPinLoadedMachine = PinLoadedMachine(id: "pin_loaded_machine_contract_minimal", name: "Pec Deck", ranges: [], isActive: false)

    static let fullPlateLoadedMachine = PlateLoadedMachine(
        id: "plate_loaded_machine_contract_full",
        typeId: "t_bar_row",
        name: "Chest-Supported T-Bar",
        imageName: "t_bar_icon",
        description: "Back corner",
        baseWeight: 12.5,
        unit: .kilograms,
        sleeves: 1,
        excludesBaseFromLoad: false,
        isActive: true
    )

    static let minimalPlateLoadedMachine = PlateLoadedMachine(
        id: "plate_loaded_machine_contract_minimal", name: "Hip Thrust", baseWeight: 7.5, unit: .pounds, isActive: false
    )
}

// MARK: - Gym profiles

extension Samples {
    static func fullGymProfile() throws -> GymProfileModel {
        let rich: [String: [String: Any]] = [
            "free_weights": try encodeItem(fullFreeWeights),
            "loadable_bars": try encodeItem(fullLoadableBars),
            "fixed_weight_bars": try encodeItem(fullFixedWeightBars),
            "bands": try encodeItem(fullBands),
            "body_weights": try encodeItem(fullBodyWeights),
            "support_equipment": try encodeItem(fullSupportEquipment),
            "accessory_equipment": try encodeItem(fullAccessoryEquipment),
            "loadable_accessory_equipment": try encodeItem(fullLoadableAccessoryEquipment),
            "cable_machines": try encodeItem(fullCableMachine),
            "plate_loaded_machines": try encodeItem(fullPlateLoadedMachine),
            "pin_loaded_machines": try encodeItem(fullPinLoadedMachine)
        ]
        var lists = try GymCatalogueContract.cutDownCatalogue()
        for (key, item) in rich {
            lists[key] = (lists[key] ?? []) + [item]
        }
        return try gymProfile([
            "id": "gym_contract_full",
            "author_id": "user_contract_full",
            "name": "Platinum Gym",
            "icon": "figure.strengthtraining.traditional",
            "image_url": "https://example.com/gym.jpg",
            "date_created": Timestamp(date: date("2026-07-01T07:00:00.125Z")),
            "date_modified": Timestamp(date: date("2026-10-03T19:45:00.875Z")),
            "deleted_at": Timestamp(date: date("2026-10-04T08:00:00.000Z"))
        ], lists: lists)
    }

    static func minimalGymProfile() throws -> GymProfileModel {
        try gymProfile([
            "id": "gym_contract_minimal",
            "author_id": "user_contract_minimal",
            "date_created": Timestamp(date: date("2026-07-02T07:00:00.000Z")),
            "date_modified": Timestamp(date: date("2026-07-02T07:00:00.000Z"))
        ], lists: try GymCatalogueContract.cutDownCatalogue())
    }

    private static func gymProfile(_ fields: [String: Any], lists: [String: [[String: Any]]]) throws -> GymProfileModel {
        try Firestore.Decoder().decode(GymProfileModel.self, from: fields.merging(lists.mapValues { $0 as Any }) { $1 })
    }

    private static func encodeItem<T: Encodable>(_ item: T) throws -> [String: Any] {
        try Firestore.Encoder().encode(item)
    }
}

// MARK: - The catalogue

/// The equipment a new profile starts with, as `contracts/firestore/gym_equipment_catalogue.json`
/// holds it for the Dart model, which appends it to a stored profile as Swift's decoder does.
enum GymCatalogueContract {
    /// The profile's equipment lists, in `GymProfileModel.CodingKeys` spelling.
    static let listKeys = [
        "free_weights", "loadable_bars", "fixed_weight_bars", "bands", "body_weights", "support_equipment",
        "accessory_equipment", "loadable_accessory_equipment", "cable_machines", "plate_loaded_machines",
        "pin_loaded_machines"
    ]
    /// The lists of plates, base weights and stacks inside an item.
    private static let nestedKeys = ["range", "baseWeights", "ranges"]
    /// An item's references to one of its nested entries.
    private static let nestedIdKeys = ["defaultBaseWeightId", "chosenBaseWeightId", "defaultRangeId"]

    /// Every list of a new profile. The catalogue gives each nested entry a random id, made per
    /// launch, so each becomes `<item id>_<n>`, references to it included; nothing else changes.
    ///
    /// Band colours are system colours turned into hex as the profile is made, so they follow the
    /// simulator's appearance. The catalogue is recorded in dark, which the fixture and the Dart copy
    /// hold; pinning it keeps a light-mode simulator (CI's default) from failing the contract.
    static func catalogue() throws -> [String: [[String: Any]]] {
        var made: GymProfileModel?
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            made = GymProfileModel(
                id: "catalogue", authorId: "catalogue",
                dateCreated: Date(timeIntervalSince1970: 0), dateModified: Date(timeIntervalSince1970: 0)
            )
        }
        let profile = try #require(made)
        let encoded = try Firestore.Encoder().encode(profile)
        var lists: [String: [[String: Any]]] = [:]
        for key in listKeys {
            lists[key] = (encoded[key] as? [[String: Any]] ?? []).map(withStableNestedIds)
        }
        return lists
    }

    /// The catalogue with each item cut down to its required fields: no image, description or
    /// nested entries. A required Double is set to a fraction, since a whole one (the catalogue's
    /// are) would be recorded as an integer.
    static func cutDownCatalogue() throws -> [String: [[String: Any]]] {
        try catalogue().mapValues { items in
            items.map { item in
                var item = item
                for key in ["imageName", "description"] + nestedIdKeys { item[key] = nil }
                for key in nestedKeys where item[key] != nil { item[key] = [Any]() }
                for key in ["collarWeight", "baseWeight"] where item[key] != nil { item[key] = 2.5 }
                return item
            }
        }
    }

    private static func withStableNestedIds(_ item: [String: Any]) -> [String: Any] {
        var item = item
        let itemId = item["id"] as? String ?? ""
        var renamed: [String: String] = [:]
        for key in nestedKeys {
            guard let entries = item[key] as? [[String: Any]] else { continue }
            item[key] = entries.enumerated().map { index, entry in
                var entry = entry
                let stable = "\(itemId)_\(index + 1)"
                if let old = entry["id"] as? String { renamed[old] = stable }
                entry["id"] = stable
                return entry
            }
        }
        for key in nestedIdKeys {
            if let old = item[key] as? String { item[key] = renamed[old] ?? old }
        }
        return item
    }
}
