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
    
    @State var presenter: CreateFoodPresenter
    let delegate: CreateFoodDelegate
    
    var barcodeGenerator = BarcodeGenerator()

    @ScaledMetric(relativeTo: .body) private var imageSide: CGFloat = 120
    
    var body: some View {
        List {
            imageSection
            foodNameSection
            brandNameSection
            barcodeSection
            submitToPublicDatabaseSection
        }
        .navigationTitle("Create Food")
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
                presenter.onNextPressed(delegate: delegate)
            } label: {
                Text("Next")
            }
            .disabled(!presenter.canSave)
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
                Group {
                    if let data = presenter.selectedImageData {
#if canImport(UIKit)
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(Circle())
                                .frame(width: imageSide, height: imageSide)
                        }
#elseif canImport(AppKit)
                        if let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(Circle())
                                .frame(width: imageSide, height: imageSide)
                        }
#endif
                    } else {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: Symbol.meal + ".circle")
                                .iconSize(.hero)
                                .foregroundStyle(.tertiary)
                            Image(systemName: Symbol.edit + ".circle.fill")
                                .iconSize(.medium)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: imageSide)
                .contentShape(.rect)
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
                    .font(.label)
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
            Button {
                presenter.onBarcodeScannerPressed()
            } label: {
                Group {
                    if let barcode = presenter.barcode {
                        VStack {
                            barcodeGenerator.generateBarcode(text: barcode)
                            Text(barcode)
                                .monospacedDigit()
                        }
                    } else {
                        Label("Scan Barcode", systemImage: Symbol.barcode)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
        } header: {
            Text("Barcode")
        }
    }
    
    private var submitToPublicDatabaseSection: some View {
        Section {
            ListRowToggle(
                title: String(localized: "Submit Foods to the Public Database?"),
                subtitle: String(localized: "Toggle this option to contribute new foods"),
                isOn: $presenter.contributeToPublicDatabase
            )
            Button("Learn More") {
                presenter.onLearnMorePressed()
            }
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
