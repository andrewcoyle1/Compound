//
//  BodyMeasurementEntry.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

struct BodyMeasurementEntry: DataSyncModelProtocol, Equatable {
    
    let id: String
    let authorId: String
    let weightKg: Double?
    let bodyFatPercentage: Double?
    let neckCircumference: Double?
    let shoulderCircumference: Double?
    let bustCircumference: Double?
    let chestCircumference: Double?
    let waistCircumference: Double?
    let hipCircumference: Double?
    let leftBicepCircumference: Double?
    let rightBicepCircumference: Double?
    let leftForearmCircumference: Double?
    let rightForearmCircumference: Double?
    let leftWristCircumference: Double?
    let rightWristCircumference: Double?
    let leftThighCircumference: Double?
    let rightThighCircumference: Double?
    let leftCalfCircumference: Double?
    let rightCalfCircumference: Double?
    let leftAnkleCircumference: Double?
    let rightAnkleCircumference: Double?
    let progressPhotoURLs: [String]?
    let date: Date
    let source: WeightSource
    let notes: String?
    let dateCreated: Date
    let deletedAt: Date?
    let healthKitUUID: UUID?

    init(
        id: String = UUID().uuidString,
        authorId: String,
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        neckCircumference: Double? = nil,
        shoulderCircumference: Double? = nil,
        bustCircumference: Double? = nil,
        chestCircumference: Double? = nil,
        waistCircumference: Double? = nil,
        hipCircumference: Double? = nil,
        leftBicepCircumference: Double? = nil,
        rightBicepCircumference: Double? = nil,
        leftForearmCircumference: Double? = nil,
        rightForearmCircumference: Double? = nil,
        leftWristCircumference: Double? = nil,
        rightWristCircumference: Double? = nil,
        leftThighCircumference: Double? = nil,
        rightThighCircumference: Double? = nil,
        leftCalfCircumference: Double? = nil,
        rightCalfCircumference: Double? = nil,
        leftAnkleCircumference: Double? = nil,
        rightAnkleCircumference: Double? = nil,
        progressPhotoURLs: [String]? = nil,
        date: Date,
        source: WeightSource = .manual,
        notes: String? = nil,
        dateCreated: Date = Date(),
        deletedAt: Date? = nil,
        healthKitUUID: UUID? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.neckCircumference = neckCircumference
        self.shoulderCircumference = shoulderCircumference
        self.bustCircumference = bustCircumference
        self.chestCircumference = chestCircumference
        self.waistCircumference = waistCircumference
        self.hipCircumference = hipCircumference
        self.leftBicepCircumference = leftBicepCircumference
        self.rightBicepCircumference = rightBicepCircumference
        self.leftForearmCircumference = leftForearmCircumference
        self.rightForearmCircumference = rightForearmCircumference
        self.leftWristCircumference = leftWristCircumference
        self.rightWristCircumference = rightWristCircumference
        self.leftThighCircumference = leftThighCircumference
        self.rightThighCircumference = rightThighCircumference
        self.leftCalfCircumference = leftCalfCircumference
        self.rightCalfCircumference = rightCalfCircumference
        self.leftAnkleCircumference = leftAnkleCircumference
        self.rightAnkleCircumference = rightAnkleCircumference
        self.progressPhotoURLs = progressPhotoURLs
        self.date = date
        self.source = source
        self.notes = notes
        self.dateCreated = dateCreated
        self.deletedAt = deletedAt
        self.healthKitUUID = healthKitUUID
    }

    /// Returns a copy with the specified circumference field updated to the given value.
    func withUpdated(_ update: CircumferenceUpdate) -> BodyMeasurementEntry {
        if let result = applyUpperBodyUpdate(update) { return result }
        if let result = applyArmsUpdate(update) { return result }
        // Safe: the three helpers cover every case; BodyMeasurementTests round-trips each kind.
        return applyLegsUpdate(update)!
    }

    private func applyUpperBodyUpdate(_ update: CircumferenceUpdate) -> BodyMeasurementEntry? {
        switch update {
        case .neck(let value): return copyWithOverrides(neckCircumference: value)
        case .shoulder(let value): return copyWithOverrides(shoulderCircumference: value)
        case .bust(let value): return copyWithOverrides(bustCircumference: value)
        case .chest(let value): return copyWithOverrides(chestCircumference: value)
        case .waist(let value): return copyWithOverrides(waistCircumference: value)
        case .hip(let value): return copyWithOverrides(hipCircumference: value)
        default: return nil
        }
    }

