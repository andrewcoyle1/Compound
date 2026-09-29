//
//  ReportManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 14/08/2025.
//

import Foundation
import SwiftUI

/// What a report is about. Stored as `target_type`, which the rules limit to these three.
enum ReportContentType: String, Codable {
    /// A comment on a workout session.
    case comment
    /// A finished workout session in the feed.
    case session
    /// A user's profile.
    case user
}

/// Why something was reported. Stored as `reason`; `firestore.rules` lists the same raw values.
enum ReportReason: String, CaseIterable, Codable, Identifiable {
    case spam
    case harassment
    case inappropriate
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: return String(localized: "Spam")
        case .harassment: return String(localized: "Harassment")
        case .inappropriate: return String(localized: "Inappropriate")
        case .other: return String(localized: "Other")
        }
    }
}

struct ReportSubmission: Codable {
    let reportId: String
    let reporterUserId: String
    let reportedUserId: String?
    let contentType: ReportContentType
    let contentId: String
    let reason: ReportReason
    let notes: String?
    let createdAt: Date
}

@Observable
@MainActor
class ReportManager {
    private let remote: RemoteReportService
    private let userManager: UserManager
    private let logManager: LogManager?
    
    init(service: RemoteReportService, userManager: UserManager, logManager: LogManager? = nil) {
        self.remote = service
        self.userManager = userManager
        self.logManager = logManager
    }
    
    func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws {
        guard let reporterId = userManager.currentUser?.userId else { throw ReportError.noCurrentUser }
        let submission = ReportSubmission(
            reportId: UUID().uuidString,
            reporterUserId: reporterId,
            reportedUserId: authorUserId,
            contentType: contentType,
            contentId: contentId,
            reason: reason,
            notes: notes,
            createdAt: Date()
        )
        logManager?.trackEvent(event: AnyLoggableEvent(eventName: "Report_Submit_Start", parameters: [
            "content_type": contentType.rawValue, "content_id": contentId, "reason": reason.rawValue
        ]))
        try await remote.submit(report: submission)
        logManager?.trackEvent(event: AnyLoggableEvent(eventName: "Report_Submit_Success", parameters: [
            "content_type": contentType.rawValue, "content_id": contentId
        ]))
    }
    
    enum ReportError: LocalizedError { case noCurrentUser }
}

extension CoreInteractor {
    // ReportManager
    
    func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws {
        try await reportManager.report(contentType: contentType, contentId: contentId, authorUserId: authorUserId, reason: reason, notes: notes)
    }

}
