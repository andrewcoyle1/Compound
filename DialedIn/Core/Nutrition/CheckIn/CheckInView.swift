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
        .navigationTitle(presenter.currentStep?.title ?? "Weekly check-in")
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
            continueButton("Continue")
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
        Section {
            continueButton("Continue")
        }
    }

    @ViewBuilder
    private var weighInStep: some View {
        Section {
            Text("A recent weigh-in keeps the trend honest.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        WeightPickerInput(
            unit: $presenter.unit,
            selectedKilograms: $presenter.selectedKilograms,
            selectedPounds: $presenter.selectedPounds
        )
        Section {
            Button("Log weight") {
                presenter.onLogWeightPressed()
            }
            .disabled(presenter.isSaving)
            Button("Skip") {
                presenter.onSkipWeighInPressed()
            }
            .disabled(presenter.isSaving)
        }
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
        Section {
            continueButton("Continue")
        }
    }

    @ViewBuilder
    private var loggingBreakStep: some View {
        if presenter.hasOpenLoggingBreak {
            Section {
                Button("End my break") {
                    presenter.onEndLoggingBreakPressed()
                }
                .disabled(presenter.isSaving)
                continueButton("Stay on a break")
            } header: {
                Text("You are on a logging break")
            } footer: {
                Text("Your expenditure estimate is frozen while the break is open.")
            }
        } else {
            Section {
                Button("Start a break") {
                    presenter.onStartLoggingBreakPressed()
                }
                .disabled(presenter.isSaving)
                continueButton("No thanks")
            } header: {
                Text("Take a break from logging?")
            } footer: {
                Text("Your estimate freezes until you end the break, and the check-in stops asking.")
            }
        }
    }

    @ViewBuilder
    private var programUpdateStep: some View {
        if let summary = presenter.proposalSummary {
            Section {
                Text(summary)
                    .font(.subheadline)
                Button("Accept") {
                    presenter.onAcceptProposalPressed()
                }
                .disabled(presenter.isSaving)
                Button("Not now") {
                    presenter.onDonePressed()
                }
                .disabled(presenter.isSaving)
            } header: {
                Text("New targets suggested")
            }
        } else {
            Section {
                summaryRow(title: String(localized: "Expenditure"), value: presenter.expenditureDescription)
                summaryRow(title: String(localized: "Weight trend"), value: presenter.trendChangeDescription ?? "Not enough data yet")
                Button("Done") {
                    presenter.onDonePressed()
                }
                .disabled(presenter.isSaving)
            } header: {
                Text("Your targets are unchanged this week")
            }
        }
    }

    // MARK: - Pieces

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func dayLabel(_ row: CheckInDayRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.weekdayName)
            Text(row.intakeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func continueButton(_ title: String) -> some View {
        Button(title) {
            presenter.onContinuePressed()
        }
        .disabled(presenter.isSaving)
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
        router.showScreen(.sheetConfig(config: ResizableSheetConfig(detents: [.large]))) { router in
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
