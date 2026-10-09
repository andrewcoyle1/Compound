import SwiftUI

struct ExpenditureSettingsDelegate {
    
}

struct ExpenditureSettingsView: View {
    
    @State var presenter: ExpenditureSettingsPresenter
    let delegate: ExpenditureSettingsDelegate
    
    var body: some View {
        List {
            estimateSection

            Section {
                optionPicker("Estimation Method", options: presenter.estimationMethods, selection: $presenter.estimationMethod)
                ListRowButton(
                    title: String(localized: "Calculation Start Date"),
                    subtitle: presenter.calculationStartDateLabel
                ) {
                    presenter.onEditStartDatePressed()
                }
                optionPicker("BMR Equation", options: presenter.bmrEquations, selection: $presenter.bmrEquation)
            } header: {
                MethodInfoHeader(title: "Initial Estimate", info: .restingMetabolicRate)
            }

            Section {
                optionPicker("Calculation Mode", options: presenter.calculationModes, selection: $presenter.calculationMode)
                optionPicker("Algorithm", options: presenter.algorithmVersions, selection: $presenter.algorithmVersion)
            } header: {
                Text("Expenditure Calculation")
            } footer: {
                Text("Dynamic learns from your logged intake and your weight trend, day by day. Fixed holds the figure where it is.")
            }

            Section {
                ListRowToggle(
                    title: String(localized: "Step-Informed Updates"),
                    subtitle: String(localized: "Use your steps to update expenditure sooner"),
                    isOn: Binding(
                        get: { presenter.stepInformedUpdates },
                        set: { presenter.stepInformedUpdates = $0 }
                    )
                )
            } header: {
                Text("Expenditure Modifiers")
            }
        }
        .navigationTitle("Expenditure")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presenter.isChoosingStartDate) {
            startDatePicker
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    /// Today's figure and one line saying where it came from. The controls below all change this
    /// number, so it belongs above them rather than on another screen.
    private var estimateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(presenter.expenditureValueText)
                    .font(.metricLarge)
                if let rangeText = presenter.expenditureRangeText {
                    Text(rangeText)
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }
                Text(presenter.expenditureStatusText)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                if let stepText = presenter.stepAdjustmentText {
                    Text(stepText)
                        .font(.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            MethodInfoHeader(title: "Today's Expenditure", info: .adaptiveExpenditure)
        }
    }

    private var startDatePicker: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Start date",
                    selection: Binding(
                        get: { presenter.calculationStartDate },
                        // Picking a day is the whole choice, so it closes the sheet too.
                        set: {
                            presenter.calculationStartDate = $0
                            presenter.isChoosingStartDate = false
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                Button("Use Default") {
                    presenter.onClearStartDatePressed()
                }
                .padding(.top)
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .navigationTitle("Calculation Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { presenter.onCancelStartDatePressed() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { presenter.isChoosingStartDate = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// An inline menu picker: these are all short lists, so a menu beats another screen.
    private func optionPicker<Option: Identifiable & Hashable & ExpenditureOptionDescribing>(
        _ title: LocalizedStringKey,
        options: [Option],
        selection: Binding<Option>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(options) { option in
                Text(option.title).tag(option)
            }
        }
    }
}

/// Lets one picker helper serve every expenditure option enum without repeating it four times.
protocol ExpenditureOptionDescribing {
    var title: String { get }
    var subtitle: String { get }
}

extension ExpenditureEstimationMethod: ExpenditureOptionDescribing { }
extension BMREquation: ExpenditureOptionDescribing { }
extension ExpenditureCalculationMode: ExpenditureOptionDescribing { }
extension ExpenditureAlgorithmVersion: ExpenditureOptionDescribing { }

extension CoreBuilder {
    
    func expenditureSettingsView(router: AnyRouter, delegate: ExpenditureSettingsDelegate) -> some View {
        ExpenditureSettingsView(
            presenter: ExpenditureSettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showExpenditureSettingsView(delegate: ExpenditureSettingsDelegate) {
        router.showScreen(.push) { router in
            builder.expenditureSettingsView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = ExpenditureSettingsDelegate()
    
    return RouterView { router in
        builder.expenditureSettingsView(router: router, delegate: delegate)
    }
    
}
