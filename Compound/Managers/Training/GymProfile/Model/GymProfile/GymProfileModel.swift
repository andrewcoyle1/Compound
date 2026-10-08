//
//  GymProfileModel.swift
//  Compound
//
//  Created by Andrew Coyle on 20/01/2026.
//

import SwiftUI

struct GymProfileModel: DataSyncModelProtocol {
    
    var id: String
    var authorId: String
    var name: String
    private(set) var imageUrl: String?
    var icon: String
    var dateCreated: Date
    var dateModified: Date
    var deletedAt: Date?
    
    var freeWeights: [FreeWeights] = FreeWeights.defaultFreeWeights
    var loadableBars: [LoadableBars] = LoadableBars.defaultLoadableBars
    var fixedWeightBars: [FixedWeightBars] = FixedWeightBars.defaultFixedWeightBars
    var bands: [Bands] = Bands.defaultBands
    var bodyWeights: [BodyWeights] = BodyWeights.defaultBodyWeights
    var supportEquipment: [SupportEquipment] = SupportEquipment.defaultSupportEquipment
    var accessoryEquipment: [AccessoryEquipment] = AccessoryEquipment.defaultAccessoryEquipment
    var loadableAccessoryEquipment: [LoadableAccessoryEquipment] = LoadableAccessoryEquipment.defaultLoadableAccessoryEquipment
    var cableMachines: [CableMachine] = CableMachine.defaultCableMachines
    var plateLoadedMachines: [PlateLoadedMachine] = PlateLoadedMachine.defaultPlateLoadedMachines
    var pinLoadedMachines: [PinLoadedMachine] = PinLoadedMachine.defaultPinLoadedMachines
    
    init(
        id: String = UUID().uuidString,
        authorId: String,
        name: String = "",
        imageUrl: String? = nil,
        icon: String = "dumbell",
        dateCreated: Date = Date.now,
        dateModified: Date = Date.now,
        deletedAt: Date? = nil,
        freeWeights: [FreeWeights] = FreeWeights.defaultFreeWeights,
        loadableBars: [LoadableBars] = LoadableBars.defaultLoadableBars,
        fixedWeightBars: [FixedWeightBars] = FixedWeightBars.defaultFixedWeightBars,
        bands: [Bands] = Bands.defaultBands,
        bodyWeights: [BodyWeights] = BodyWeights.defaultBodyWeights,
        supportEquipment: [SupportEquipment] = SupportEquipment.defaultSupportEquipment,
        accessoryEquipment: [AccessoryEquipment] = AccessoryEquipment.defaultAccessoryEquipment,
        loadableAccessoryEquipment: [LoadableAccessoryEquipment] = LoadableAccessoryEquipment.defaultLoadableAccessoryEquipment,
        cableMachines: [CableMachine] = CableMachine.defaultCableMachines,
        plateLoadedMachines: [PlateLoadedMachine] = PlateLoadedMachine.defaultPlateLoadedMachines,
        pinLoadedMachines: [PinLoadedMachine] = PinLoadedMachine.defaultPinLoadedMachines
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.imageUrl = imageUrl
        self.icon = icon
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.deletedAt = deletedAt
        self.freeWeights = freeWeights
        self.loadableBars = loadableBars
        self.fixedWeightBars = fixedWeightBars
        self.bands = bands
        self.bodyWeights = bodyWeights
        self.supportEquipment = supportEquipment
        self.accessoryEquipment = accessoryEquipment
        self.loadableAccessoryEquipment = loadableAccessoryEquipment
        self.cableMachines = cableMachines
        self.plateLoadedMachines = plateLoadedMachines
        self.pinLoadedMachines = pinLoadedMachines
    }
    
    mutating func updateImageUrl(imageUrl: String) {
        self.imageUrl = imageUrl
        self.dateModified = Date.now
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case imageUrl = "image_url"
        case authorId = "author_id"
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case deletedAt = "deleted_at"
        case freeWeights = "free_weights"
        case loadableBars = "loadable_bars"
        case fixedWeightBars = "fixed_weight_bars"
        case bands
        case bodyWeights = "body_weights"
        case supportEquipment = "support_equipment"
        case accessoryEquipment = "accessory_equipment"
        case loadableAccessoryEquipment = "loadable_accessory_equipment"
        case cableMachines = "cable_machines"
        case plateLoadedMachines = "plate_loaded_machines"
        case pinLoadedMachines = "pin_loaded_machines"
    }

