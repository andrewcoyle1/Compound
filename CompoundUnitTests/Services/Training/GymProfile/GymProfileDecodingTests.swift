//
//  GymProfileDecodingTests.swift
//  CompoundUnitTests
//
//  A gym profile that fails to decode is skipped by Firestore's listener without a word, and the
//  local cache drops every profile with it. These tests hold the decoder to reading what earlier
//  builds wrote: CompoundUnitTests/Fixtures/gym-profile-v1.json is the mock and a default profile
//  as encoded before tolerant decoding (G1), and every later change to the gym models must keep
//  it readable without losing a stored value.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct GymProfileDecodingTests {

    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/gym-profile-v1.json")

    private func fixtureProfile(_ key: String) throws -> [String: Any] {
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.fixtureURL)) as? [String: Any]
        return try #require(fixture?[key] as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> GymProfileModel {
        try JSONDecoder().decode(GymProfileModel.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func decode(_ json: String) throws -> GymProfileModel {
        try JSONDecoder().decode(GymProfileModel.self, from: Data(json.utf8))
    }

    /// True when `container` holds everything in `expected`: every key of a dictionary with a
    /// matching value, every element of an array in order and no more, and equal leaves. Later
    /// packages add fields, so a re-encoded item may carry keys the fixture does not.
    private static func contains(_ container: Any, _ expected: Any) -> Bool {
        switch (container, expected) {
        case let (container as [String: Any], expected as [String: Any]):
            return expected.allSatisfy { key, value in container[key].map { contains($0, value) } ?? false }
        case let (container as [Any], expected as [Any]):
            return container.count == expected.count && zip(container, expected).allSatisfy { contains($0, $1) }
        default:
            return (container as? NSObject)?.isEqual(expected) ?? false
        }
    }

    // MARK: - The v1 fixture

    /// Decoding then encoding keeps every stored item first, in order, with every key and value it
    /// was saved with. Anything after them must be a catalogue item the stored list lacked,
    /// switched off, which is the merge on decode.
    @Test("Test The V1 Fixture Decodes And Re-encodes Every Stored Value", arguments: ["mock", "default"])
    func testFixtureRoundTrip(profileKey: String) throws {
        let stored = try fixtureProfile(profileKey)
        let profile = try decode(stored)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any]
        let reencoded = try #require(encoded)
        let catalogueIds = Set(GymProfileModel.allEquipmentCatalog.map(\.ref.equipmentId))

        for (key, value) in stored {
            guard let storedItems = value as? [[String: Any]] else {
                #expect(Self.contains(reencoded[key] as Any, value), "\(key)")
                continue
            }
            let items = try #require(reencoded[key] as? [[String: Any]], "\(key)")
            #expect(items.count >= storedItems.count, "\(key)")
            for (new, old) in zip(items, storedItems) {
                #expect(Self.contains(new, old), "\(key) \(old["id"] ?? "")")
            }
            let storedIds = Set(storedItems.compactMap { $0["id"] as? String })
            for extra in items.dropFirst(storedItems.count) {
                let id = extra["id"] as? String ?? ""
                #expect(!storedIds.contains(id) && catalogueIds.contains(id), "\(key) \(id)")
                #expect(extra["isActive"] as? Bool == false, "\(key) \(id)")
            }
        }
    }

    @Test("Test A Profile Missing A List Decodes It As The Catalogue")
    func testMissingListIsTheCatalogue() throws {
        var stored = try fixtureProfile("mock")
        stored["pin_loaded_machines"] = nil

        let profile = try decode(stored)

        let catalogue = PinLoadedMachine.defaultPinLoadedMachines
        #expect(profile.pinLoadedMachines.map(\.id) == catalogue.map(\.id))
        #expect(profile.pinLoadedMachines.map(\.isActive) == catalogue.map(\.isActive))
        #expect(profile.name == "Platinum Gym Malahide")
    }

    @Test("Test A Profile With Only An Id And Author Decodes With Defaults")
    func testMinimalProfile() throws {
        let profile = try decode(#"{"id": "gym-1", "author_id": "author-1"}"#)

        #expect(profile.name.isEmpty)
        #expect(profile.icon == "dumbbell")
        #expect(profile.freeWeights.map(\.id) == FreeWeights.defaultFreeWeights.map(\.id))
        #expect(profile.cableMachines.map(\.id) == CableMachine.defaultCableMachines.map(\.id))
    }

    @Test("Test A Profile Without An Id Still Fails")
    func testIdIsRequired() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"author_id": "author-1"}"#)
        }
    }

    // MARK: - Items

    @Test("Test An Item With An Unknown Field Decodes")
    func testUnknownFieldIsIgnored() throws {
        let profile = try decode(#"""
        {"id": "gym-1", "author_id": "author-1", "pin_loaded_machines": [
            {"id": "custom_stack", "name": "Custom Stack", "isActive": true, "futureField": {"a": 1},
             "ranges": [{"id": "r1", "name": "Main", "minWeight": 5, "maxWeight": 100, "increment": 5,
                         "unit": "kilograms", "isActive": true, "addOns": [2, 2]}]}
        ]}
        """#)

        let machine = try #require(profile.pinLoadedMachines.first)
        #expect(machine.id == "custom_stack")
        #expect(machine.isActive)
        #expect(machine.ranges.map(\.id) == ["r1"])
        #expect(machine.ranges.first?.addOns == [2, 2])
    }

    /// Stacks written before add-ons and uneven stacks (G3) read as plain grids, and the new
    /// fields round-trip.
    @Test("Test Stacks From The V1 Fixture Have No Add-ons Or Uneven Weights")
    func testV1StacksDecodeAsPlainGrids() throws {
        let profile = try decode(try fixtureProfile("mock"))
        let stacks = profile.pinLoadedMachines.flatMap(\.ranges) + profile.cableMachines.flatMap(\.ranges)

        #expect(!stacks.isEmpty)
        #expect(stacks.allSatisfy { $0.addOns.isEmpty && $0.weights == nil })

        var stack = try #require(stacks.first)
        stack.addOns = [2, 2]
        stack.weights = [5, 12.5]
        #expect(try JSONDecoder().decode(WeightStack.self, from: JSONEncoder().encode(stack)) == stack)
    }

    @Test("Test A Corrupt Item Is Skipped And Its Siblings Kept")
    func testCorruptItemIsSkipped() throws {
        let profile = try decode(#"""
        {"id": "gym-1", "author_id": "author-1",
         "pin_loaded_machines": [
            {"id": "custom_stack", "name": "Custom Stack", "isActive": true, "ranges": [
                {"id": "r1", "name": "Main", "minWeight": 5, "maxWeight": 100, "increment": 5, "unit": "kilograms", "isActive": true},
                {"id": "r2", "name": "Broken", "minWeight": "abc", "maxWeight": 100, "increment": 5, "unit": "kilograms", "isActive": true},
                {"id": "r3", "name": "Pounds", "minWeight": 10, "maxWeight": 200, "increment": 10, "unit": "pounds", "isActive": false}
            ]}
         ],
         "plate_loaded_machines": [
            {"id": "custom_broken", "name": "Broken", "baseWeight": "heavy", "unit": "kilograms", "isActive": true},
            {"id": "custom_sled", "name": "Sled", "baseWeight": 30, "unit": "kilograms", "isActive": true}
         ]}
        """#)

        #expect(profile.pinLoadedMachines.first?.ranges.map(\.id) == ["r1", "r3"])
        #expect(profile.plateLoadedMachines.first?.id == "custom_sled")
        #expect(!profile.plateLoadedMachines.contains { $0.id == "custom_broken" })
    }

    @Test("Test An Item Missing Optional Fields Decodes With Defaults")
    func testItemDefaults() throws {
        let profile = try decode(#"""
        {"id": "gym-1", "author_id": "author-1",
         "bands": [{"id": "custom_bands", "name": "Loop Bands",
                    "range": [{"id": "b1", "name": "Red", "availableResistance": 10}]}]}
        """#)

        let bands = try #require(profile.bands.first)
        #expect(bands.id == "custom_bands")
        // A missing isActive reads as off, so a damaged item never offers unconfirmed equipment.
        #expect(!bands.isActive)
        let band = try #require(bands.range.first)
        #expect(band.unit == .kilograms)
        #expect(band.bandColour.isEmpty)
        #expect(!band.isActive)
    }

    // MARK: - Merge on decode

    @Test("Test A Catalogue Machine Missing From A Stored Profile Is Appended Switched Off")
    func testMissingCatalogueItemIsAppended() throws {
        let catalogue = PinLoadedMachine.defaultPinLoadedMachines
        var first = try #require(catalogue.first)
        first.isActive = true
        let stored = GymProfileModel(id: "gym-1", authorId: "author-1", pinLoadedMachines: [first])

        let profile = try JSONDecoder().decode(GymProfileModel.self, from: JSONEncoder().encode(stored))

        #expect(profile.pinLoadedMachines.map(\.id) == catalogue.map(\.id))
        #expect(profile.pinLoadedMachines.map(\.isActive) == [true] + Array(repeating: false, count: catalogue.count - 1))
    }

    // MARK: - Sleeves, plates and collars

    /// A machine saved before sleeves existed takes the catalogue's figure for its type, so the
    /// v1 fixture's T-bar loads on one post; a machine the catalogue does not know takes two.
    @Test("Test A Stored Machine Without Sleeves Takes The Catalogues")
    func testSleevesDefaultFromTheCatalogue() throws {
        let fixture = try decode(fixtureProfile("mock"))
        #expect(fixture.plateLoadedMachines.first { $0.id == "chest-supported_t-bar_row_machine" }?.sleeves == 1)
        #expect(fixture.plateLoadedMachines.first { $0.id == "hack_squat_machine" }?.sleeves == 2)

        let profile = try decode(#"""
        {"id": "gym-1", "author_id": "author-1", "plate_loaded_machines": [
            {"id": "standing_t-bar_row_machine_without_chest_support", "name": "T-Bar", "baseWeight": 18, "unit": "kilograms", "isActive": true},
            {"id": "custom_press", "name": "Press", "baseWeight": 10, "unit": "kilograms", "isActive": true},
            {"id": "custom_post", "name": "Post", "baseWeight": 10, "unit": "kilograms", "sleeves": 1, "isActive": true}
        ]}
        """#)
        let sleeves = Dictionary(profile.plateLoadedMachines.map { ($0.id, $0.sleeves) }, uniquingKeysWith: { first, _ in first })
        #expect(sleeves["standing_t-bar_row_machine_without_chest_support"] == 1)
        #expect(sleeves["custom_press"] == 2)
        #expect(sleeves["custom_post"] == 1)
    }

    /// Before the flag, plates were the items whose id ends in "plates"; counts and collars are
    /// new, so stored entries read as unlimited and collar-less.
    @Test("Test Plates Counts And Collars Decode Without Their Keys")
    func testPlatesCountsAndCollarsDefaults() throws {
        let profile = try decode(#"""
        {"id": "gym-1", "author_id": "author-1",
         "free_weights": [
            {"id": "weight_plates", "name": "Plates", "isActive": true, "range": [{"id": "p1", "availableWeights": 20, "isActive": true}]},
            {"id": "dumbbells", "name": "Dumbbells", "isActive": true, "range": []},
            {"id": "change_discs", "name": "Discs", "isPlates": true, "isActive": true,
             "range": [{"id": "d1", "availableWeights": 0.5, "isActive": true, "count": 4}]}
         ],
         "loadable_bars": [{"id": "barbell", "name": "Barbell", "isActive": true, "baseWeights": []}]}
        """#)

        let items = Dictionary(profile.freeWeights.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        #expect(items["weight_plates"]?.isPlates == true)
        #expect(items["dumbbells"]?.isPlates == false)
        #expect(items["change_discs"]?.isPlates == true)
        #expect(items["weight_plates"]?.range.first?.count == nil)
        #expect(items["change_discs"]?.range.first?.count == 4)
        #expect(profile.loadableBars.first { $0.id == "barbell" }?.collarWeight == 0)
    }

    // MARK: - Equipment index

    @Test("Test The Equipment Index Keeps The First Of Two Items With The Same Ref")
    func testEquipmentIndexWithDuplicates() throws {
        let first = try #require(PinLoadedMachine.defaultPinLoadedMachines.first)
        var second = first
        second.name = "Second Copy"
        let profile = GymProfileModel(authorId: "author-1", pinLoadedMachines: [first, second])

        #expect(profile.equipment(for: first.equipmentRef)?.name == first.name)
    }

    // MARK: - Type ids

    /// Items saved before custom and duplicate machines carry no `typeId`: each is its own type,
    /// so every exercise that named it still finds it.
    @Test("Test Items Without A Type Id Are Their Own Type", arguments: ["mock", "default"])
    func testItemsWithoutATypeIdAreTheirOwnType(profileKey: String) throws {
        let profile = try decode(try fixtureProfile(profileKey))

        #expect(!profile.allEquipment.isEmpty)
        #expect(profile.allEquipment.allSatisfy { $0.ref.equipmentId == $0.instanceId })
    }

    /// A duplicate keeps its own id and its original's type through a save and a load.
    @Test("Test A Duplicate Keeps Its Type Id Through Encoding")
    func testADuplicateKeepsItsTypeIdThroughEncoding() throws {
        var profile = GymProfileModel(authorId: "author-1")
        let copyIdResult = profile.duplicateMachine(in: \.cableMachines, id: "cable_lat_pulldown_machine")
        let copyId = try #require(copyIdResult)

        let decoded = try JSONDecoder().decode(GymProfileModel.self, from: JSONEncoder().encode(profile))

        let copy = try #require(decoded.cableMachines.first { $0.id == copyId })
        #expect(copy.typeId == "cable_lat_pulldown_machine")
        #expect(copy.equipmentRef == EquipmentRef(kind: .cableMachine, id: "cable_lat_pulldown_machine"))
        #expect(decoded.cableMachines.count == profile.cableMachines.count)
    }
}
