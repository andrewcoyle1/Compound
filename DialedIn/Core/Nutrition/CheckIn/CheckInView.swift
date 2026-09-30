//
//  CheckInView.swift
//  DialedIn
//

import SwiftUI

struct CheckInDelegate {
    /// The ISO week the check-in is reviewing, which is what completing it records.
    var weekStart: Date = CheckInSchedule.weekStart(for: Date(), calendar: .current)

    var eventParameters: [String: Any]? {
        ["check_in_week_start": weekStart]
    }
}

struct CheckInView: View {

    @State var presenter: CheckInPresenter
    let delegate: CheckInDelegate

    var body: some View {
        List {
            switch presenter.currentStep {
            case .introduction:   introductionStep
            case .partialLogging: partialLoggingStep
            case .weighIn:        weighInStep
            case .fasting:        fastingStep
            case .loggingBreak:   loggingBreakStep
            case .programUpdate:  programUpdateStep
            case nil:             EmptyView()
            }
        }
        // Each step's choices are the flow's buttons, pinned under the list as every other flow
        // has them, rather than rows that read as more data.
        .bottomCTA { actions }
        .navigationTitle(presenter.currentStep?.title ?? String(localized: "Weekly Check-In"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    // MARK: - Steps

    private var introductionStep: some View {
        Section {
            summaryRow(title: String(localized: "Days logged"), value: "\(presenter.loggedDayCount) of 7")
            summaryRow(title: String(localized: "Weigh-ins"), value: "\(presenter.weighInCount)")
            summaryRow(title: String(localized: "Weight trend"), value: presenter.trendChangeDescription ?? "Not enough data yet")
        } header: {
            Text("The last seven days")
        }
    }

    @ViewBuilder
    private var partialLoggingStep: some View {
        Section {
            ForEach($presenter.partialRows) { $row in
                Toggle(isOn: $row.isOn) {
                    dayLabel(row)
                }
            }
        } header: {
            Text("Any days you did not finish logging?")
        } footer: {
            Text("Days you mark as incomplete are left out of your expenditure estimate.")
        }
    }

    @ViewBuilder
    private var weighInStep: some View {
        Section {
            Text("A recent weigh-in keeps the trend honest.")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
        WeightPickerInput(
            unit: $presenter.unit,
            selectedKilograms: $presenter.selectedKilograms,
            selectedKilogramsTenths: $presenter.selectedKilogramsTenths,
            selectedPounds: $presenter.selectedPounds,
            selectedPoundsTenths: $presenter.selectedPoundsTenths
        )
    }

    @ViewBuilder
    private var fastingStep: some View {
        Section {
            ForEach($presenter.fastingRows) { $row in
                Toggle(isOn: $row.isOn) {
                    dayLabel(row)
                }
            }
        } header: {
            Text("Did you fast on any of these days?")
        } footer: {
            Text("A fasting day counts as 0 kcal rather than a day you forgot to log.")
        }
    }

    @ViewBuilder
    private var loggingBreakStep: some View {
        if presenter.hasOpenLoggingBreak {
            Section {
                Text("Your expenditure estimate is frozen while the break is open.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            } header: {
                Text("You are on a logging break")
            }
        } else {
            Section {
                Text("Your estimate freezes until you end the break, and the check-in stops asking.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Take a break from logging?")
            }
        }
    }

    @ViewBuilder
    private var programUpdateStep: some View {
        if let summary = presenter.proposalSummary {
            Section {
                Text(summary)
                    .font(.rowDetail)
            } header: {
                Text("New targets suggested")
            }
        } else {
            Section {
                summaryRow(title: String(localized: "Expenditure"), value: presenter.expenditureDescription)
                summaryRow(title: String(localized: "Weight trend"), value: presenter.trendChangeDescription ?? "Not enough data yet")
            } header: {
                Text("Your targets are unchanged this week")
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch presenter.currentStep {
        case .introduction, .partialLogging, .fasting:
            actionButton("Continue") { presenter.onContinuePressed() }
        case .weighIn:
            actionButton("Log Weight") { presenter.onLogWeightPressed() }
            actionButton("Skip", isPrimary: false) { presenter.onSkipWeighInPressed() }
        case .loggingBreak:
            if presenter.hasOpenLoggingBreak {
                actionButton("End My Break") { presenter.onEndLoggingBreakPressed() }
                actionButton("Stay on a Break", isPrimary: false) { presenter.onContinuePressed() }
            } else {
                actionButton("No Thanks") { presenter.onContinuePressed() }
                actionButton("Start a Break", isPrimary: false) { presenter.onStartLoggingBreakPressed() }
            }
        case .programUpdate:
            if presenter.proposalSummary != nil {
                actionButton("Accept") { presenter.onAcceptProposalPressed() }
                actionButton("Not Now", isPrimary: false) { presenter.onDonePressed() }
            } else {
                actionButton("Done") { presenter.onDonePressed() }
            }
        case nil:
            EmptyView()
        }
    }

    private func actionButton(_ title: LocalizedStringKey, isPrimary: Bool = true, action: @escaping () -> Void) -> some View {
        CallToActionButton(isPrimaryAction: isPrimary, isLoading: isPrimary && presenter.isSaving, action: action) {
            Text(title)
        }
        .disabled(presenter.isSaving)
    }

    // MARK: - Pieces

    private func summaryRow(title: String, value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func dayLabel(_ row: CheckInDayRow) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(row.weekdayName)
            Text(row.intakeDescription)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
    }
}

extension CoreBuilder {
    func checkInView(router: AnyRouter, delegate: CheckInDelegate) -> some View {
        CheckInView(
            presenter: CheckInPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showCheckInView(delegate: CheckInDelegate) {
        router.showScreen(.sheetConfig(config: .full)) { router in
            builder.checkInView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    return RouterView { router in
        builder.checkInView(router: router, delegate: CheckInDelegate())
    }
}
