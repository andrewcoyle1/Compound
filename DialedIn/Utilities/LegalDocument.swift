//
//  LegalDocument.swift
//  DialedIn
//
//  The agreements the app links to, in one place. `LegalView` listed all four as buttons with
//  empty actions, `WelcomeView` linked two of them from `Constants`, and `AuthView` tried to and
//  failed — its markdown destination was the literal text `Constants.termsofServiceURL`, with no
//  interpolation, so neither link resolved to anything.
//

import Foundation

enum LegalDocument: String, CaseIterable, Identifiable {

    case termsOfService
    case privacyPolicy
    case healthDisclaimer
    case consumerHealthPrivacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .termsOfService:        return String(localized: "Terms of Service")
        case .privacyPolicy:         return String(localized: "Privacy Policy")
        case .healthDisclaimer:      return String(localized: "Health Disclaimer")
        case .consumerHealthPrivacy: return String(localized: "Consumer Health Privacy")
        }
    }

    /// ⚠️ These are placeholders pointing at apple.com, inherited from `Constants.termsofServiceURL`
    /// and `privacyPolicyURL`. They must be replaced with the real published documents before
    /// release — the App Store requires a working privacy policy link, and a health app shipping a
    /// disclaimer that resolves to someone else's homepage is worse than not linking one at all.
    var url: URL? {
        URL(string: urlString)
    }

    private var urlString: String {
        switch self {
        case .termsOfService:        return Constants.termsofServiceURL
        case .privacyPolicy:         return Constants.privacyPolicyURL
        case .healthDisclaimer:      return Constants.healthDisclaimerURL
        case .consumerHealthPrivacy: return Constants.consumerHealthPrivacyURL
        }
    }
}
