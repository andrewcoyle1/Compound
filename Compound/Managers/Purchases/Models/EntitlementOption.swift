//
//  EntitlementOption.swift
//  Compound
//
//  Created by AndrewCoyle on 11/1/24.
//

enum EntitlementOption: Codable, CaseIterable {
    case yearly
    case monthly
    
    var productId: String {
        switch self {
        case .yearly:
            #if DEBUG
            return "com.andrewcoyle.compound.dev.yearly"
            #else
            return "com.andrewcoyle.compound.yearly"
            #endif
        case .monthly:
            #if DEBUG
            return "com.andrewcoyle.compound.dev.monthly"
            #else
            return "com.andrewcoyle.compound.monthly"
            #endif
        }
    }
    
    static var allProductIds: [String] {
        EntitlementOption.allCases.map({ $0.productId })
    }
}
