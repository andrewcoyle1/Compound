//
//  AccessoryEquipment.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

struct AccessoryEquipment: Identifiable, Codable {
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
    
    static let defaultAccessoryEquipment: [AccessoryEquipment] = [
        AccessoryEquipment(
            id: "ab_wheel",
            name: "Ab Wheel",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "aerobic_steps",
            name: "Aerobic Steps",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "anchor_point_for_elastic_band",
            name: "Anchor Point For Elastic Band",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "anchor_point_for_suspension_trainer",
            name: "Anchor Point For Suspension Trainer",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "bench_press_board_block",
            name: "Bench Press Board/Block",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "calf_raise_block",
            name: "Calf Raise Block",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "cuff_cable_attachment",
            name: "Cuff Cable Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "deadlift_blocks",
            name: "Deadlift Blocks",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "gymnastics_rings",
            name: "Gymnastics Rings",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "landmine_attachment_wall_corner",
            name: "Landmine Attachment/Wall Corner",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "neutral_grip_landmine_row_attachment",
            name: "Neutral Grip Landmine Row Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "nordic_hamstring_curl_strap",
            name: "Nordic Hamstring Curl Strap",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "overhand_grip_landmine_attachment",
            name: "Overhand Grip Landmine Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "plyometric_boxes",
            name: "Plyometric Boxes",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "pull_up_bar",
            name: "Pull-Up Bar",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "push_up_handles",
            name: "Push-Up Handles",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "slant_board",
            name: "Slant Board",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "slingshot",
            name: "Slingshot",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "split_squat_roller_stand",
            name: "Split Squat Roller Stand",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "squat_box",
            name: "Squat Box",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "stability_ball",
            name: "Stability Ball",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "staircase",
            name: "Staircase",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "suspension_trainer",
            name: "Suspension Trainer",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "v_bar_row_grip_attachment",
            name: "V-Bar Row Grip Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "yoga_blocks",
            name: "Yoga Blocks",
            description: nil,
            isActive: true
        )
    ]
    
    static var mock: AccessoryEquipment {
        mocks[0]
    }
    
    static let mocks: [AccessoryEquipment] = [
        AccessoryEquipment(
            id: "ab_wheel",
            name: "Ab Wheel",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "aerobic_steps",
            name: "Aerobic Steps",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "anchor_point_for_elastic_band",
            name: "Anchor Point For Elastic Band",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "anchor_point_for_suspension_trainer",
            name: "Anchor Point For Suspension Trainer",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "bench_press_board_block",
            name: "Bench Press Board/Block",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "calf_raise_block",
            name: "Calf Raise Block",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "cuff_cable_attachment",
            name: "Cuff Cable Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "deadlift_blocks",
            name: "Deadlift Blocks",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "gymnastics_rings",
            name: "Gymnastics Rings",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "landmine_attachment_wall_corner_attachment",
            name: "Landmine Attachment/Wall Corner",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "neutral_grip_landmine_row_attachment",
            name: "Neutral Grip Landmine Row Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "nordic_hamstring_curl_strap",
            name: "Nordic Hamstring Curl Strap",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "overhand_grip_landmine_row_attachment",
            name: "Overhand Grip Landmine Row Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "plyometric_boxes",
            name: "Plyometric Boxes",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "pull_up_bar",
            name: "Pull-Up Bar",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "push_up_handles",
            name: "Push-Up Handles",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "slant_board",
            name: "Slant Board",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "slingshot",
            name: "Slingshot",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "split_squat_roller_stand",
            name: "Split Squat Roller Stand",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "squat_box",
            name: "Squat Box",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "stability_ball",
            name: "Stability Ball",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "staircase",
            name: "Staircase",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "suspension_trainer",
            name: "Suspension Trainer",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "v_bar_row_grip_attachment",
            name: "V-Bar Row Grip Attachment",
            description: nil,
            isActive: true
        ),
        AccessoryEquipment(
            id: "yoga_blocks",
            name: "Yoga Blocks",
            description: nil,
            isActive: true
        )
    ]
}
