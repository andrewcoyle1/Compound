//
//  ReportFlow.swift
//  DialedIn
//

import SwiftUI

/// What a report names: the kind of thing, which one, and who made it.
struct ReportedContent: Equatable {
    let type: ReportContentType
    let id: String
    let authorUserId: String?
    /// How the alerts refer to it: "comment", "workout", "profile".
    let noun: String
}

@MainActor
protocol ReportInteractor: GlobalInteractor {
    func report(contentType: ReportContentType, contentId: String, authorUserId: String?, reason: ReportReason, notes: String?) async throws
}

extension CoreInteractor: ReportInteractor { }

/// The one report flow — ask why, take an optional note, send, say whether it went — shared by
/// comments, feed cards and profiles so the three do not drift apart.
@MainActor
final class ReportFlow {
    /// The longest note a report may carry. `firestore.rules` refuses anything longer.
    static let noteLimit = 500

    private let interactor: ReportInteractor
    private let router: GlobalRouter

    /// The content the flow is open for.
    private(set) var pending: ReportedContent?
    /// The reason picked for it, once one has been.
    private(set) var reason: ReportReason?
    /// What the reporter typed into the note alert.
    var note = ""

    init(interactor: ReportInteractor, router: GlobalRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// Why a report cannot be sent yet, or nil when it can. "Other" says nothing on its own, so it
    /// needs a note; every other reason may go without one.
    static func validationMessage(reason: ReportReason?, note: String) -> String? {
        guard let reason else { return "Choose a reason for the report." }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if reason == .other && trimmed.isEmpty { return "Add a note saying what is wrong." }
        if trimmed.count > noteLimit { return "Keep the note to \(noteLimit) characters or fewer." }
        return nil
    }

    func start(_ content: ReportedContent) {
        pending = content
        reason = nil
        note = ""
        router.showAlert(
            title: String(localized: "Report \(content.noun.capitalized)"),
            subtitle: String(localized: "Why are you reporting this \(content.noun)?"),
            buttons: {
                AnyView(
                    ForEach(ReportReason.allCases) { reason in
                        Button(reason.displayName) {
                            self.onReasonSelected(reason)
                        }
                    }
                )
            }
        )
    }

    func onReasonSelected(_ reason: ReportReason) {
        guard pending != nil else { return }
        self.reason = reason
        showNoteAlert(subtitle: reason == .other ? String(localized: "Tell us what is wrong.") : String(localized: "Optional: anything that helps us review it."))
    }

    func onSendPressed() {
        guard let content = pending else { return }
        if let message = Self.validationMessage(reason: reason, note: note) {
            // Back to the note rather than a dead end, with what was typed still there.
            showNoteAlert(subtitle: message)
            return
        }
        guard let reason else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        pending = nil
        Task {
            do {
                try await interactor.report(
                    contentType: content.type,
                    contentId: content.id,
                    authorUserId: content.authorUserId,
                    reason: reason,
                    notes: trimmed.isEmpty ? nil : trimmed
                )
                router.showSimpleAlert(
                    title: String(localized: "Report Sent"),
                    subtitle: "Thanks — we will take a look at this \(content.noun)."
                )
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to Send Report"), subtitle: String(localized: "Please try again."))
            }
        }
    }

    func onCancelPressed() {
        pending = nil
        reason = nil
        note = ""
    }

    private func showNoteAlert(subtitle: String) {
        router.showAlert(
            title: String(localized: "Add a Note"),
            subtitle: subtitle,
            buttons: {
                AnyView(
                    Group {
                        TextField("Note", text: Binding(
                            // The alert calls these on the main actor; the closures are only
                            // typed Sendable.
                            get: { MainActor.assumeIsolated { self.note } },
                            set: { value in MainActor.assumeIsolated { self.note = value } }
                        ))
                        Button("Send") { self.onSendPressed() }
                        Button("Cancel", role: .cancel) { self.onCancelPressed() }
                    }
                )
            }
        )
    }
}
