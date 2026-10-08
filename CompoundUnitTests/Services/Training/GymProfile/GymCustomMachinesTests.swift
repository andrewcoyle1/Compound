//
//  GymCustomMachinesTests.swift
//  CompoundUnitTests
//
//  A gym can hold two of one machine (two lat pulldowns) and machines of its own. Exercises still
//  name catalogue types, so these tests pin how an instance answers for its type: the first one
//  switched on drives the keyboard, a duplicate makes its type available, and a machine of the
//  user's own becomes a type an exercise can be made with.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct GymCustomMachinesTests {

    private static let latPulldown = "cable_lat_pulldown_machine"
    private static let latPulldownRef = EquipmentRef(kind: .cableMachine, id: latPulldown)

    private func pulldown(id: String, increment: Double, isActive: Bool = true) -> CableMachine {
        CableMachine(
            id: id,
            typeId: Self.latPulldown,
            name: "Lat Pulldown",
            ranges: [WeightStack(id: "s-\(id)", name: "Stack", minWeight: 5, maxWeight: 50, increment: increment, unit: .kilograms, isActive: true)],
            isActive: isActive
        )
    }

    // MARK: - Resolving

    @Test("Test The First Active Machine Of A Type Drives The Keyboard")
    func testTheFirstActiveMachineOfATypeDrivesTheKeyboard() {
        let profile = GymProfileModel(authorId: "u", cableMachines: [
            pulldown(id: Self.latPulldown, increment: 5),
            pulldown(id: "second", increment: 2.5)
        ])

        let step = WeightStepper.steps(for: [Self.latPulldownRef], profile: profile, unit: .kilograms)

        #expect(step.next(after: 5) == 10)
    }

    @Test("Test Switching The First Off Lets The Second Drive The Keyboard")
    func testSwitchingTheFirstOffLetsTheSecondDriveTheKeyboard() {
        let profile = GymProfileModel(authorId: "u", cableMachines: [
            pulldown(id: Self.latPulldown, increment: 5, isActive: false),
            pulldown(id: "second", increment: 2.5)
        ])

        let step = WeightStepper.steps(for: [Self.latPulldownRef], profile: profile, unit: .kilograms)

        #expect(step.next(after: 5) == 7.5)
    }

    @Test("Test The Equipment Index Holds Duplicates Under One Ref")
    func testTheEquipmentIndexHoldsDuplicatesUnderOneRef() {
        let profile = GymProfileModel(authorId: "u", cableMachines: [
            pulldown(id: Self.latPulldown, increment: 5),
            pulldown(id: "second", increment: 2.5)
        ])

        let pulldowns = profile.allEquipment.filter { $0.ref == Self.latPulldownRef }
        #expect(pulldowns.count == 2)
        #expect(Set(pulldowns.map(\.id)).count == 2)
        #expect(profile.equipmentIndex.count == Set(profile.allEquipment.map(\.ref)).count)
        #expect(profile.equipment(for: Self.latPulldownRef)?.instanceId == Self.latPulldown)
    }

    // MARK: - Duplicating

    @Test("Test Duplicating Copies The Machine Beside The Original")
    func testDuplicatingCopiesTheMachineBesideTheOriginal() throws {
        var profile = GymProfileModel(authorId: "u")
        let index = try #require(profile.cableMachines.firstIndex { $0.id == Self.latPulldown })
        let original = profile.cableMachines[index]

        let copyIdResult = profile.duplicateMachine(in: \.cableMachines, id: Self.latPulldown)

        let copyId = try #require(copyIdResult)

        let copy = profile.cableMachines[index + 1]
        #expect(copy.id == copyId)
        #expect(copy.id != original.id)
        #expect(copy.typeId == Self.latPulldown)
        #expect(copy.name == "\(original.name) 2")
        #expect(copy.ranges.map(\.maxWeight) == original.ranges.map(\.maxWeight))
        #expect(copy.isCustom)
        #expect(!original.isCustom)
    }

    @Test("Test A Second Duplicate Takes The Next Free Number")
    func testASecondDuplicateTakesTheNextFreeNumber() throws {
        var profile = GymProfileModel(authorId: "u")
        profile.duplicateMachine(in: \.cableMachines, id: Self.latPulldown)
        profile.duplicateMachine(in: \.cableMachines, id: Self.latPulldown)

        let names = profile.cableMachines.filter { $0.typeId == Self.latPulldown }.map(\.name)

        #expect(names == ["Cable Lat Pulldown Machine", "Cable Lat Pulldown Machine 3", "Cable Lat Pulldown Machine 2"])
    }

    // MARK: - Adding

    @Test("Test A Machine Added As A Catalogue Type Takes Its Loading")
    func testAMachineAddedAsACatalogueTypeTakesItsLoading() throws {
        var profile = GymProfileModel(authorId: "u")
        let catalogue = try #require(CableMachine.catalogue.first { $0.id == Self.latPulldown })

        let idResult = profile.addMachine(kind: .cableMachine, name: "Hammer Pulldown", worksAs: Self.latPulldown)

        let id = try #require(idResult)

        let machine = try #require(profile.cableMachines.last)
        #expect(machine.id == id)
        #expect(machine.typeId == Self.latPulldown)
        #expect(machine.name == "Hammer Pulldown")
        #expect(machine.isActive)
        #expect(machine.ranges.map(\.id) == catalogue.ranges.map(\.id))
        #expect(machine.defaultRangeId == catalogue.defaultRangeId)
    }

    @Test("Test A Machine Added On Its Own Is Its Own Type", arguments: [EquipmentKind.cableMachine, .pinLoadedMachine, .plateLoadedMachine])
    func testAMachineAddedOnItsOwnIsItsOwnType(kind: EquipmentKind) throws {
        var profile = GymProfileModel(authorId: "u")

        let idResult = profile.addMachine(kind: kind, name: "Garage Contraption", worksAs: nil)

        let id = try #require(idResult)

        let item = try #require(profile.allEquipment.first { $0.instanceId == id })
        #expect(item.ref == EquipmentRef(kind: kind, id: id))
        #expect(item.name == "Garage Contraption")
        #expect(item.isActive)
        // It has loading to resolve: a stack or a base, not the 2.5 kg fallback.
        #expect(WeightStepper.steps(for: [item.ref], profile: profile, unit: .kilograms).constrainsWeight)
    }

    @Test("Test Only Machines Can Be Added")
    func testOnlyMachinesCanBeAdded() {
        var profile = GymProfileModel(authorId: "u")

        #expect(profile.addMachine(kind: .freeWeight, name: "Rocks", worksAs: nil) == nil)
    }

    // MARK: - Deleting

    @Test("Test A Machine Of The User's Own Can Be Deleted")
    func testAMachineOfTheUsersOwnCanBeDeleted() throws {
        var profile = GymProfileModel(authorId: "u")
        let count = profile.pinLoadedMachines.count
        let idResult = profile.addMachine(kind: .pinLoadedMachine, name: "Mine", worksAs: nil)
        let id = try #require(idResult)

        profile.deleteMachine(kind: .pinLoadedMachine, id: id)

        #expect(profile.pinLoadedMachines.count == count)
        #expect(!profile.pinLoadedMachines.contains { $0.id == id })
    }

    @Test("Test A Catalogue Machine Cannot Be Deleted")
    func testACatalogueMachineCannotBeDeleted() {
        var profile = GymProfileModel(authorId: "u")
        let count = profile.cableMachines.count

        profile.deleteMachine(kind: .cableMachine, id: Self.latPulldown)

        #expect(profile.cableMachines.count == count)
    }

    /// The merge on decode appends catalogue ids a stored list lacks. A deleted machine of the
    /// user's own has an id the catalogue never had, so it stays deleted.
    @Test("Test A Deleted Machine Does Not Come Back On Decode")
    func testADeletedMachineDoesNotComeBackOnDecode() throws {
        var profile = GymProfileModel(authorId: "u")
        let idResult = profile.duplicateMachine(in: \.cableMachines, id: Self.latPulldown)
        let id = try #require(idResult)
        profile.deleteMachine(kind: .cableMachine, id: id)

        let decoded = try JSONDecoder().decode(GymProfileModel.self, from: JSONEncoder().encode(profile))

        #expect(!decoded.cableMachines.contains { $0.id == id })
        #expect(decoded.cableMachines.count == CableMachine.catalogue.count)
    }

    // MARK: - Exercise creation

    @Test("Test A Machine Of The User's Own Becomes An Equipment Type")
    func testAMachineOfTheUsersOwnBecomesAnEquipmentType() throws {
        var home = GymProfileModel(authorId: "u")
        let ownIdResult = home.addMachine(kind: .plateLoadedMachine, name: "Garage Sled", worksAs: nil)
        let ownId = try #require(ownIdResult)
        home.addMachine(kind: .cableMachine, name: "Hammer Pulldown", worksAs: Self.latPulldown)
        home.duplicateMachine(in: \.cableMachines, id: Self.latPulldown)
        // The same profile twice stands in for two gyms that share a machine.
        let types = GymProfileModel.equipmentTypes(including: [home, home])

        let ownRef = EquipmentRef(kind: .plateLoadedMachine, id: ownId)
        #expect(types.count == GymProfileModel.allEquipmentCatalog.count + 1)
        #expect(types.filter { $0.ref == ownRef }.count == 1)
        #expect(types.name(for: ownRef) == "Garage Sled")
        #expect(types.name(for: Self.latPulldownRef) == "Cable Lat Pulldown Machine")
        #expect(types.name(for: EquipmentRef(kind: .cableMachine, id: "gone")) == "gone")
    }
}