    /// Only the id and author are required. Everything else falls back to a default, and each
    /// equipment list skips items it cannot read and gains any catalogue items it lacks, so a
    /// profile saved by an older or newer build still loads. `encode(to:)` stays synthesized,
    /// which keeps the keys written unchanged.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorId = try container.decode(String.self, forKey: .authorId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "dumbbell"
        dateCreated = try container.decodeIfPresent(Date.self, forKey: .dateCreated) ?? .now
        dateModified = try container.decodeIfPresent(Date.self, forKey: .dateModified) ?? .now
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        freeWeights = .mergingCatalogue(
            container.decodeLossyArray(FreeWeights.self, forKey: .freeWeights),
            FreeWeights.defaultFreeWeights
        )
        loadableBars = .mergingCatalogue(
            container.decodeLossyArray(LoadableBars.self, forKey: .loadableBars),
            LoadableBars.defaultLoadableBars
        )
        fixedWeightBars = .mergingCatalogue(
            container.decodeLossyArray(FixedWeightBars.self, forKey: .fixedWeightBars),
            FixedWeightBars.defaultFixedWeightBars
        )
        bands = .mergingCatalogue(container.decodeLossyArray(Bands.self, forKey: .bands), Bands.defaultBands)
        bodyWeights = .mergingCatalogue(
            container.decodeLossyArray(BodyWeights.self, forKey: .bodyWeights),
            BodyWeights.defaultBodyWeights
        )
        supportEquipment = .mergingCatalogue(
            container.decodeLossyArray(SupportEquipment.self, forKey: .supportEquipment),
            SupportEquipment.defaultSupportEquipment
        )
        accessoryEquipment = .mergingCatalogue(
            container.decodeLossyArray(AccessoryEquipment.self, forKey: .accessoryEquipment),
            AccessoryEquipment.defaultAccessoryEquipment
        )
        loadableAccessoryEquipment = .mergingCatalogue(
            container.decodeLossyArray(LoadableAccessoryEquipment.self, forKey: .loadableAccessoryEquipment),
            LoadableAccessoryEquipment.defaultLoadableAccessoryEquipment
        )
        cableMachines = .mergingCatalogue(
            container.decodeLossyArray(CableMachine.self, forKey: .cableMachines),
            CableMachine.defaultCableMachines
        )
        plateLoadedMachines = .mergingCatalogue(
            container.decodeLossyArray(PlateLoadedMachine.self, forKey: .plateLoadedMachines),
            PlateLoadedMachine.defaultPlateLoadedMachines
        )
        pinLoadedMachines = .mergingCatalogue(
            container.decodeLossyArray(PinLoadedMachine.self, forKey: .pinLoadedMachines),
            PinLoadedMachine.defaultPinLoadedMachines
        )
    }

    var eventParameters: [String: Any] {
        [:]
    }
    
    static var mock: GymProfileModel {
        mocks[0]
    }
    
    static var mocks: [GymProfileModel] {
        [
            GymProfileModel(
                id: "1",
                authorId: "user123",
                name: "Platinum Gym Malahide",
                icon: "dumbbell",
                dateCreated: Date.now.addingTimeInterval(-86_400),
                dateModified: Date.now,
                deletedAt: nil,
                freeWeights: FreeWeights.mocks,
                loadableBars: LoadableBars.mocks,
                fixedWeightBars: FixedWeightBars.mocks,
                bands: Bands.mocks,
                bodyWeights: BodyWeights.mocks,
                supportEquipment: SupportEquipment.mocks,
                accessoryEquipment: AccessoryEquipment.mocks,
                loadableAccessoryEquipment: LoadableAccessoryEquipment.mocks,
                cableMachines: CableMachine.mocks,
                plateLoadedMachines: PlateLoadedMachine.mocks,
                pinLoadedMachines: PinLoadedMachine.mocks
            )
        ]
    }
}

extension GymProfileModel {
    static var allEquipmentCatalog: [AnyEquipment] {
        [
            FreeWeights.defaultFreeWeights.map(AnyEquipment.init),
            LoadableBars.defaultLoadableBars.map(AnyEquipment.init),
            FixedWeightBars.defaultFixedWeightBars.map(AnyEquipment.init),
            Bands.defaultBands.map(AnyEquipment.init),
            BodyWeights.defaultBodyWeights.map(AnyEquipment.init),
            SupportEquipment.defaultSupportEquipment.map(AnyEquipment.init),
            AccessoryEquipment.defaultAccessoryEquipment.map(AnyEquipment.init),
            LoadableAccessoryEquipment.defaultLoadableAccessoryEquipment.map(AnyEquipment.init),
            CableMachine.defaultCableMachines.map(AnyEquipment.init),
            PlateLoadedMachine.defaultPlateLoadedMachines.map(AnyEquipment.init),
            PinLoadedMachine.defaultPinLoadedMachines.map(AnyEquipment.init)
        ].flatMap { $0 }
    }

    var allEquipment: [AnyEquipment] {
        [
            freeWeights.map(AnyEquipment.init),
            loadableBars.map(AnyEquipment.init),
            fixedWeightBars.map(AnyEquipment.init),
            bands.map(AnyEquipment.init),
            bodyWeights.map(AnyEquipment.init),
            supportEquipment.map(AnyEquipment.init),
            accessoryEquipment.map(AnyEquipment.init),
            loadableAccessoryEquipment.map(AnyEquipment.init),
            cableMachines.map(AnyEquipment.init),
            plateLoadedMachines.map(AnyEquipment.init),
            pinLoadedMachines.map(AnyEquipment.init)
        ].flatMap { $0 }
    }
    
    var equipmentIndex: [EquipmentRef: AnyEquipment] {
        // Keeps the first item for a ref rather than trapping, since a decoded profile can hold
        // the same id twice.
        Dictionary(allEquipment.map { ($0.ref, $0) }, uniquingKeysWith: { first, _ in first })
    }
    
    func equipment(for ref: EquipmentRef) -> AnyEquipment? {
        equipmentIndex[ref]
    }
    
    var activeEquipmentCount: Int {
        allEquipment.filter(\.isActive).count
    }
}
