//
//  CreateFoodView.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/09/2025.
//

import SwiftUI
import PhotosUI

struct CreateFoodDelegate {
    let mealItems: Binding<[MealItemModel]>?
    
    init(mealItems: Binding<[MealItemModel]>? = nil) {
        self.mealItems = mealItems
    }
}

struct CreateFoodView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @State var presenter: CreateFoodPresenter
    let delegate: CreateFoodDelegate
    
    var barcodeGenerator = BarcodeGenerator()
    
    var body: some View {
        List {
            imageSection
            foodNameSection
            brandNameSection
            barcodeSection
            submitToPublicDatabaseSection
        }
        .navigationBarTitle("Create Food")
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
        .safeAreaInset(edge: .bottom) {
            CallToActionButton {
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Next")
            }
            .disabled(!presenter.canSave)
            .padding(.bottom)
        }
        .onChange(of: presenter.selectedPhotoItem) {
            guard let newItem = presenter.selectedPhotoItem else { return }
            
            Task {
                await presenter.onImageSelectorChanged(newItem)
            }
        }
    }
    
    private var imageSection: some View {
        Section {
            Button {
                presenter.onImageSelectorPressed()
            } label: {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.001))
                    Group {
                        if let data = presenter.selectedImageData {
#if canImport(UIKit)
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .frame(width: 120, height: 120)
                            }
#elseif canImport(AppKit)
                            if let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(Circle())
                                    .frame(width: 120, height: 120)
                            }
#endif
                        } else {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: "fork.knife.circle")
                                    .font(.system(size: 100))
                                    .foregroundStyle(.secondary.opacity(0.4))
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24))
                                    .padding(12)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            }
            .accessibilityLabel("Choose food image")
        }
        .removeListRowFormatting()
        .photosPicker(isPresented: $presenter.isImagePickerPresented, selection: $presenter.selectedPhotoItem, matching: .images)
    }
    
    private var foodNameSection: some View {
        Section {
            TextField("Add name", text: $presenter.name)
                .textInputAutocapitalization(.words)
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Food Name")
                Spacer()
                Text("Required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var brandNameSection: some View {
        Section {
            TextField(
                "Add name",
                text: Binding(
                    get: { presenter.brandName ?? "" },
                    set: { newValue in
                        presenter.brandName = newValue.isEmpty ? nil : newValue
                    }
                )
            )
            .textInputAutocapitalization(.words)
        } header: {
            Text("Brand Name")
        }
    }
    
    private var barcodeSection: some View {
        Section {
            Group {
                if let barcode = presenter.barcode {
                    VStack {
                        barcodeGenerator.generateBarcode(text: barcode)
                        Text(barcode)
                    }
                } else {
                    Label("Barcode", systemImage: "barcode")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .anyButton(.press) {
                presenter.onBarcodeScannerPressed()
            }
        } header: {
            Text("Barcode")
        }
    }
    
    private var submitToPublicDatabaseSection: some View {
        Section {
            CustomToggleView(
                title: String(localized: "Submit Foods to the Public Database?"),
                subtitle: String(localized: "Toggle this option to contribute new foods"),
                bool: $presenter.contributeToPublicDatabase
            )
            .removeListRowFormatting()
            HStack {
                Text("Learn More")
                    .padding(8)
                    .background(.secondary.opacity(0.3), in: .capsule)
                Spacer()
            }
            .anyButton(.press) {
                presenter.onLearnMorePressed()
            }
        }
    }
    
    private func inputRow(label: String, value: Binding<Double?>, unit: String? = nil) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(" " + (unit ?? ""))
                .foregroundStyle(value.wrappedValue != nil ? .primary : .secondary)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                presenter.onCancelPressed()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Cancel")
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
    func createFoodView(router: AnyRouter, delegate: CreateFoodDelegate) -> some View {
        CreateFoodView(
            presenter: CreateFoodPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showCreateFoodView(delegate: CreateFoodDelegate) {
        router.showScreen(.sheet) { router in
            builder.createFoodView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = CreateFoodDelegate()
    
    RouterView { router in
        builder.createFoodView(router: router, delegate: delegate)
    }
    
}
