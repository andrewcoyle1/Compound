//
//  FirebaseReportService.swift
//  DialedIn
//
//  Created by Andrew Coyle on 14/08/2025.
//

import Foundation
import FirebaseFirestore

/// Writes `reports/{id}`. Every report starts `open`; only the backend moves it on, and the
/// `onReportCreated` function counts the open ones per target.
struct FirebaseReportService: RemoteReportService {
    var collection: CollectionReference { Firestore.firestore().collection("reports") }
    
    func submit(report: ReportSubmission) async throws {
        try await collection.document(report.reportId).setData([
            "id": report.reportId,
            "reporter_id": report.reporterUserId,
            "target_type": report.contentType.rawValue,
            "target_id": report.contentId,
            "target_author_id": report.reportedUserId as Any,
            "reason": report.reason.rawValue,
            "note": report.notes as Any,
            "status": "open",
            "date_created": Timestamp(date: report.createdAt)
        ])
    }
}
