//
//  CreateExerciseView.swift
//  Compound
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
            detailsSection
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
    
    /// Short option lists, so in-row menus rather than a sheet per choice.
    private var trackableMetricSection: some View {
        Section {
            optionPicker("Metric 1", selection: $presenter.trackableMetricA)
                .accessibilityIdentifier("CreateExercise.metricA")
            optionPicker("Metric 2", selection: $presenter.trackableMetricB)
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Trackable Metric")
                Spacer()
                Text("Required")
                    .font(.caption)
            }
        }
    }

    private var detailsSection: some View {
        Section {
            optionPicker("Type", selection: $presenter.exerciseType)
            optionPicker("Laterality", selection: $presenter.laterality)
        }
    }

    /// A menu of every option, each with its description, plus None for a field left empty.
    private func optionPicker<Item: PickableItem>(_ title: LocalizedStringKey, selection: Binding<Item?>) -> some View {
        Picker(title, selection: selection) {
            Text("None").tag(Item?.none)
            ForEach(Array(Item.allCases), id: \.self) { item in
                VStack(alignment: .leading) {
                    Text(item.name)
                    if let description = item.description {
                        Text(description)
                    }
                }
                .tag(Optional(item))
                .accessibilityIdentifier("EnumPicker.\(item.name)")
            }
        }
        .pickerStyle(.menu)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onCancelPressed()
            }
        }
        
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
