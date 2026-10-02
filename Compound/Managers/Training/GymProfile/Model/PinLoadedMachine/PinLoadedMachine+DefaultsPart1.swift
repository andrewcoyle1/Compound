//
//  PinLoadedMachine+Defaults.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

extension PinLoadedMachine {

    static let defaultPinLoadedMachinesPart1: [PinLoadedMachine] = [
        PinLoadedMachine(
            id: "biceps_curl_machine_with_arms_at_side",
            name: "Biceps Curl Machine With Arms At Side",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        PinLoadedMachine(
            id: "chest-supported_pin-loaded_row_machine",
            name: "Chest-Supported Pin-Loaded Row Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        PinLoadedMachine(
            id: "kneeling_lower_trunk_rotation_machine",
            name: "Kneeling Lower Trunk Rotation Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "kneeling_pin-loaded_glute_kickback_machine",
            name: "Kneeling Pin-Loaded Glute Kickback Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "lying_pin-loaded_chest_press_machine",
            name: "Lying Pin-Loaded Chest Press Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "lying_pin-loaded_leg_curl_machine",
            name: "Lying Pin-Loaded Leg Curl Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        PinLoadedMachine(
            id: "multi_hip_machine",
            name: "Multi-Hip Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pec_deck",
            name: "Pec Deck",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        PinLoadedMachine(
            id: "pin-loaded_abdominal_crunch_machine_with_chest_pad",
            name: "Pin-Loaded Abdominal Crunch Machine (With Chest Pad)",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_abdominal_crunch_machine_with_front_handles",
            name: "Pin-Loaded Abdominal Crunch Machine (With Front Handles)",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_abdominal_crunch_machine_with_overhead_handles",
            name: "Pin-Loaded Abdominal Crunch Machine (With Overhead Handles)",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_assisted_pull-up_dip_machine",
            name: "Pin-Loaded Assisted Pull-Up/Dip Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_back_extension_machine",
            name: "Pin-Loaded Back Extension Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_chest_fly_machine_with_arm_pads",
            name: "Pin-Loaded Chest Fly Machine With Arm Pads",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_dip_machine",
            name: "Pin-Loaded Dip Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_hip_thrust_machine",
            name: "Pin-Loaded Hip Thrust Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_leg_extension_machine",
            name: "Pin-Loaded Leg Extension Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        PinLoadedMachine(
            id: "pin-loaded_leg_press_machine",
            name: "Pin-Loaded Leg Press Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        ),
        PinLoadedMachine(
            id: "pin-loaded_overhead_triceps_extension_machine",
            name: "Pin-Loaded Overhead Triceps Extension Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_preacher_curl_machine",
            name: "Pin-Loaded Preacher Curl Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_preacher_curl_triceps_extension_combo_machine",
            name: "Pin-Loaded Preacher Curl/Triceps Extension Combo Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: false
        ),
        PinLoadedMachine(
            id: "pin-loaded_pulldown_machine",
            name: "Pin-Loaded Pulldown Machine",
            description: nil,
            ranges: [
                PinLoadedMachineRange(
                    id: UUID().uuidString,
                    name: "Range 1",
                    minWeight: 0,
                    maxWeight: 300,
                    increment: 5,
                    unit: .pounds,
                    isActive: true
                )
            ],
            isActive: true
        )
    ]
}