    private func applyArmsUpdate(_ update: CircumferenceUpdate) -> BodyMeasurementEntry? {
        switch update {
        case .leftBicep(let value): return copyWithOverrides(leftBicepCircumference: value)
        case .rightBicep(let value): return copyWithOverrides(rightBicepCircumference: value)
        case .leftForearm(let value): return copyWithOverrides(leftForearmCircumference: value)
        case .rightForearm(let value): return copyWithOverrides(rightForearmCircumference: value)
        case .leftWrist(let value): return copyWithOverrides(leftWristCircumference: value)
        case .rightWrist(let value): return copyWithOverrides(rightWristCircumference: value)
        default: return nil
        }
    }

    private func applyLegsUpdate(_ update: CircumferenceUpdate) -> BodyMeasurementEntry? {
        switch update {
        case .leftThigh(let value): return copyWithOverrides(leftThighCircumference: value)
        case .rightThigh(let value): return copyWithOverrides(rightThighCircumference: value)
        case .leftCalf(let value): return copyWithOverrides(leftCalfCircumference: value)
        case .rightCalf(let value): return copyWithOverrides(rightCalfCircumference: value)
        case .leftAnkle(let value): return copyWithOverrides(leftAnkleCircumference: value)
        case .rightAnkle(let value): return copyWithOverrides(rightAnkleCircumference: value)
        default: return nil
        }
    }

    private func copyWithOverrides(
        neckCircumference: Double? = nil,
        shoulderCircumference: Double? = nil,
        bustCircumference: Double? = nil,
        chestCircumference: Double? = nil,
        waistCircumference: Double? = nil,
        hipCircumference: Double? = nil,
        leftBicepCircumference: Double? = nil,
        rightBicepCircumference: Double? = nil,
        leftForearmCircumference: Double? = nil,
        rightForearmCircumference: Double? = nil,
        leftWristCircumference: Double? = nil,
        rightWristCircumference: Double? = nil,
        leftThighCircumference: Double? = nil,
        rightThighCircumference: Double? = nil,
        leftCalfCircumference: Double? = nil,
        rightCalfCircumference: Double? = nil,
        leftAnkleCircumference: Double? = nil,
        rightAnkleCircumference: Double? = nil
    ) -> BodyMeasurementEntry {
        BodyMeasurementEntry(
            id: id,
            authorId: authorId,
            weightKg: weightKg,
            bodyFatPercentage: bodyFatPercentage,
            neckCircumference: neckCircumference ?? self.neckCircumference,
            shoulderCircumference: shoulderCircumference ?? self.shoulderCircumference,
            bustCircumference: bustCircumference ?? self.bustCircumference,
            chestCircumference: chestCircumference ?? self.chestCircumference,
            waistCircumference: waistCircumference ?? self.waistCircumference,
            hipCircumference: hipCircumference ?? self.hipCircumference,
            leftBicepCircumference: leftBicepCircumference ?? self.leftBicepCircumference,
            rightBicepCircumference: rightBicepCircumference ?? self.rightBicepCircumference,
            leftForearmCircumference: leftForearmCircumference ?? self.leftForearmCircumference,
            rightForearmCircumference: rightForearmCircumference ?? self.rightForearmCircumference,
            leftWristCircumference: leftWristCircumference ?? self.leftWristCircumference,
            rightWristCircumference: rightWristCircumference ?? self.rightWristCircumference,
            leftThighCircumference: leftThighCircumference ?? self.leftThighCircumference,
            rightThighCircumference: rightThighCircumference ?? self.rightThighCircumference,
            leftCalfCircumference: leftCalfCircumference ?? self.leftCalfCircumference,
            rightCalfCircumference: rightCalfCircumference ?? self.rightCalfCircumference,
            leftAnkleCircumference: leftAnkleCircumference ?? self.leftAnkleCircumference,
            rightAnkleCircumference: rightAnkleCircumference ?? self.rightAnkleCircumference,
            progressPhotoURLs: progressPhotoURLs,
            date: date,
            source: source,
            notes: notes,
            dateCreated: dateCreated,
            deletedAt: deletedAt,
            healthKitUUID: healthKitUUID
        )
    }

    enum CircumferenceUpdate {
        case neck(Double)
        case shoulder(Double)
        case bust(Double)
        case chest(Double)
        case waist(Double)
        case hip(Double)
        case leftBicep(Double)
        case rightBicep(Double)
        case leftForearm(Double)
        case rightForearm(Double)
        case leftWrist(Double)
        case rightWrist(Double)
        case leftThigh(Double)
        case rightThigh(Double)
        case leftCalf(Double)
        case rightCalf(Double)
        case leftAnkle(Double)
        case rightAnkle(Double)
    }

