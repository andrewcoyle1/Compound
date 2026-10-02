import Foundation

struct ExerciseSettingsModel: DataSyncModelProtocol {

    var id: String           // exerciseTemplateId
    var authorId: String
    var note: String?
    var restDurationOverride: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case note
        case restDurationOverride = "rest_duration_override"
    }

    init(id: String, authorId: String) {
        self.id = id
        self.authorId = authorId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        restDurationOverride = try container.decodeIfPresent(Int.self, forKey: .restDurationOverride)
    }

    var eventParameters: [String: Any] { [:] }

    static var mock: Self {
        self.mocks[0]
    }
    
    static var mocks: [Self] {
        [
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123"),
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123"),
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123"),
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123"),
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123"),
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123"),
            ExerciseSettingsModel(id: UUID().uuidString, authorId: "mock_user_123")
        ]
    }
}
