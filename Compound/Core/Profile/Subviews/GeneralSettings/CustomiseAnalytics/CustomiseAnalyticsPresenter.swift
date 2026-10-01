import SwiftUI

@Observable
@MainActor
class CustomiseAnalyticsPresenter {
    
    private let interactor: CustomiseAnalyticsInteractor
    private let router: CustomiseAnalyticsRouter

    /// Snapshot-and-save, the same idiom as `FoodLogSettingsPresenter` and
    /// `WorkoutSettingsPresenter`: each toggle writes into `settings` and fires a save. No Save
    /// button, which is why the screen's toolbar confirm button — an empty action — is gone.
    private var settings: AnalyticsSettings

    init(interactor: CustomiseAnalyticsInteractor, router: CustomiseAnalyticsRouter) {
        self.interactor = interactor
        self.router = router
        self.settings = interactor.analyticsSettings
    }

    let sections: [AnalyticsSection] = AnalyticsSection.allCases

    func isVisible(_ section: AnalyticsSection) -> Bool {
        settings.isVisible(section)
    }

    func setVisible(_ isVisible: Bool, for section: AnalyticsSection) {
        settings.setVisible(isVisible, for: section)
        interactor.trackEvent(event: Event.sectionVisibilityChanged(section: section, isVisible: isVisible))
        save()
    }

    /// Hiding every section would leave the tab with only its header and the More list, which is
    /// recoverable but reads as a broken screen — so the last visible one cannot be switched off.
    func canHide(_ section: AnalyticsSection) -> Bool {
        guard isVisible(section) else { return true }
        return sections.filter { isVisible($0) }.count > 1
    }

    var hiddenCount: Int {
        sections.filter { !isVisible($0) }.count
    }

    func onShowAllPressed() {
        for section in sections where !isVisible(section) {
            settings.setVisible(true, for: section)
        }
        interactor.trackEvent(event: Event.showAllPressed)
        save()
    }

    private func save() {
        let settings = settings
        Task {
            do {
                try await interactor.saveAnalyticsSettings(settings)
            } catch {
                interactor.trackEvent(event: Event.saveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Settings"), subtitle: String(localized: "Please try again."))
            }
        }
    }
    
    /// Re-read rather than trusting the snapshot taken at init: `save()` writes the whole
    /// `AnalyticsSettings` document, so a copy taken when this screen was first pushed would
    /// revert a change made on another device while it sat there.
    func onViewAppear() {
        settings = interactor.analyticsSettings
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

}

extension CustomiseAnalyticsPresenter {
    
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case sectionVisibilityChanged(section: AnalyticsSection, isVisible: Bool)
        case showAllPressed
        case saveFail(error: Error)

        var eventName: String {
            switch self {
            case .saveFail: return "CustomiseAnalyticsView_Save_Fail"
            case .onAppear:                 return "CustomiseAnalyticsView_Appear"
            case .onDisappear:              return "CustomiseAnalyticsView_Disappear"
            case .sectionVisibilityChanged: return "CustomiseAnalyticsView_SectionVisibility_Changed"
            case .showAllPressed:           return "CustomiseAnalyticsView_ShowAll_Press"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .saveFail(error: let error): return error.eventParameters
            case .sectionVisibilityChanged(section: let section, isVisible: let isVisible):
                return ["section": section.rawValue, "is_visible": isVisible]
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .saveFail: return .severe
            default:
                return .analytic
            }
        }
    }
}
