//
//  ReportFlow.swift
//  Compound
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
///
/// One sheet holds the reasons and the note, with Close and Send. It used to be two alerts in a
/// row, the first with no way out but picking a reason.
@Observable
@MainActor
final class ReportFlow {
    /// The longest note a report may carry. `firestore.rules` refuses anything longer.
    static let noteLimit = 500

    @ObservationIgnored private let interactor: ReportInteractor
    @ObservationIgnored private let router: GlobalRouter

    /// The content the flow is open for.
    private(set) var pending: ReportedContent?
    /// The reason picked for it, once one has been.
    private(set) var reason: ReportReason?
    /// What the reporter typed into the note field.
    var note = ""
    /// Why the last Send did not go, shown in the sheet until the reporter fixes it.
    private(set) var validationMessage: String?

    init(interactor: ReportInteractor, router: GlobalRouter) {
        self.interactor = interactor
        self.router = router
    }

    /// Why a report cannot be sent yet, or nil when it can. "Other" says nothing on its own, so it
    /// needs a note; every other reason may go without one.
    static func validationMessage(reason: ReportReason?, note: String) -> String? {
        guard let reason else { return String(localized: "Choose a reason for the report.") }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if reason == .other && trimmed.isEmpty { return String(localized: "Add a note saying what is wrong.") }
        if trimmed.count > noteLimit { return String(localized: "Keep the note to \(noteLimit) characters or fewer.") }
        return nil
    }

    var title: String {
        String(localized: "Report \(pending?.noun.capitalized ?? "")")
    }

    var reasonPrompt: String {
        String(localized: "Why are you reporting this \(pending?.noun ?? "")?")
    }

    var notePrompt: String {
        reason == .other ? String(localized: "Tell us what is wrong.") : String(localized: "Optional: anything that helps us review it.")
    }

    func start(_ content: ReportedContent) {
        pending = content
        reason = nil
        note = ""
        validationMessage = nil
        router.router.showScreen(.sheetConfig(config: .half)) { sheetRouter in
            ReportSheetView(flow: self, onClose: { sheetRouter.dismissScreen() })
        }
    }

    func onReasonSelected(_ reason: ReportReason) {
        guard pending != nil else { return }
        self.reason = reason
        validationMessage = nil
    }

    /// Sends the report, or says in the sheet why it cannot. True when it went and the sheet can close.
    @discardableResult
    func onSendPressed() -> Bool {
        guard let content = pending else { return false }
        if let message = Self.validationMessage(reason: reason, note: note) {
            validationMessage = message
            return false
        }
        guard let reason else { return false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        pending = nil
        interactor.trackEvent(event: Event.reportStart(type: content.type, reason: reason))
        Task {
            do {
                try await interactor.report(
                    contentType: content.type,
                    contentId: content.id,
                    authorUserId: content.authorUserId,
                    reason: reason,
                    notes: trimmed.isEmpty ? nil : trimmed
                )
                interactor.trackEvent(event: Event.reportSuccess(type: content.type, reason: reason))
                // Informative only, so a toast rather than an alert to tap away.
                interactor.showAppToast(AppToast(
                    style: .success,
                    message: String(localized: "Report sent. Thanks — we will take a look at this \(content.noun).")
                ))
            } catch {
                interactor.trackEvent(event: Event.reportFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Send Report"), subtitle: String(localized: "Please try again."))
            }
        }
        return true
    }

    func onCancelPressed() {
        pending = nil
        reason = nil
        note = ""
        validationMessage = nil
    }

    enum Event: LoggableEvent {
        case reportStart(type: ReportContentType, reason: ReportReason)
        case reportSuccess(type: ReportContentType, reason: ReportReason)
        case reportFail(error: Error)

        var eventName: String {
            switch self {
            case .reportStart:   return "ReportFlow_Report_Start"
            case .reportSuccess: return "ReportFlow_Report_Success"
            case .reportFail:    return "ReportFlow_Report_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .reportStart(let type, let reason), .reportSuccess(let type, let reason):
                return ["content_type": type.rawValue, "reason": reason.rawValue]
            case .reportFail(let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .reportFail: return .severe
            default: return .analytic
            }
        }
    }
}

/// The reasons, the note and the two actions. The flow holds the state; this only draws it.
struct ReportSheetView: View {

    @Bindable var flow: ReportFlow
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(ReportReason.allCases) { reason in
                    SelectableRow(title: reason.displayName, isSelected: flow.reason == reason) {
                        flow.onReasonSelected(reason)
                    }
                }
            } header: {
                Text(flow.reasonPrompt)
            }

            Section {
                TextField("Note", text: $flow.note, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                Text(flow.notePrompt)
            }

            if let message = flow.validationMessage {
                InlineMessage(.error, message)
            }
        }
        .navigationTitle(flow.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    flow.onCancelPressed()
                    onClose()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send", role: .confirm) {
                    if flow.onSendPressed() { onClose() }
                }
            }
        }
    }
}
