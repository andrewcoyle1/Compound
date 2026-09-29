import SwiftUI
import PhotosUI

struct RecipePreparationDelegate {

    let recipeName: String
    let servingQuantity: Double
    let recipeTotalWeight: Double
    let ingredients: [RecipeIngredientModel]
    var onMealItemConfirmed: ((MealItemModel) -> Void)?

    var eventParameters: [String: Any]? {
        nil
    }

    static var mock: Self {
        Self(
            recipeName: "Mock Recipe",
            servingQuantity: 1,
            recipeTotalWeight: 458.3,
            ingredients: []
        )
    }
}

enum TimeUnit: String, PickableUnit {
    var id: String { self.rawValue }

    case minute
    case second
    case hour

    var acronym: String {
        switch self {
        case .minute: return "min"
        case .second: return "sec"
        case .hour: return "hr"
        }
    }
}

struct RecipePreparationView: View {

    @State var presenter: RecipePreparationPresenter
    let delegate: RecipePreparationDelegate

    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        List {
            timingSection
            linkSection
            stepsSection
            photoSection
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                if delegate.onMealItemConfirmed != nil {
                    CallToActionButton(
                        isPrimaryAction: true,
                        action: {
                            presenter.onCreateAndAddPressed(
                                delegate: delegate,
                                onConfirm: delegate.onMealItemConfirmed ?? { _ in }
                            )
                        },
                        label: {
                            Text("Create & Add")
                        }
                    )
                }
                CallToActionButton(
                    isPrimaryAction: delegate.onMealItemConfirmed == nil,
                    action: {
                        presenter.onCreatePressed(delegate: delegate)
                    },
                    label: {
                        Text("Create")
                    }
                )
            }
        }
        .navigationTitle(delegate.recipeName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = PlatformImage(data: data) {
                    presenter.image = image
                }
            }
        }
    }

    private var timingSection: some View {
        Group {
            LabeledTextFieldWithUnit<TimeUnit>(
                label: "Preparation Time",
                prompt: String(localized: "Enter preparation time"),
                value: $presenter.prepTime,
                unit: TimeUnit.minute
            )
            LabeledTextFieldWithUnit<TimeUnit>(
                label: "Cooking Time",
                prompt: String(localized: "Enter cooking time"),
                value: $presenter.cookTime,
                unit: TimeUnit.minute
            )
        }
    }

    private var linkSection: some View {
        LabeledTextField(
            label: "Link",
            prompt: String(localized: "Enter link to the recipe"),
            text: $presenter.sourceURL
        )
    }

    private var stepsSection: some View {
        Section {
            ForEach(presenter.preparationSteps.indices, id: \.self) { (idx: Int) in
                TextField("Step \(idx + 1)", text: Binding(
                    get: { presenter.preparationSteps[idx] },
                    set: { presenter.preparationSteps[idx] = $0 }
                ), axis: .vertical)
                .lineLimit(2...)
            }
            .onDelete { presenter.onRemoveStep(atOffsets: $0) }
            .onMove { presenter.onMoveStep(from: $0, toOffset: $1) }
            Button {
                presenter.onAddStepPressed()
            } label: {
                Label("Add Step", systemImage: "plus")
            }
        } header: {
            Text("Preparation Steps")
        }
    }

    private var photoSection: some View {
        // `PhotosPicker`'s label is a `@Sendable` closure in the iOS 26 SDK, so it cannot
        // reach back into the main-actor presenter. Read the image here and let the
        // closure capture the value instead.
        let image = presenter.image

        return Section("Photo") {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Label("Select Photo", systemImage: "photo")
                }
            }
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = RecipePreparationDelegate.mock

    return RouterView { router in
        builder.recipePreparationView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func recipePreparationView(router: AnyRouter, delegate: RecipePreparationDelegate) -> some View {
        RecipePreparationView(
            presenter: RecipePreparationPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showRecipePreparationView(delegate: RecipePreparationDelegate) {
        router.showScreen(.push) { router in
            builder.recipePreparationView(router: router, delegate: delegate)
        }
    }

}
