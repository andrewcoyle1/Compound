//
//  PrivacyManifestTests.swift
//  DialedInUnitTests
//
//  Loads the shipped privacy manifests from the built bundles and checks every declared
//  required-reason code against Apple's allowed list, so a typo or a reason from the wrong
//  category is caught here rather than by App Store Connect. Answers live in docs/AppPrivacy.md.
//

import Testing
import Foundation
@testable import DialedIn

struct PrivacyManifestTests {

    /// Apple's approved reasons per required-reason API category (TN3183 / "Describing use of
    /// required reason API"). Add to this only from Apple's published list.
    static let allowedReasons: [String: Set<String>] = [
        "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1", "1C8F.1", "C56D.1", "AC6B.1"],
        "NSPrivacyAccessedAPICategoryFileTimestamp": ["DDA9.1", "C617.1", "3B52.1", "0A2A.1"],
        "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1", "8FFB.1", "3D61.1"],
        "NSPrivacyAccessedAPICategoryDiskSpace": ["85F4.1", "E174.1", "7D9E.1", "B728.1"],
        "NSPrivacyAccessedAPICategoryActiveKeyboards": ["3EC4.1", "54BD.1"]
    ]

    static let allowedPurposes: Set<String> = [
        "AppFunctionality", "Analytics", "ProductPersonalization",
        "DeveloperAdvertising", "ThirdPartyAdvertising", "Other"
    ].reduce(into: []) { $0.insert("NSPrivacyCollectedDataTypePurpose" + $1) }

    static var manifestURLs: [URL] {
        let app = Bundle.main.bundleURL.appendingPathComponent("PrivacyInfo.xcprivacy")
        let widget = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("WorkoutSessionActivityExtension.appex/PrivacyInfo.xcprivacy")
        return [app] + (widget.map { [$0] } ?? [])
    }

    static func load(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test func bothManifestsShipInTheirBundles() {
        #expect(Self.manifestURLs.count == 2)
        for url in Self.manifestURLs {
            #expect(FileManager.default.fileExists(atPath: url.path), "missing \(url.path)")
        }
    }

    @Test(arguments: manifestURLs)
    func everyReasonCodeIsAllowedForItsCategory(url: URL) throws {
        let manifest = try Self.load(url)
        let types = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(!types.isEmpty)
        for entry in types {
            let category = try #require(entry["NSPrivacyAccessedAPIType"] as? String)
            let allowed = try #require(Self.allowedReasons[category], "unknown category \(category)")
            let reasons = try #require(entry["NSPrivacyAccessedAPITypeReasons"] as? [String])
            #expect(!reasons.isEmpty, "\(category) declares no reason")
            for reason in reasons {
                #expect(allowed.contains(reason), "\(reason) is not an allowed reason for \(category)")
            }
        }
    }

    @Test(arguments: manifestURLs)
    func declaresNoTracking(url: URL) throws {
        let manifest = try Self.load(url)
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
    }

    @Test(arguments: manifestURLs)
    func collectedDataTypesAreWellFormed(url: URL) throws {
        let manifest = try Self.load(url)
        let collected = try #require(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        for entry in collected {
            let type = try #require(entry["NSPrivacyCollectedDataType"] as? String)
            #expect(type.hasPrefix("NSPrivacyCollectedDataType"))
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] is Bool, "\(type) missing Linked")
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false, "\(type) must not track")
            let purposes = try #require(entry["NSPrivacyCollectedDataTypePurposes"] as? [String])
            #expect(!purposes.isEmpty, "\(type) has no purpose")
            #expect(Set(purposes).isSubset(of: Self.allowedPurposes), "\(type) has an unknown purpose")
        }
    }

    /// The app manifest declares system boot time under 35F9.1, which forbids sending it off-device.
    @MainActor
    @Test func analyticsParametersNeverCarrySystemUptime() {
        #expect(Utilities.eventParameters["utility_system_uptime_days"] != nil)
        #expect(Utilities.offDeviceEventParameters["utility_system_uptime_days"] == nil)
    }
}
