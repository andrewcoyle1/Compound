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
                CustomLabelButtonView(
                    title: String(localized: "Estimation Method"),
                    subtitle: presenter.estimationMethod.title) {
                        editMenu(
                            options: presenter.estimationMethods,
                            selection: presenter.estimationMethod,
                            onSelect: { presenter.estimationMethod = $0 }
                        )
                    }
                CustomLabelButtonView(
                    title: String(localized: "Calculation Start Date"),
                    subtitle: presenter.calculationStartDateLabel) {
                        Text("Edit")
                            .padding(.horizontal, 8)
                            .padding(8)
                            .background(Color.secondary.opacity(0.2), in: .capsule)
                            .anyButton(.press) {
                                presenter.onEditStartDatePressed()
                            }
                    }
                CustomLabelButtonView(
                    title: String(localized: "BMR Equation"),
                    subtitle: presenter.bmrEquation.title) {
                        editMenu(
                            options: presenter.bmrEquations,
                            selection: presenter.bmrEquation,
                            onSelect: { presenter.bmrEquation = $0 }
                        )
                    }
            } header: {
                Text("Initial Estimate")
            }

            Section {
                CustomLabelButtonView(
                    title: String(localized: "Calculation Mode"),
                    subtitle: presenter.calculationMode.title) {
                        editMenu(
                            options: presenter.calculationModes,
                            selection: presenter.calculationMode,
                            onSelect: { presenter.calculationMode = $0 }
                        )
                    }
                CustomLabelButtonView(
                    title: String(localized: "Algorithm"),
                    subtitle: presenter.algorithmVersion.title) {
                        editMenu(
                            options: presenter.algorithmVersions,
                            selection: presenter.algorithmVersion,
                            onSelect: { presenter.algorithmVersion = $0 }
                        )
                    }
            } header: {
                Text("Expenditure Calculation")
            } footer: {
                Text("Dynamic reads your logged intake against your weight trend over the last four weeks. Fixed holds the figure where it is.")
            }

            Section {
                CustomToggleView(
                    title: String(localized: "Step-Informed Updates"),
                    subtitle: String(localized: "Uses step trends to speed up expenditure updates during periods where the step data improves confidence"),
                    bool: Binding(
                        get: { presenter.stepInformedUpdates },
                        set: { presenter.stepInformedUpdates = $0 }
                    )
                )
                CustomToggleView(
                    title: String(localized: "Predictive Goal Adjustment"),
                    subtitle: String(localized: "Applies a predictive adjustment to expenditure based on the likely impact of goal changes"),
                    bool: Binding(
                        get: { presenter.predictiveGoalAdjustments },
                        set: { presenter.predictiveGoalAdjustments = $0 }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(presenter.expenditureValueText)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(presenter.expenditureStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let stepText = presenter.stepAdjustmentText {
                    Text(stepText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Today's Expenditure")
        }
    }

    private var startDatePicker: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Start date",
                    selection: Binding(
                        get: { presenter.calculationStartDate },
                        set: { presenter.calculationStartDate = $0 }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presenter.isChoosingStartDate = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The row keeps its "Edit" capsule, which opens a menu rather than another screen — these are
    /// all short lists, and each option carries its own explanation.
    private func editMenu<Option: Identifiable & Equatable>(
        options: [Option],
        selection: Option,
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option: ExpenditureOptionDescribing {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    if option == selection {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            Text("Edit")
                .padding(.horizontal, 8)
                .padding(8)
                .background(Color.secondary.opacity(0.2), in: .capsule)
        }
    }
}

/// Lets one menu helper serve every expenditure option enum without repeating it four times.
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
