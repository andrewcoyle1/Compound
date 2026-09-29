//
//  ShareModel.swift
//  DialedIn
//

import Foundation

/// `shares/{id}`: a workout template or program one user sent another, carried whole so the
/// recipient can read it without access to the sender's library. The recipient answers by writing
/// `status`; accepting also copies the payload into their own library.
struct ShareModel: Codable, Identifiable, Sendable {

    enum Status: String, Codable, Sendable {
        case pending
        case accepted
        case dismissed
    }

    enum Payload: Sendable {
        case template(WorkoutTemplateModel)
        case program(TrainingProgram)

        var kind: String {
            switch self {
            case .template: "template"
            case .program: "program"
            }
        }

        var name: String {
            switch self {
            case .template(let template): template.name
            case .program(let program): program.name
            }
        }
    }

    let id: String
    let fromUserId: String
    let toUserId: String
    let payload: Payload
    let dateCreated: Date
    var status: Status

    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        toUserId: String,
        payload: Payload,
        dateCreated: Date = .now,
        status: Status = .pending
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.payload = payload
        self.dateCreated = dateCreated
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case kind
        case payload
        case dateCreated = "date_created"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fromUserId = try container.decode(String.self, forKey: .fromUserId)
        toUserId = try container.decode(String.self, forKey: .toUserId)
        dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        status = try container.decode(Status.self, forKey: .status)
        switch try container.decode(String.self, forKey: .kind) {
        case "program": payload = .program(try container.decode(TrainingProgram.self, forKey: .payload))
        default: payload = .template(try container.decode(WorkoutTemplateModel.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fromUserId, forKey: .fromUserId)
        try container.encode(toUserId, forKey: .toUserId)
        try container.encode(payload.kind, forKey: .kind)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(status, forKey: .status)
        switch payload {
        case .template(let template): try container.encode(template, forKey: .payload)
        case .program(let program): try container.encode(program, forKey: .payload)
        }
    }
}

extension ShareModel {
    /// Two pending shares to the mock user: a template from Alice and a program from Charlie.
    static var mocks: [ShareModel] {
        [
            ShareModel(
                id: "mock_share_template",
                fromUserId: "user1",
                toUserId: "mock_user_123",
                payload: .template(WorkoutTemplateModel.userMocks.first ?? .mock),
                dateCreated: Date(timeIntervalSinceNow: -3600)
            ),
            ShareModel(
                id: "mock_share_program",
                fromUserId: "user3",
                toUserId: "mock_user_123",
                payload: .program(.mock),
                dateCreated: Date(timeIntervalSinceNow: -7200)
            )
        ]
    }
}

/// Turns a shared payload into the recipient's own copy: new ids, the recipient as author.
///
/// Exercises the recipient can already see (the seeded library, or one of their own) keep their
/// id. Anything else is the sender's custom exercise, which lives in the top-level
/// `exercise_templates` collection under the sender's id — the recipient cannot write that
/// document — so it is copied under a new id and the template points at the copy.
enum SharedItemCopier {

    struct Result {
        let payload: ShareModel.Payload
        let newExercises: [ExerciseModel]
    }

    static func copy(_ payload: ShareModel.Payload, recipientId: String, library: [ExerciseModel]) -> Result {
        let known = Set(library.map(\.id))
        var copied: [String: ExerciseModel] = [:]

        func copyExercise(_ exercise: ExerciseModel) -> ExerciseModel {
            if exercise.isSystemExercise || known.contains(exercise.id) { return exercise }
            if let existing = copied[exercise.id] { return existing }
            var copy = exercise
            copy.id = UUID().uuidString
            copy.authorId = recipientId
            copy.dateCreated = .now
            copy.dateModified = .now
            copied[exercise.id] = copy
            return copy
        }

        func copyTemplate(_ template: WorkoutTemplateModel) -> WorkoutTemplateModel {
            WorkoutTemplateModel(
                authorId: recipientId,
                name: template.name,
                description: template.description,
                imageURL: template.imageURL,
                exercises: template.exercises.map { item in
                    var item = item
                    item.id = UUID().uuidString
                    item.exercise = copyExercise(item.exercise)
                    return item
                }
            )
        }

        let result: ShareModel.Payload
        switch payload {
        case .template(let template):
            result = .template(copyTemplate(template))
        case .program(let program):
            result = .program(TrainingProgram(
                authorId: recipientId,
                name: program.name,
                icon: program.icon,
                colour: program.colour,
                numMicrocycles: program.numMicrocycles,
                deload: program.deload,
                periodisation: program.periodisation,
                workoutTemplates: program.workoutTemplates.map(copyTemplate)
            ))
        }
        return Result(payload: result, newExercises: Array(copied.values))
    }
}