    /// Returns a copy with the specified measurement field set to nil.
    func withCleared(_ field: ClearedField) -> BodyMeasurementEntry {
        copy(
            clearWeightKg: field == .weightKg,
            clearBodyFatPercentage: field == .bodyFatPercentage,
            clearNeckCircumference: field == .neckCircumference,
            clearShoulderCircumference: field == .shoulderCircumference,
            clearBustCircumference: field == .bustCircumference,
            clearChestCircumference: field == .chestCircumference,
            clearWaistCircumference: field == .waistCircumference,
            clearHipCircumference: field == .hipCircumference,
            clearLeftBicepCircumference: field == .leftBicepCircumference,
            clearRightBicepCircumference: field == .rightBicepCircumference,
            clearLeftForearmCircumference: field == .leftForearmCircumference,
            clearRightForearmCircumference: field == .rightForearmCircumference,
            clearLeftWristCircumference: field == .leftWristCircumference,
            clearRightWristCircumference: field == .rightWristCircumference,
            clearLeftThighCircumference: field == .leftThighCircumference,
            clearRightThighCircumference: field == .rightThighCircumference,
            clearLeftCalfCircumference: field == .leftCalfCircumference,
            clearRightCalfCircumference: field == .rightCalfCircumference,
            clearLeftAnkleCircumference: field == .leftAnkleCircumference,
            clearRightAnkleCircumference: field == .rightAnkleCircumference
        )
    }

    private func copy(
        clearWeightKg: Bool = false,
        clearBodyFatPercentage: Bool = false,
        clearNeckCircumference: Bool = false,
        clearShoulderCircumference: Bool = false,
        clearBustCircumference: Bool = false,
        clearChestCircumference: Bool = false,
        clearWaistCircumference: Bool = false,
        clearHipCircumference: Bool = false,
        clearLeftBicepCircumference: Bool = false,
        clearRightBicepCircumference: Bool = false,
        clearLeftForearmCircumference: Bool = false,
        clearRightForearmCircumference: Bool = false,
        clearLeftWristCircumference: Bool = false,
        clearRightWristCircumference: Bool = false,
        clearLeftThighCircumference: Bool = false,
        clearRightThighCircumference: Bool = false,
        clearLeftCalfCircumference: Bool = false,
        clearRightCalfCircumference: Bool = false,
        clearLeftAnkleCircumference: Bool = false,
        clearRightAnkleCircumference: Bool = false
    ) -> BodyMeasurementEntry {
        BodyMeasurementEntry(
            id: id,
            authorId: authorId,
            weightKg: clearWeightKg ? nil : weightKg,
            bodyFatPercentage: clearBodyFatPercentage ? nil : bodyFatPercentage,
            neckCircumference: clearNeckCircumference ? nil : neckCircumference,
            shoulderCircumference: clearShoulderCircumference ? nil : shoulderCircumference,
            bustCircumference: clearBustCircumference ? nil : bustCircumference,
            chestCircumference: clearChestCircumference ? nil : chestCircumference,
            waistCircumference: clearWaistCircumference ? nil : waistCircumference,
            hipCircumference: clearHipCircumference ? nil : hipCircumference,
            leftBicepCircumference: clearLeftBicepCircumference ? nil : leftBicepCircumference,
            rightBicepCircumference: clearRightBicepCircumference ? nil : rightBicepCircumference,
            leftForearmCircumference: clearLeftForearmCircumference ? nil : leftForearmCircumference,
            rightForearmCircumference: clearRightForearmCircumference ? nil : rightForearmCircumference,
            leftWristCircumference: clearLeftWristCircumference ? nil : leftWristCircumference,
            rightWristCircumference: clearRightWristCircumference ? nil : rightWristCircumference,
            leftThighCircumference: clearLeftThighCircumference ? nil : leftThighCircumference,
            rightThighCircumference: clearRightThighCircumference ? nil : rightThighCircumference,
            leftCalfCircumference: clearLeftCalfCircumference ? nil : leftCalfCircumference,
            rightCalfCircumference: clearRightCalfCircumference ? nil : rightCalfCircumference,
            leftAnkleCircumference: clearLeftAnkleCircumference ? nil : leftAnkleCircumference,
            rightAnkleCircumference: clearRightAnkleCircumference ? nil : rightAnkleCircumference,
            progressPhotoURLs: progressPhotoURLs,
            date: date,
            source: source,
            notes: notes,
            dateCreated: dateCreated,
            deletedAt: deletedAt,
            healthKitUUID: healthKitUUID
        )
    }

