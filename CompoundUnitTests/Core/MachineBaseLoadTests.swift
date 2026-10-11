//
//  MachineBaseLoadTests.swift
//  CompoundUnitTests
//
//  A plate-loaded machine set to enter plates only (`PlateLoadedMachine.excludesBaseFromLoad`):
//  10 kg typed on a 7 kg hack squat is recorded as 17 kg and shown as 10 everywhere.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

@MainActor
struct MachineBaseLoadTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let hackSquat = [EquipmentRef(kind: .plateLoadedMachine, id: "hack_squat")]

    private func gym(excludesBase: Bool = true, isActive: Bool = true, base: Double = 7) -> GymProfileModel {
        GymProfileModel(
            id: "gym-1", authorId: "a", freeWeights: [], loadableBars: [], fixedWeightBars: [], bands: [], bodyWeights: [],
            cableMachines: [],
            plateLoadedMachines: [PlateLoadedMachine(
                id: "hack_squat", name: "Hack Squat", baseWeight: base, unit: .kilograms,
                excludesBaseFromLoad: excludesBase, isActive: isActive
            )],
            pinLoadedMachines: []
        )
    }

    private func set(_ id: String, weightKg: Double?, logged: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "a", index: 1, reps: 8, weightKg: weightKg, isWarmup: false, completedAt: logged ? start : nil, dateCreated: start)
    }

    @Test func theBaseIsTheActiveMachinesWhenItEntersPlatesOnly() {
        #expect(SessionLoadChoice.machineBaseKg(refs: hackSquat, gym: gym()) == 7)
        #expect(SessionLoadChoice.machineBaseKg(refs: hackSquat, gym: gym(excludesBase: false)) == nil)
        #expect(SessionLoadChoice.machineBaseKg(refs: hackSquat, gym: gym(isActive: false)) == nil)
        #expect(SessionLoadChoice.machineBaseKg(refs: hackSquat, gym: gym(base: 0)) == nil)
        #expect(SessionLoadChoice.machineBaseKg(refs: [EquipmentRef(kind: .loadableBar, id: "barbell")], gym: gym()) == nil)
    }

    /// Sets still to do follow the exercise's base, logged ones keep the one they were logged on.
    @Test func setsStillToDoCarryTheExercisesBase() {
        var logged = set("logged", weightKg: 17, logged: true)
        logged.machineBaseKg = 7
        var exercise = WorkoutExerciseModel(
            id: "e", authorId: "a", templateId: "hack", name: "Hack Squat", trackingMode: .weightReps, index: 1,
            sets: [logged, set("next", weightKg: 17)], machineBaseKg: 7
        )
        #expect(exercise.sets.map(\.loadKg) == [10, 10])
        exercise.machineBaseKg = nil
        #expect(exercise.sets.map(\.loadKg) == [10, 17])
        exercise.sets.append(set("added", weightKg: 20))
        exercise.machineBaseKg = 5
        #expect(exercise.sets.map(\.loadKg) == [10, 12, 15])
    }

    /// Typed as the load, stored as the total, read back as the load.
    @Test func theKeyboardTypesTheLoad() {
        let box = GymEquipmentBox(set("s", weightKg: nil))
        box.value.machineBaseKg = 7
        let keyboard = SetKeyboardPresenter()
        keyboard.open(.weight, set: box.binding, context: SetKeyboardContext(lastSetWeightKg: 17))
        keyboard.type("1")
        keyboard.type("0")
        #expect(box.value.weightKg == 17)
        #expect(keyboard.text == "10")
        #expect(keyboard.weightChips.first?.title == "Last set 10")
        keyboard.close()
        #expect(keyboard.displayText(for: .weight, set: box.value, unit: .kilograms) == "10")
    }

    @Test func aStoredMachineEntersPlatesOnly() throws {
        let data = Data(#"{"id":"hack_squat","name":"Hack Squat","baseWeight":7,"unit":"kilograms","isActive":true}"#.utf8)
        #expect(try JSONDecoder().decode(PlateLoadedMachine.self, from: data).excludesBaseFromLoad)
    }

    /// A record is beaten on the total and described as the load.
    @Test func aRecordReadsAsTheLoad() {
        func session(_ id: String, kilograms: Double, at date: Date) -> WorkoutSessionModel {
            var logged = set("\(id)-s", weightKg: kilograms, logged: true)
            logged.machineBaseKg = 7
            return WorkoutSessionModel(
                id: id, authorId: "a", name: "Legs", dateCreated: date, endedAt: date,
                exercises: [WorkoutExerciseModel(
                    id: "\(id)-e", authorId: "a", templateId: "hack", name: "Hack Squat", trackingMode: .weightReps, index: 1, sets: [logged]
                )]
            )
        }
        let records = WorkoutSessionHighlights.personalRecords(
            in: session("now", kilograms: 27, at: start),
            priorSessions: [session("before", kilograms: 17, at: start.addingTimeInterval(-86_400))]
        )
        #expect(records.first?.detail.hasPrefix(Format.weight(kg: 20, unit: ExerciseWeightUnit.kilograms)) == true)
    }
}
