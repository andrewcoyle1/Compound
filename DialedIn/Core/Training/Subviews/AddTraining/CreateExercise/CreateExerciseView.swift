//
//  CreateExerciseView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 23/09/2025.
//

import SwiftUI

struct CreateExerciseView: View {
    
    @State var presenter: CreateExercisePresenter

    var body: some View {
        
        List {
            nameSection
            trackableMetricSection
            typeSection
            lateralitySection
        }
        .navigationTitle("Create Custom Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .scrollIndicators(.hidden)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .toolbar {
            toolbarContent
        }
        .bottomCTA {
            CallToActionButton {
                presenter.onNextPressed()
            } label: {
                Text("Next")
            }
            .accessibilityIdentifier("CreateExercise.next")
            .disabled(!presenter.canSave)
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Add name", text: Binding(
                get: { presenter.exerciseName ?? "" },
                set: { newValue in
                    presenter.exerciseName = newValue.isEmpty ? nil : newValue
                }
            ))
            .textInputAutocapitalization(.words)
            .accessibilityIdentifier("CreateExercise.name")
       } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise Name")
                Spacer()
                Text("Required")
                    .font(.caption)
            }
        }
    }
    
    private var trackableMetricSection: some View {
        Section {
            HStack(spacing: 0) {
                CustomPickerView(
                    text: presenter.trackableMetricA?.name ?? String(localized: "None"),
                    isHighlighted: presenter.trackableMetricA == nil,
                    action: {
                        presenter.trackableMetricPressed(
                            navigationTitle: String(localized: "Trackable Metric 1"),
                            metric: $presenter.trackableMetricA
                        )
                    }
                )
                .accessibilityIdentifier("CreateExercise.metricA")
                Divider()
                CustomPickerView(
                    text: presenter.trackableMetricB?.name ?? String(localized: "None"),
                    isHighlighted: presenter.trackableMetricB == nil,
                    action: {
                        presenter.trackableMetricPressed(
                            navigationTitle: String(localized: "Trackable Metric 2"),
                            metric: $presenter.trackableMetricB
                        )
                    }
                )
            }
            .removeListRowFormatting()
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Trackable Metric")
                Spacer()
                Text("Required")
                    .font(.caption)
            }
        }
    }
    
    private var typeSection: some View {
        Section {
            CustomPickerView(
                text: presenter.exerciseType?.name ?? String(localized: "None"),
                isHighlighted: presenter.exerciseType == nil,
                action: {
                    presenter.exerciseTypePressed(
                        navigationTitle: String(localized: "Exercise Type"),
                        type: $presenter.exerciseType
                    )
                }
            )
            .removeListRowFormatting()
        } header: {
            Text("Type")
        }
    }

    private var lateralitySection: some View {
        Section {
            CustomPickerView(
                text: presenter.laterality?.name ?? String(localized: "None"),
                isHighlighted: presenter.laterality == nil,
                action: {
                    presenter.lateralityPressed(
                        navigationTitle: String(localized: "Laterality"),
                        item: $presenter.laterality
                    )
                }
            )
            .removeListRowFormatting()
        } header: {
            Text("Laterality")
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onCancelPressed()
            }
        }
        
        #if DEBUG || MOCK
        ToolbarSpacer(.fixed, placement: .topBarLeading)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onDevSettingsPressed()
            } label: {
                Image(systemName: "info")
            }
            .accessibilityLabel("Developer settings")
        }
        #endif
        
    }
}

extension CoreBuilder {
    func createExerciseView(router: AnyRouter) -> some View {
        CreateExerciseView(
            presenter: CreateExercisePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showCreateExerciseView() {
        router.showScreen(.fullScreenCover) { router in
            builder.createExerciseView(router: router)
        }
    }
}

#Preview("As sheet") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.createExerciseView(router: router)
    }
    
}

#Preview("Is saving") {
    @Previewable @State var isPresented: Bool = true
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.createExerciseView(router: router)
    }
    
}

#Preview("As fullscreen cover") {
    @Previewable @State var isPresented: Bool = true
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.createExerciseView(router: router)
    }
    
}

struct CustomPickerView: View {
    
    var text: String
    var isHighlighted: Bool
    var action: () -> Void
    
    var body: some View {
        HStack {
            Text(text)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down")
        }
        .foregroundStyle(isHighlighted ? .secondary : .primary)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.surface)
        .anyButton {
            action()
        }
    }
}
