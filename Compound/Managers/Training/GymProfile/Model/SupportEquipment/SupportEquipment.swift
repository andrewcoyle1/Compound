//
//  SupportEquipment.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct SupportEquipment: Identifiable, Codable {
    var id: String
    var name: String
    var imageName: String?
    var description: String?
    
    var isActive: Bool
    
    init(
        id: String,
        name: String,
        imageName: String? = nil,
        description: String? = nil,
        isActive: Bool
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.description = description
        self.isActive = isActive
    }
    
    static let defaultSupportEquipment: [SupportEquipment] = [
        SupportEquipment(
            id: "adjustable_bench",
            name: "Adjustable Bench",
            imageName: "adjustable_bench_icon",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "captains_chair",
            name: "Captain's Chair",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "decline_bench",
            name: "Decline Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "decline_bench_press_station",
            name: "Decline Bench Press Station",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "flat_bench",
            name: "Flat Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "flat_bench_press_station",
            name: "Flat Bench Press Station",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "glute_ham_developer",
            name: "Glute Ham Developer",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "hip_thrust_bench",
            name: "Hip Thrust Bench",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "incline_bench_press_station",
            name: "Incline Bench Press Station",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "multi-grip_pull-up_bar",
            name: "Multi-Grip Pull-Up Bar",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "nordic_hamstring_curl_bench",
            name: "Nordic Hamstring Curl Bench",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "parallel_bars",
            name: "Parallel Bars",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "power_rack",
            name: "Power Rack",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "preacher_curl_bench",
            name: "Preacher Curl Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "roman_chair",
            name: "Roman Chair",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "seal_row_bench",
            name: "Seal Row Bench",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "seated_bench",
            name: "Seated Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "seated_overhead_press_station",
            name: "Seated Overhead Press Station",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "squat_stand",
            name: "Squat Stand",
            description: nil,
            isActive: false
        )
    ]
    
    static var mock: SupportEquipment {
        mocks[0]
    }
    
    static let mocks: [SupportEquipment] = [
        SupportEquipment(
            id: "adjustable_bench",
            name: "Adjustable Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "captains_chair",
            name: "Captain's Chair",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "decline_bench",
            name: "Decline Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "decline_bench_press_station",
            name: "Decline Bench Press Station",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "flat_bench",
            name: "Flat Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "flat_bench_press_station",
            name: "Flat Bench Press Station",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "glute_ham_developer",
            name: "Glute Ham Developer",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "hip_thrust_bench",
            name: "Hip Thrust Bench",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "incline_bench_press_station",
            name: "Incline Bench Press Station",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "multi-grip_pull-up_bar",
            name: "Multi-Grip Pull-Up Bar",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "nordic_hamstring_curl_bench",
            name: "Nordic Hamstring Curl Bench",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "parallel_bars",
            name: "Parallel Bars",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "power_rack",
            name: "Power Rack",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "preacher_curl_bench",
            name: "Preacher Curl Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "roman_chair",
            name: "Roman Chair",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "seal_row_bench",
            name: "Seal Row Bench",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "seated_bench",
            name: "Seated Bench",
            description: nil,
            isActive: true
        ),
        SupportEquipment(
            id: "seated_overhead_press_station",
            name: "Seated Overhead Press Station",
            description: nil,
            isActive: false
        ),
        SupportEquipment(
            id: "squat_stand",
            name: "Squat Stand",
            description: nil,
            isActive: false
        )
    ]

}

// MARK: - Decoding

extension SupportEquipment {
    /// The keys match the property names, which is the wire format these items have always had.
    /// The id and name are required; a missing `isActive` reads as off, so a damaged item never
    /// offers equipment the user did not confirm. See `GymEquipmentDecoding.swift`.
    enum CodingKeys: String, CodingKey {
        case id, name, imageName, description, isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}
