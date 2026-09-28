//
//  Licence.swift
//  DialedIn
//

import Foundation

/// One third-party package the app ships, for the Licences screen.
///
/// The list and each `licence` were read from the LICENSE files in the resolved Swift Package
/// checkouts, not filled in from memory — this is a legal notice, so an unverified claim is worse
/// than an absent one. `licence` is nil where the package ships no licence file; those are shown as
/// unstated rather than assumed. SwiftLint is excluded: it is a build-time plugin, not shipped code.
struct Licence: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let owner: String
    let licence: String?

    var repositoryURL: URL? {
        URL(string: "https://github.com/\(owner)/\(name)")
    }

    var licenceLabel: String {
        licence ?? "License not stated in package"
    }

    /// Every package the app links, ordered as the screen lists them.
    static let all: [Licence] = [
        Licence(name: "abseil-cpp-binary", owner: "google", licence: "Apache-2.0"),
        Licence(name: "app-check", owner: "google", licence: "Apache-2.0"),
        Licence(name: "AppAuth-iOS", owner: "openid", licence: "Apache-2.0"),
        Licence(name: "firebase-ios-sdk", owner: "firebase", licence: "Apache-2.0"),
        Licence(name: "google-ads-on-device-conversion-ios-sdk", owner: "googleads", licence: "Apache-2.0"),
        Licence(name: "GoogleAppMeasurement", owner: "google", licence: "Apache-2.0"),
        Licence(name: "GoogleDataTransport", owner: "google", licence: "Apache-2.0"),
        Licence(name: "GoogleSignIn-iOS", owner: "google", licence: "Apache-2.0"),
        Licence(name: "GoogleUtilities", owner: "google", licence: "Apache-2.0"),
        Licence(name: "grpc-binary", owner: "google", licence: "Apache-2.0"),
        Licence(name: "gtm-session-fetcher", owner: "google", licence: "Apache-2.0"),
        Licence(name: "GTMAppAuth", owner: "google", licence: "Apache-2.0"),
        Licence(name: "IdentifiableByString", owner: "SwiftfulThinking", licence: nil),
        Licence(name: "interop-ios-for-google-sdks", owner: "google", licence: "Apache-2.0"),
        Licence(name: "leveldb", owner: "firebase", licence: "BSD-3-Clause"),
        Licence(name: "mixpanel-swift", owner: "mixpanel", licence: "Apache-2.0"),
        Licence(name: "nanopb", owner: "firebase", licence: "zlib"),
        Licence(name: "promises", owner: "google", licence: "Apache-2.0"),
        Licence(name: "purchases-ios", owner: "RevenueCat", licence: "MIT"),
        Licence(name: "SDWebImage", owner: "SDWebImage", licence: "MIT"),
        Licence(name: "SDWebImageSwiftUI", owner: "SDWebImage", licence: "MIT"),
        Licence(name: "SignInAppleAsync", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SignInGoogleAsync", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "swift-protobuf", owner: "apple", licence: "Apache-2.0"),
        Licence(name: "SwiftfulAuthenticating", owner: "andrewcoyle1", licence: "MIT"),
        Licence(name: "SwiftfulAuthenticatingFirebase", owner: "andrewcoyle1", licence: "MIT"),
        Licence(name: "SwiftfulDataManagers", owner: "andrewcoyle1", licence: nil),
        Licence(name: "SwiftfulDataManagersFirebase", owner: "andrewcoyle1", licence: nil),
        Licence(name: "SwiftfulFirestore", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulGamification", owner: "andrewcoyle1", licence: nil),
        Licence(name: "SwiftfulGamificationFirebase", owner: "andrewcoyle1", licence: nil),
        Licence(name: "SwiftfulHaptics", owner: "SwiftfulThinking", licence: nil),
        Licence(name: "SwiftfulLogging", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulLoggingFirebaseAnalytics", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulLoggingFirebaseCrashlytics", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulLoggingMixpanel", owner: "SwiftfulThinking", licence: nil),
        Licence(name: "SwiftfulPurchasing", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulPurchasingRevenueCat", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulRecursiveUI", owner: "SwiftfulThinking", licence: nil),
        Licence(name: "SwiftfulRouting", owner: "andrewcoyle1", licence: "MIT"),
        Licence(name: "SwiftfulSoundEffects", owner: "SwiftfulThinking", licence: nil),
        Licence(name: "SwiftfulUI", owner: "SwiftfulThinking", licence: "MIT"),
        Licence(name: "SwiftfulUtilities", owner: "SwiftfulThinking", licence: "MIT")
    ]

    /// Grouped by licence so the screen reads as a short set of terms rather than 43 rows of
    /// repetition. Unstated licences sort last.
    static var groupedByLicence: [(licence: String, packages: [Licence])] {
        let groups = Dictionary(grouping: all, by: \.licenceLabel)
        return groups
            .map { (licence: $0.key, packages: $0.value.sorted { $0.name.lowercased() < $1.name.lowercased() }) }
            .sorted { lhs, rhs in
                let lhsUnstated = lhs.licence.hasPrefix("License not")
                let rhsUnstated = rhs.licence.hasPrefix("License not")
                if lhsUnstated != rhsUnstated { return rhsUnstated }
                if lhs.packages.count != rhs.packages.count { return lhs.packages.count > rhs.packages.count }
                return lhs.licence < rhs.licence
            }
    }
}
