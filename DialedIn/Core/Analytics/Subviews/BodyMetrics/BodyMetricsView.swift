import SwiftUI

struct BodyMetricsDelegate {

}

struct BodyMetricsView: View {

    @State var presenter: BodyMetricsPresenter
    let delegate: BodyMetricsDelegate

    private let bodyMetricsColor = Color.green

    var body: some View {
        List {
            Group {
                // `presenter.sections` is a computed list; four hardcoded subscripts here traded a
                // crash for every section the presenter might ever add or drop.
                ForEach(presenter.sections) { section in
                    dataDrivenSection(section)
                }
                ratiosSection
                progressPhotosSection
            }
            .listSectionMargins(.horizontal, 0)
            .listRowSeparator(.hidden)
        }
        .navigationTitle("Body Metrics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    presenter.onDismissPressed()
                }
            }
        }
    }

    private func dataDrivenSection(_ section: BodyMetricsSection) -> some View {
        Section {
            AnalyticsCardGrid {
                ForEach(section.cards) { card in
                    BodyMetricCardView(card: card, themeColor: bodyMetricsColor) {
                        presenter.onMeasurementPressed(card.id, themeColor: bodyMetricsColor)
                    }
                }
            }
        } header: {
            SectionHeaderView(title: section.header)
        }
    }

    private var progressPhotosSection: some View {
        Section {
            Button {
                presenter.onProgressPhotosPressed()
            } label: {
                Label("Progress Photos", systemImage: "photo.stack")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(bodyMetricsColor)
        } header: {
            SectionHeaderView(title: String(localized: "Photos"))
        }
    }

    /// Waist-to-height and waist-to-hip, both computed from logged measurements. Tapping opens the
    /// ratio's history on the shared `MetricDetailView`, the same as every measured card here.
    private var ratiosSection: some View {
        Section {
            AnalyticsCardGrid {
                if presenter.ratioCards.isEmpty {
                    AnalyticsEmptyCard(message: String(localized: "Log a waist measurement to see your body ratios."))
                } else {
                    ForEach(presenter.ratioCards) { card in
                        BodyRatioCardView(card: card, themeColor: bodyMetricsColor) {
                            presenter.onRatioPressed(card.id, themeColor: bodyMetricsColor)
                        }
                    }
                }
            }
        } header: {
            SectionHeaderView(title: String(localized: "Ratios"))
        }
    }
}

extension CoreBuilder {

    func bodyMetricsView(router: AnyRouter, delegate: BodyMetricsDelegate) -> some View {
        BodyMetricsView(
            presenter: BodyMetricsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showBodyMetricsView(delegate: BodyMetricsDelegate) {
        router.showScreen(.sheet) { router in
            builder.bodyMetricsView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = BodyMetricsDelegate()

    return RouterView { router in
        builder.bodyMetricsView(router: router, delegate: delegate)
    }
    
}
