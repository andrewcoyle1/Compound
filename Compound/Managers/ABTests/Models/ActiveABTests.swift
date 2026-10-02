//
//  ActiveABTests.swift
//  Compound
//
//  Created by Andrew Coyle on 05/12/2025.
//

import Foundation

struct ActiveABTests: Codable {
    private(set) var notificationsTest: Bool
    private(set) var paywallTest: PaywallTestOption

    init(
        notificationsTest: Bool? = nil,
        paywallTest: PaywallTestOption
    ) {
        self.notificationsTest = notificationsTest ?? false
        self.paywallTest = paywallTest
    }
    
    enum CodingKeys: String, CodingKey {
        case notificationsTest = "_20251205_notifications_test"
        case paywallTest = "_20241205_PaywallTest"

    }
    
    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "test\(CodingKeys.notificationsTest.rawValue)": notificationsTest,
            "test\(CodingKeys.paywallTest.rawValue)": paywallTest.rawValue
        ]
        return dict.compactMapValues({ $0 })
    }
    
    mutating func update(notificationsTest newValue: Bool) {
        notificationsTest = newValue
    }
    
    mutating func update(paywallTest newValue: PaywallTestOption) {
        paywallTest = newValue
    }
}

// MARK: Remote Config

import FirebaseRemoteConfigInternal

extension ActiveABTests {
    init(config: RemoteConfig) {
        let notificationsTest = config.configValue(forKey: ActiveABTests.CodingKeys.notificationsTest.rawValue).boolValue
        self.notificationsTest = notificationsTest
        
        let paywallTestStringValue = config.configValue(forKey: ActiveABTests.CodingKeys.paywallTest.rawValue).stringValue
        if let option = PaywallTestOption(rawValue: paywallTestStringValue) {
            self.paywallTest = option
        } else {
            self.paywallTest = .default
        }
    }
    
    // Converted to a NSObject dictionary to setDefaults within FirebaseABTestService
    var asNSObjectDictionary: [String: NSObject]? {
        [
            CodingKeys.notificationsTest.rawValue: notificationsTest as NSObject,
            CodingKeys.paywallTest.rawValue: paywallTest.rawValue as NSObject
        ]
    }
}
