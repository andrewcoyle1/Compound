//
//  ProfileAppInfoPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

// MARK: - App Icon

/// The App Icon row. There is only one icon in the asset catalogue, so the screen states that
/// rather than offering a choice — the presenter is tracking and nothing else.
@MainActor
struct ProfileAppIconPresenterTests {

    private final class Interactor: SpyGlobalInteractor, AppIconInteractor { }

    private final class Router: AppIconRouter { }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let interactor = Interactor()
        let presenter = AppIconPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.onViewDisappear()

        #expect(interactor.trackedScreenEventNames == ["AppIconView_Appear"])
        #expect(interactor.trackedEventNames == ["AppIconView_Disappear"])
    }
}

// MARK: - About

/// The About screen: the version the user reads out when they report a problem, and the way
/// through to the licences.
@MainActor
struct ProfileAboutPresenterTests {

    private final class Interactor: SpyGlobalInteractor, AboutInteractor { }

    private final class Router: AboutRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var licencesShownCount = 0

        func showLicencesView(delegate: LicencesDelegate) {
            licencesShownCount += 1
        }
    }

    private struct Screen {
        let presenter: AboutPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: AboutPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The version and build are what support asks for first. An empty string here means the
    /// screen shows a blank line where the answer should be.
    @Test("Test The Screen Shows A Version And Build")
    func testTheScreenShowsAVersionAndBuild() {
        let screen = makeScreen()

        #expect(!screen.presenter.appVersion.isEmpty)
        #expect(!screen.presenter.appBuild.isEmpty)
    }

    /// Third-party licences are a legal obligation, so the only route to them has to work.
    @Test("Test Licences Can Be Reached From About")
    func testLicencesCanBeReachedFromAbout() {
        let screen = makeScreen()

        screen.presenter.onLicencesPressed()

        #expect(screen.router.licencesShownCount == 1)
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let screen = makeScreen()
        let delegate = AboutDelegate()

        screen.presenter.onViewAppear(delegate: delegate)
        screen.presenter.onViewDisappear(delegate: delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["AboutView_Appear"])
        #expect(screen.interactor.trackedEventNames == ["AboutView_Disappear"])
    }
}

// MARK: - Licences

/// The licences list. It is a legal notice, so what matters is that every package the app ships
/// appears exactly once and that nothing is silently dropped by the grouping.
@MainActor
struct ProfileLicencesPresenterTests {

    private final class Interactor: SpyGlobalInteractor, LicencesInteractor { }

    private final class Router: LicencesRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private func makePresenter() -> (LicencesPresenter, Interactor) {
        let interactor = Interactor()
        return (LicencesPresenter(interactor: interactor, router: Router()), interactor)
    }

    /// Grouping by licence must not lose a package. A notice that omits a dependency is the one
    /// failure mode that actually matters here.
    @Test("Test Every Package Appears Exactly Once")
    func testEveryPackageAppearsExactlyOnce() {
        let (presenter, _) = makePresenter()

        let listed = presenter.groups.flatMap { $0.packages }.map(\.name)

        #expect(listed.sorted() == Licence.all.map(\.name).sorted())
        #expect(Set(listed).count == listed.count)
    }

    /// Packages that ship no licence file are shown as unstated rather than assumed, and sorted to
    /// the bottom so the stated ones read first.
    @Test("Test Packages With No Stated Licence Are Grouped Last")
    func testPackagesWithNoStatedLicenceAreGroupedLast() {
        let (presenter, _) = makePresenter()

        let unstatedIndex = presenter.groups.firstIndex { $0.licence.hasPrefix("License not") }

        if let unstatedIndex {
            #expect(unstatedIndex == presenter.groups.count - 1)
        }
    }

    /// These were logged as "AppView_Appear" and "AppView_Disappear" — the app's own screen events —
    /// so every visit to the licences list was counted as a launch of the app itself.
    @Test("Test The Screen Is Tracked Under Its Own Name")
    func testTheScreenIsTrackedUnderItsOwnName() {
        let (presenter, interactor) = makePresenter()

        presenter.onViewAppear()
        presenter.onViewDisappear()

        #expect(interactor.trackedScreenEventNames == ["LicencesView_Appear"])
        #expect(interactor.trackedEventNames == ["LicencesView_Disappear"])
    }
}

// MARK: - Legal

/// The four legal documents. The presenter only records which one was opened — the link itself is
/// the view's job — but which one was opened is the whole content of the event.
@MainActor
struct ProfileLegalPresenterTests {

    private final class Interactor: SpyGlobalInteractor, LegalInteractor { }

    private final class Router: LegalRouter { }

    @Test("Test Opening Each Document Is Tracked")
    func testOpeningEachDocumentIsTracked() {
        let interactor = Interactor()
        let presenter = LegalPresenter(interactor: interactor, router: Router())

        for document in LegalDocument.allCases {
            presenter.onDocumentPressed(document)
        }

        #expect(interactor.trackedEventNames.count == LegalDocument.allCases.count)
        #expect(interactor.trackedEventNames.allSatisfy { $0 == "LegalView_Document_Press" })
    }

    /// Every document needs a link that resolves. A nil URL is a row that does nothing when tapped,
    /// and the App Store requires the privacy policy in particular to open.
    @Test("Test Every Legal Document Has A Usable Link")
    func testEveryLegalDocumentHasAUsableLink() {
        for document in LegalDocument.allCases {
            #expect(document.url != nil, "\(document.title) has no URL")
            #expect(!document.title.isEmpty)
        }
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let interactor = Interactor()
        let presenter = LegalPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear()
        presenter.onViewDisappear()

        #expect(interactor.trackedScreenEventNames == ["LegalView_Appear"])
        #expect(interactor.trackedEventNames == ["LegalView_Disappear"])
    }
}

// MARK: - Tutorials

/// The Tutorials row. Nothing in the app records tutorial progress yet, so the screen states that
/// and the presenter is tracking only.
@MainActor
struct ProfileTutorialsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, TutorialsInteractor { }

    private final class Router: TutorialsRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test Appearing And Disappearing Are Tracked")
    func testAppearingAndDisappearingAreTracked() {
        let interactor = Interactor()
        let presenter = TutorialsPresenter(interactor: interactor, router: Router())
        let delegate = TutorialsDelegate()

        presenter.onViewAppear(delegate: delegate)
        presenter.onViewDisappear(delegate: delegate)

        #expect(interactor.trackedScreenEventNames == ["TutorialsView_Appear"])
        #expect(interactor.trackedEventNames == ["TutorialsView_Disappear"])
    }
}
