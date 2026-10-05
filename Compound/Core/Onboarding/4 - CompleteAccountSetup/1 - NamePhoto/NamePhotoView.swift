//
//  NamePhotoView.swift
//  Compound
//
//  Created by Andrew Coyle on 20/10/2025.
//

import SwiftUI
import PhotosUI

struct NamePhotoView: View {

    @State var presenter: NamePhotoPresenter

    private enum Field { case firstName, lastName }
    @FocusState private var focusedField: Field?

    var body: some View {
        OnboardingStepScaffold(
            title: "What's Your Name?",
            // The sentence the removed "Ready to Begin?" screen held on its own.
            subtitle: "A few details tailor your recommendations to your fitness journey.",
            progress: OnboardingStep.completeAccountSetup.progress,
            primary: .init(title: "Continue", isEnabled: presenter.canContinue, identifier: "Continue") { presenter.saveAndContinue() },
            onDevSettingsPressed: nil
        ) {
            imageSection
            nameSection
        }
        .scrollIndicators(.hidden)
        // This is the first screen after the paywall, which back must not return to.
        .navigationBarBackButtonHidden()
        .onAppear {
            presenter.onViewAppear()
            // No focus on appear: with the field focused as the push lands, Continue's loading modal
            // swallowed the push to the next step and the screen stayed put (OnboardingUITests).
            presenter.prefillFromCurrentUser()
        }
        .onDisappear { presenter.onViewDisappear() }
        .onChange(of: presenter.selectedPhotoItem) {
            Task {
                await presenter.handlePhotoSelection()
            }
        }
    }

    private var imageSection: some View {
        Section {
            Button {
                presenter.isImagePickerPresented = true
            } label: {
                photo
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(presenter.hasPhoto ? "Change Photo" : "Add Photo (Optional)")
            .photosPicker(isPresented: $presenter.isImagePickerPresented, selection: $presenter.selectedPhotoItem, matching: .images)

            if presenter.hasPhoto {
                Button(role: .destructive) {
                    presenter.removePhoto()
                } label: {
                    Text("Remove Photo")
                        .frame(maxWidth: .infinity)
                }
            }

            if presenter.photoLoadFailed {
                InlineMessage(.error, "Couldn't load that photo. Try a different one.")
            }
        }
        .removeListRowFormatting()
    }

    @ViewBuilder
    private var photo: some View {
        if let data = presenter.selectedImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: photoSide, height: photoSide)
                .clipShape(.circle)
        } else if let image = presenter.currentUser?.profileImageNameCalculated {
            ImageLoaderView(urlString: image)
                .frame(width: photoSide, height: photoSide)
                .clipShape(.circle)
        } else {
            VStack(spacing: Spacing.s) {
                Image(systemName: Symbol.profile)
                    .iconSize(.hero)
                    .foregroundStyle(.tint)
                Text("Add Photo (Optional)")
                    .font(.label)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The photo matches the placeholder glyph's height and scales with it.
    @ScaledMetric(relativeTo: .body) private var photoSide = IconSize.hero.points + Spacing.xl

    private var nameSection: some View {
        Section {
            TextField("First name", text: $presenter.firstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .firstName)
                .submitLabel(.next)
                .onSubmit { focusedField = .lastName }
            TextField("Last name (optional)", text: $presenter.lastName)
                .textContentType(.familyName)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .lastName)
                .submitLabel(.continue)
                .onSubmit { presenter.saveAndContinue() }
        } header: {
            Text("Your Name")
        } footer: {
            Text("Help us personalize your experience by providing your name. You can also add a profile photo if you'd like.")
        }
    }
}

extension CoreBuilder {
    func namePhotoView(router: AnyRouter) -> some View {
        NamePhotoView(
            presenter: NamePhotoPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self))
        )
    }
}

extension CoreRouter {
    func showNamePhotoView() {
        router.showScreen(.push) { router in
            builder.namePhotoView(router: router)
        }
    }
}

#Preview {
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))
    RouterView { router in
        builder.namePhotoView(router: router)
    }
    
}
