import SwiftUI

struct ProgressPhotoCompareDelegate {
    let before: ProgressPhotoModel
    let after: ProgressPhotoModel
    let beforeCaption: String
    let afterCaption: String
}

/// Two photos side by side, or stacked with a slider that wipes from one to the other.
///
/// ponytail: a plain view with no presenter — it reads nothing and does nothing beyond its own
/// layout toggle. Give it a presenter if it grows actions.
struct ProgressPhotoCompareView: View {

    let delegate: ProgressPhotoCompareDelegate

    private enum Mode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case slider = "Slider"
    }

    @State private var mode: Mode = .sideBySide
    /// How much of the older photo shows, from the leading edge.
    @State private var split: Double = 0.5

    var body: some View {
        VStack(spacing: Spacing.l) {
            Picker("Layout", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .sideBySide:
                HStack(alignment: .top, spacing: Spacing.s) {
                    column(delegate.before, caption: delegate.beforeCaption)
                    column(delegate.after, caption: delegate.afterCaption)
                }
            case .slider:
                sliderOverlay
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func photo(_ photo: ProgressPhotoModel) -> some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay { ImageLoaderView(urlString: photo.imageUrl ?? "", resizingMode: .fill) }
            .clipped()
    }

    private func column(_ model: ProgressPhotoModel, caption: String) -> some View {
        VStack(spacing: Spacing.s) {
            photo(model)
                .clipShape(.rect(cornerRadius: Radius.m, style: .continuous))
            Text(caption)
                .font(.label)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var sliderOverlay: some View {
        VStack(spacing: Spacing.m) {
            photo(delegate.after)
                .overlay {
                    GeometryReader { geometry in
                        let width = geometry.size.width * split
                        photo(delegate.before)
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: width)
                            }
                        Rectangle()
                            .fill(.white)
                            .frame(width: 2)
                            .offset(x: width - 1)
                    }
                }
                .clipShape(.rect(cornerRadius: Radius.m, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(delegate.beforeCaption) over \(delegate.afterCaption)")
            Slider(value: $split, in: 0...1) {
                Text("Reveal")
            } minimumValueLabel: {
                Text("Before").font(.label)
            } maximumValueLabel: {
                Text("After").font(.label)
            }
            HStack {
                Text(delegate.beforeCaption)
                Spacer()
                Text(delegate.afterCaption)
            }
            .font(.label)
            .foregroundStyle(.secondary)
        }
    }
}

extension CoreRouter {

    func showProgressPhotoCompareView(delegate: ProgressPhotoCompareDelegate) {
        router.showScreen(.push) { _ in
            ProgressPhotoCompareView(delegate: delegate)
        }
    }
}

#Preview {
    NavigationStack {
        ProgressPhotoCompareView(
            delegate: ProgressPhotoCompareDelegate(
                before: ProgressPhotoModel.mocks[0],
                after: ProgressPhotoModel.mocks[1],
                beforeCaption: "Before",
                afterCaption: "After"
            )
        )
    }
}
