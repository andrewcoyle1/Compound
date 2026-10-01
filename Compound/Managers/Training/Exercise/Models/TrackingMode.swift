//
//  TrackingMode.swift
//  Compound
//
//  Created by Andrew Coyle on 21/01/2026.
//

import Foundation

enum TrackingMode: String, DataSyncModelProtocol, CaseIterable {
    
    var id: String { rawValue }
    
    case weightReps
    case repsOnly
    case timeOnly
    case distanceTime
}
