//
//  PaywallTestOption.swift
//  AIChatCourse
//
//  Created by Nick Sarno on 11/2/24.
//

import SwiftUI

enum PaywallTestOption: String, Codable, CaseIterable {
    case storeKit, custom, revenueCat
    
    static var `default`: Self {
        .custom
    }
}