    enum ClearedField {
        case weightKg
        case bodyFatPercentage
        case neckCircumference
        case shoulderCircumference
        case bustCircumference
        case chestCircumference
        case waistCircumference
        case hipCircumference
        case leftBicepCircumference
        case rightBicepCircumference
        case leftForearmCircumference
        case rightForearmCircumference
        case leftWristCircumference
        case rightWristCircumference
        case leftThighCircumference
        case rightThighCircumference
        case leftCalfCircumference
        case rightCalfCircumference
        case leftAnkleCircumference
        case rightAnkleCircumference
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case weightKg = "weight_kg"
        case bodyFatPercentage = "body_fat_percentage"
        case neckCircumference = "neck_circumference"
        case shoulderCircumference = "shoulder_circumference"
        case bustCircumference = "bust_circumference"
        case chestCircumference = "chest_circumference"
        case waistCircumference = "waist_circumference"
        case hipCircumference = "hip_circumference"
        case leftBicepCircumference = "left_bicep_circumference"
        case rightBicepCircumference = "right_bicep_circumference"
        case leftForearmCircumference = "left_forearm_circumference"
        case rightForearmCircumference = "right_forearm_circumference"
        case leftWristCircumference = "left_wrist_circumference"
        case rightWristCircumference = "right_wrist_circumference"
        case leftThighCircumference = "left_thigh_circumference"
        case rightThighCircumference = "right_thigh_circumference"
        case leftCalfCircumference = "left_calf_circumference"
        case rightCalfCircumference = "right_calf_circumference"
        case leftAnkleCircumference = "left_ankle_circumference"
        case rightAnkleCircumference = "right_ankle_circumference"
        case progressPhotoURLs = "progress_photo_urls"
        case date
        case source
        case notes
        case dateCreated = "date_created"
        case deletedAt = "deleted_at"
        case healthKitUUID = "healthkit_uuid"
    }
}

// MARK: - Mock Data
extension BodyMeasurementEntry {
    static var mock: BodyMeasurementEntry {
        mocks[0]
    }

    static let mocks: [BodyMeasurementEntry] =
        (0..<500).map { datapoint in
            let position = Double(datapoint)
            // Slow downward trend on top of the seasonal wave, so the weight chart shows
            // actual progress rather than a flat sine.
            let trend = position * 0.012
            let baseWeight: Double = 72.0
            let amplitude: Double = 2.5
            let period: Double = 100.0
            let weight = baseWeight + trend + amplitude * sin(position * 2 * .pi / period)
            let bodyFatBase: Double = 16.0
            let bodyFatAmplitude: Double = 1.2
            let bodyFatPercent = bodyFatBase + (position * 0.004) + bodyFatAmplitude * sin(position * 2 * .pi / 120.0)
            let wave = sin(position * 2 * .pi / 90.0)
            let date = Date.now.addingTimeInterval(Double(-86400 * datapoint))

            // A weekly progress photo and a note every few weeks, so those UIs are not empty.
            let hasPhoto = datapoint % 7 == 0
            let note: String?
            switch datapoint % 28 {
            case 0:  note = "Morning weigh-in, fasted."
            case 7:  note = "Felt strong this week — sleep has been better."
            case 14: note = "Travelling, meals were less consistent."
            default: note = nil
            }

            return BodyMeasurementEntry(
                // Was "user_123", which matched no mock user, so these entries were
                // filtered out of the body metrics screens.
                authorId: UserModel.mock.userId,
                weightKg: weight,
                bodyFatPercentage: bodyFatPercent,
                neckCircumference: 38 + wave * 0.4,
                shoulderCircumference: 120 + wave * 1.2,
                chestCircumference: 101 + wave * 1.0,
                waistCircumference: 80 - trend * 0.5 + wave,
                hipCircumference: 95 - trend * 0.3 + wave,
                leftBicepCircumference: 35.5 + wave * 0.5,
                rightBicepCircumference: 36.0 + wave * 0.5,
                leftForearmCircumference: 29.0 + wave * 0.3,
                rightForearmCircumference: 29.4 + wave * 0.3,
                leftWristCircumference: 17.2,
                rightWristCircumference: 17.4,
                leftThighCircumference: 58.0 + wave * 0.8,
                rightThighCircumference: 58.5 + wave * 0.8,
                leftCalfCircumference: 38.5 + wave * 0.4,
                rightCalfCircumference: 38.8 + wave * 0.4,
                leftAnkleCircumference: 22.4,
                rightAnkleCircumference: 22.5,
                progressPhotoURLs: hasPhoto ? ["https://picsum.photos/seed/progress\(datapoint)/600/800"] : nil,
                date: date,
                source: datapoint % 3 == 0 ? .healthkit : .manual,
                notes: note
            )
        }
}

extension BodyMeasurementEntry: @MainActor MetricEntry {
    var displayLabel: String {
        "\(date.formatted(.dateTime.day().month().year()))"
    }

    var displayValue: String {
        weightKg?.formatted(.number.precision(.fractionLength(1))) ?? "--"
    }

    var systemImageName: String {
        "scalemass"
    }

    func timeSeriesData() -> [MetricTimeSeriesPoint] {
        var series: [MetricTimeSeriesPoint] = []
        if let weightKg {
            series.append(MetricTimeSeriesPoint(seriesName: "Weight", date: date, value: weightKg))
        }
        if let bodyFatPercentage {
            series.append(MetricTimeSeriesPoint(seriesName: "Body Fat", date: date, value: bodyFatPercentage))
        }
        return series
    }
}
