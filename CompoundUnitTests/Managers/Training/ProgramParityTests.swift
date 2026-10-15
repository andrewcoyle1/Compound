//
//  ProgramParityTests.swift
//  CompoundUnitTests
//
//  The Flutter app's `program_repository` package ports `MesocycleSchedule` (slots, the next
//  workout, today's entry, the legacy run, deload and periodisation) and `Macrocycle`'s moves
//  (`advanced`, `started`). CompoundUnitTests/Fixtures/program-parity.json holds deterministic
//  cases built here, with what the Swift answers for each: every situation `MesocycleScheduleTests`
//  covers, then seeded random histories over a week-long block. This side checks the fixture still
//  matches the Swift; the Dart side checks its port against the same file.
//
//  Times are milliseconds since 1970 and days are UTC days, so both sides agree whatever the time
//  zone they run in.
//
//  To regenerate after changing the Swift (then update the Dart until it passes):
//
//      TEST_RUNNER_RECORD_PARITY=1 xcodebuild test … \
//        -only-testing:CompoundUnitTests/ProgramParityTests
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct ProgramParityTests {

    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/program-parity.json")

    private static var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_PARITY"] == "1"
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Wednesday 30 September 2026, 09:00 UTC, as `MesocycleScheduleTests`.
    private static let wednesday: Double = 1_790_758_800_000
    private static let hour: Double = 3_600_000
    private static let day: Double = 24 * hour

    @Test("Test The Program Schedule Matches The Parity Fixture")
    func testFixture() throws {
        if Self.isRecording {
            let fixture: [String: Any] = [
                "schedules": Self.scheduleInputs().map { ["input": $0, "expected": Self.schedule($0)] },
                "macrocycles": Self.macrocycleInputs().map { ["input": $0, "expected": Self.macrocycle($0)] }
            ]
            try Self.lines(fixture).write(to: Self.fixtureURL, atomically: true, encoding: .utf8)
            return
        }
        let data = try Data(contentsOf: Self.fixtureURL)
        let fixture = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schedules = try #require(fixture["schedules"] as? [[String: Any]])
        let macrocycles = try #require(fixture["macrocycles"] as? [[String: Any]])
        #expect(schedules.count > 40)
        for (index, testCase) in schedules.enumerated() {
            let actual = Self.schedule(testCase["input"] as? [String: Any] ?? [:])
            #expect(CoachParityTests.matches(actual, testCase["expected"] ?? NSNull()), "schedules[\(index)]: Swift gives \(actual)")
        }
        for (index, testCase) in macrocycles.enumerated() {
            let actual = Self.macrocycle(testCase["input"] as? [String: Any] ?? [:])
            #expect(CoachParityTests.matches(actual, testCase["expected"] ?? NSNull()), "macrocycles[\(index)]: Swift gives \(actual)")
        }
    }

    /// One case per line, so a regenerated file diffs case by case.
    private static func lines(_ fixture: [String: Any]) throws -> String {
        let sections = try fixture.keys.sorted().map { key -> String in
            let cases = try (fixture[key] as? [Any] ?? []).map { testCase in
                String(bytes: try JSONSerialization.data(withJSONObject: testCase, options: [.sortedKeys]), encoding: .utf8) ?? ""
            }
            return "  \"\(key)\": [\n    " + cases.joined(separator: ",\n    ") + "\n  ]"
        }
        return "{\n" + sections.joined(separator: ",\n") + "\n}\n"
    }

    // MARK: - Schedules

    /// A, rest, B, rest, C, rest, rest: the week-long microcycle `MesocycleScheduleTests` uses.
    private static let week: [[String: Any]] = [
        ["id": "a", "name": "A", "rest": false], ["id": "rest 1", "name": "Rest 1", "rest": true],
        ["id": "b", "name": "B", "rest": false], ["id": "rest 2", "name": "Rest 2", "rest": true],
        ["id": "c", "name": "C", "rest": false], ["id": "rest 3", "name": "Rest 3", "rest": true],
        ["id": "rest 4", "name": "Rest 4", "rest": true]
    ]

    private static func at(_ dayOffset: Int, _ hourOfDay: Int = 10) -> Double {
        // Midnight of Wednesday, then the day and hour.
        wednesday - 9 * hour + Double(dayOffset) * day + Double(hourOfDay) * hour
    }

    private static func workout(_ templateId: String, _ dayOffset: Int, _ hourOfDay: Int = 10, mesocycleId: String? = "program-1", name: String? = nil, templated: Bool = true) -> [String: Any] {
        var session: [String: Any] = [
            "id": "\(templateId)-\(dayOffset)-\(hourOfDay)",
            "name": name ?? templateId.uppercased(),
            "createdAt": at(dayOffset, hourOfDay),
            "endedAt": at(dayOffset, hourOfDay),
            "rest": false,
            "deleted": false
        ]
        if templated { session["templateId"] = templateId }
        if let mesocycleId { session["mesocycleId"] = mesocycleId }
        return session
    }

    private static func rest(_ templateId: String, _ dayOffset: Int, _ hourOfDay: Int = 0) -> [String: Any] {
        [
            "id": "\(templateId)-\(dayOffset)-\(hourOfDay)", "name": templateId, "templateId": templateId,
            "mesocycleId": "program-1", "createdAt": at(dayOffset, hourOfDay), "endedAt": at(dayOffset, hourOfDay),
            "rest": true, "deleted": false
        ]
    }

    private static func scenario(
        cycles: Int = 4,
        days: [[String: Any]] = week,
        startedAt: Double? = wednesday,
        skips: [[String: Any]] = [],
        firstMicrocycleIndex: Int = 0,
        sessions: [[String: Any]] = [],
        now: Double = wednesday,
        deload: String = "none",
        periodisation: Bool = false
    ) -> [String: Any] {
        var input: [String: Any] = [
            "days": days, "cycles": cycles, "skips": skips, "firstMicrocycleIndex": firstMicrocycleIndex,
            "sessions": sessions, "now": now, "deload": deload, "periodisation": periodisation
        ]
        if let startedAt { input["startedAt"] = startedAt }
        return input
    }

    private static func scheduleInputs() -> [[String: Any]] {
        let abc = ["a", "b", "c"]
        var inputs: [[String: Any]] = [
            scenario(),
            scenario(now: at(3, 9)),
            scenario(sessions: [workout("a", 0)], now: at(1, 9)),
            scenario(sessions: [workout("a", 0)], now: at(0, 12)),
            scenario(sessions: [workout("a", 0, 10), workout("b", 0, 18)], now: at(0, 20)),
            scenario(sessions: [workout("c", 0)], now: at(0, 12)),
            scenario(sessions: [workout("a", 0), workout("a", 1)], now: at(1, 12)),
            scenario(skips: [["cycleIndex": 0, "position": 0, "templateId": "a"]]),
            scenario(skips: [["cycleIndex": 0, "position": 0, "templateId": "renamed"]]),
            scenario(sessions: [workout("a", 0), workout("b", 2), workout("c", 4)], now: at(5, 9)),
            scenario(cycles: 2, sessions: abc.enumerated().map { workout($1, $0) } + abc.enumerated().map { workout($1, $0 + 3) }, now: at(10, 9)),
            scenario(sessions: [workout("a", -7)]),
            scenario(sessions: [workout("a", 0, mesocycleId: "program-2")], now: at(0, 12)),
            scenario(sessions: [workout("a", 0), rest("rest 1", 1)], now: at(1, 9)),
            scenario(sessions: [workout("a", 0), rest("rest 1", 1)], now: at(0, 20)),
            scenario(sessions: [workout("a", 0), workout("b", 1)], now: at(1, 20)),
            scenario(sessions: [workout("a", 0), workout("b", 0, 12), workout("c", 0, 14), workout("a", 1), rest("rest 1", 2)], now: at(2, 12)),
            scenario(sessions: [workout("a", 0, 10), rest("rest 1", 0, 11)], now: at(0, 12)),
            scenario(startedAt: nil, sessions: [workout("a", -30)]),
            scenario(cycles: 2, startedAt: nil, sessions: (abc + abc + abc + abc + ["a"]).enumerated().map { workout($1, $0) }, now: at(13, 12)),
            scenario(cycles: 2, startedAt: nil, sessions: (abc + abc).enumerated().map { workout($1, $0) }, now: at(6, 12)),
            scenario(firstMicrocycleIndex: 2),
            scenario(firstMicrocycleIndex: 3, sessions: [workout("a", 0)], now: at(0, 12)),
            scenario(sessions: [workout("a", 0), workout("b", 2), workout("c", 4)], now: at(7, 9)),
            scenario(sessions: [workout("a", 0), workout("b", 2), workout("c", 4), workout("a", 7, 8)], now: at(7, 9)),
            scenario(sessions: [workout("a", 0), workout("b", 2), workout("c", 4), workout("a", 7), rest("rest 1", 8, 23)], now: at(8, 9)),
            scenario(sessions: [workout("x", 0, mesocycleId: nil, name: "B", templated: false)], now: at(0, 12)),
            scenario(cycles: 9, deload: "start", periodisation: true),
            scenario(cycles: 4, deload: "end", periodisation: true),
            scenario(cycles: 3, periodisation: true),
            scenario(cycles: 0)
        ]
        inputs += randomInputs(count: 40)
        return inputs
    }

    /// Seeded histories: workouts on the block's days, in or out of order, rest days ticked or
    /// pre-logged, skips, a join point, deleted sessions and another mesocycle's.
    private static func randomInputs(count: Int) -> [[String: Any]] {
        var seed: UInt64 = 20_261_015
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }
        let workouts = ["a", "b", "c"]
        let rests = ["rest 1", "rest 2", "rest 3", "rest 4"]
        return (0..<count).map { index in
            var sessions: [[String: Any]] = []
            let length = next(18)
            for dayOffset in 0..<length {
                switch next(6) {
                case 0, 1, 2:
                    var session = workout(workouts[next(3)], dayOffset, 8 + next(12))
                    if next(10) == 0 { session["deleted"] = true }
                    if next(12) == 0 { session["mesocycleId"] = "program-2" }
                    if next(15) == 0 { session.removeValue(forKey: "endedAt") }
                    sessions.append(session)
                case 3:
                    sessions.append(rest(rests[next(4)], dayOffset + next(2), next(24)))
                default:
                    break
                }
            }
            let skips: [[String: Any]] = (0..<next(3)).map { _ in
                let position = next(week.count)
                return ["cycleIndex": next(3), "position": position, "templateId": week[position]["id"] ?? ""]
            }
            return scenario(
                cycles: 1 + next(4),
                startedAt: index % 7 == 6 ? nil : wednesday - Double(next(2)) * day,
                skips: skips,
                firstMicrocycleIndex: next(4) == 0 ? next(3) : 0,
                sessions: sessions,
                now: at(next(max(length, 1) + 2), next(24)),
                deload: ["none", "start", "end"][next(3)],
                periodisation: next(2) == 0
            )
        }
    }

    private static func date(_ millis: Any?) -> Date? {
        (millis as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
    }

    private static func millis(_ date: Date) -> Double {
        (date.timeIntervalSince1970 * 1000).rounded()
    }

    private static func schedule(_ input: [String: Any]) -> [String: Any] {
        let days = (input["days"] as? [[String: Any]] ?? []).map { day in
            WorkoutTemplateModel(
                id: day["id"] as? String ?? "",
                authorId: "me",
                name: day["name"] as? String ?? "",
                exercises: (day["rest"] as? Bool ?? false) ? [] : [WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)]
            )
        }
        let mesocycle = Mesocycle(
            id: "program-1", authorId: "me", name: "Block", icon: "dumbbell", colour: "#FF0000",
            numMicrocycles: input["cycles"] as? Int ?? 1,
            deload: DeloadType(rawValue: input["deload"] as? String ?? "none") ?? .none,
            periodisation: input["periodisation"] as? Bool ?? false,
            workoutTemplates: days, dateCreated: Date(timeIntervalSince1970: wednesday / 1000)
        )
        let sessions = (input["sessions"] as? [[String: Any]] ?? []).map { session in
            WorkoutSessionModel(
                id: session["id"] as? String ?? "",
                authorId: "me",
                name: session["name"] as? String ?? "",
                workoutTemplateId: session["templateId"] as? String,
                mesocycleId: session["mesocycleId"] as? String,
                dateCreated: date(session["createdAt"]) ?? Date(),
                endedAt: date(session["endedAt"]),
                exercises: [],
                deletedAt: (session["deleted"] as? Bool ?? false) ? date(session["createdAt"]) : nil,
                isRestDay: session["rest"] as? Bool ?? false
            )
        }
        let skips = (input["skips"] as? [[String: Any]] ?? []).map { skip in
            CycleSkip(
                mesocycleIndex: 0, cycleIndex: skip["cycleIndex"] as? Int ?? 0, position: skip["position"] as? Int ?? 0,
                templateId: skip["templateId"] as? String ?? "", date: Date(timeIntervalSince1970: wednesday / 1000)
            )
        }
        var expected: [String: Any] = [:]
        var run: MesocycleSchedule.Run
        if let startedAt = date(input["startedAt"]) {
            run = MesocycleSchedule.Run(mesocycle: mesocycle, startedAt: startedAt)
        } else {
            run = MesocycleSchedule.legacyRun(mesocycle: mesocycle, sessions: sessions)
            expected["legacyStartedAt"] = millis(run.startedAt)
        }
        run.skips = skips
        run.firstMicrocycleIndex = input["firstMicrocycleIndex"] as? Int ?? 0
        let now = date(input["now"]) ?? Date()

        let progress = MesocycleSchedule.progress(of: run, sessions: sessions, now: now)
        expected["slots"] = progress.cycles.map { cycle in
            cycle.map { slot -> String in
                switch slot.state {
                case .open: return "open"
                case .done(let sessionId, let completedAt): return "done:\(sessionId)@\(Int(millis(completedAt)))"
                case .skipped: return "skipped"
                case .beforeStart: return "beforeStart"
                }
            }
        }
        expected["current"] = progress.currentCycleIndex
        expected["next"] = progress.next?.id ?? NSNull()
        expected["complete"] = progress.isMesocycleComplete
        if let today = MesocycleSchedule.todayItem(run: run, sessions: sessions, now: now, calendar: calendar) {
            expected["today"] = [
                "plan": today.dayPlan.id,
                "session": today.completedSessionId ?? NSNull(),
                "cycle": today.cycleIndex ?? NSNull()
            ] as [String: Any]
        } else {
            expected["today"] = NSNull()
        }
        let count = max(mesocycle.numMicrocycles, 1)
        expected["deload"] = (1...count).map { MesocycleSchedule.isDeload(cycleIndex: $0, of: mesocycle) }
        let presenter = ActiveMesocyclePresenter(interactor: ParityInteractor(), router: ParityRouter())
        expected["phases"] = (1...count).map { cycle -> Any in
            switch presenter.currentPeriodisationPhase(cycleIndex: cycle, mesocycle: mesocycle) {
            case .hypertrophy: return "hypertrophy"
            case .strength: return "strength"
            case .power: return "power"
            case nil: return NSNull()
            }
        }
        return expected
    }

    // MARK: - Macrocycles

    private static func macrocycleInputs() -> [[String: Any]] {
        var inputs: [[String: Any]] = []
        for status in ["notStarted", "active", "completed", "ended"] {
            for count in [0, 1, 3] {
                for index in [0, 1, 2] where index < max(count, 1) {
                    for start in [NSNull(), 2] as [Any] {
                        let base: [String: Any] = [
                            "status": status, "count": count, "index": index, "start": start, "iteration": 2
                        ]
                        inputs.append(base.merging(["op": "advance"]) { $1 })
                        inputs.append(base.merging(["op": "start", "mesocycle": index + 1, "microcycle": 0]) { $1 })
                        inputs.append(base.merging(["op": "start", "mesocycle": -1, "microcycle": 3]) { $1 })
                    }
                }
            }
        }
        return inputs
    }

    private static func macrocycle(_ input: [String: Any]) -> [String: Any] {
        let count = input["count"] as? Int ?? 0
        let macrocycle = Macrocycle(
            id: "plan", authorId: "me", name: "Plan",
            mesocycleIds: (0..<count).map { "meso-\($0)" },
            status: Macrocycle.Status(rawValue: input["status"] as? String ?? "") ?? .active,
            mesocycleIndex: input["index"] as? Int ?? 0,
            mesocycleStartedAt: Date(timeIntervalSince1970: wednesday / 1000),
            startMicrocycleIndex: input["start"] as? Int,
            skips: [CycleSkip(mesocycleIndex: 0, cycleIndex: 0, position: 0, templateId: "a", date: Date(timeIntervalSince1970: wednesday / 1000))],
            iteration: input["iteration"] as? Int ?? 1,
            dateCreated: Date(timeIntervalSince1970: wednesday / 1000),
            dateModified: Date(timeIntervalSince1970: wednesday / 1000)
        )
        let now = Date(timeIntervalSince1970: (wednesday + day) / 1000)
        let result = input["op"] as? String == "advance"
            ? macrocycle.advanced(now: now)
            : macrocycle.started(atMesocycle: input["mesocycle"] as? Int ?? 0, microcycle: input["microcycle"] as? Int ?? 0, now: now)
        return [
            "status": result.status.rawValue,
            "index": result.mesocycleIndex,
            "startedAt": millis(result.mesocycleStartedAt),
            "start": result.startMicrocycleIndex ?? NSNull(),
            "skips": result.skips.count,
            "iteration": result.iteration,
            "modified": millis(result.dateModified),
            "current": result.currentMesocycleId ?? NSNull(),
            "last": result.isLastMesocycle
        ]
    }
}

/// The presenter only needs doubles to exist; the phase is pure.
@MainActor
private final class ParityInteractor: SpyGlobalInteractor, ActiveMesocycleInteractor {
    var activeSession: WorkoutSessionModel?
    var workoutSessions: [WorkoutSessionModel] = []
    var activeMesocycleRun: MesocycleSchedule.Run?
    var currentMacrocycle: Macrocycle?
    var currentUser: UserModel?
    func saveWorkoutSession(_ session: WorkoutSessionModel) async throws {}
    func deleteWorkoutSession(id: String) async throws {}
    func skipScheduledWorkout(_ slot: MesocycleSchedule.Slot) async throws {}
    func deleteActiveSession() throws {}
    func deleteMesocycle(mesocycleId: String) async throws {}
}

@MainActor
private final class ParityRouter: ActiveMesocycleRouter {
    let router: AnyRouter = TestRouting.anyRouter
    func showCoach(context: CoachContext) {}
    func showEditMesocycleView(delegate: EditMesocycleDelegate) {}
    func showWorkoutSessionDetailView(delegate: WorkoutSessionDetailDelegate) {}
    func showWorkoutTemplateDetailView(delegate: WorkoutTemplateDetailDelegate) {}
    func showWorkoutTrackerView() {}
}
