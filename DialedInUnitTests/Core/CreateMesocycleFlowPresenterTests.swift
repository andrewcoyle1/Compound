//
//  CreateMesocycleFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// A failure for the interactor doubles to throw, so the tests can drive the unhappy path.
private struct MesocycleFlowTestError: Error { }

/// A flag a `@Sendable` completion closure can set.
///
/// Every step of this wizard copies the previous step's `onComplete` onto the delegate it builds,
/// and that closure is what returns the user to onboarding once the mesocycle is saved. Dropping it
/// cannot be seen by comparing delegates — the only way to know it survived is to call it.
private final class CompletionFlag: @unchecked Sendable {
    private(set) var fired = false

    func fire() {
        fired = true
    }
}

/// The first screen of creating a training mesocycle: an explainer with a Next button.
///
/// It holds nothing, so the only thing it can get wrong is losing the caller's completion handler
/// — the one that returns an onboarding user to where they left off once the mesocycle is saved.
@MainActor
struct CreateMesocycleFlowTests {

    private final class Interactor: SpyGlobalInteractor, CreateMesocycleInteractor { }

    private final class Router: CreateMesocycleRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var nameDelegates: [NameMesocycleDelegate] = []

        func showNameMesocycleView(delegate: NameMesocycleDelegate) {
            nameDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: CreateMesocyclePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: CreateMesocyclePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test Next Opens The Naming Step")
    func testNextOpensTheNamingStep() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: CreateMesocycleDelegate())

        #expect(screen.router.nameDelegates.count == 1)
    }

    /// When onboarding opens this flow it passes a completion handler, and onboarding cannot
    /// resume without it. It has to be copied onto every delegate from here to the last step.
    @Test("Test The Completion Handler Reaches The Naming Step")
    func testTheCompletionHandlerReachesTheNamingStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: CreateMesocycleDelegate(onComplete: { flag.fire() }))
        screen.router.nameDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    /// Opened from the library rather than onboarding, there is no handler to carry, and the next
    /// step must be told that — it is what decides between resuming onboarding and just closing.
    @Test("Test No Completion Handler Is Carried When There Was None")
    func testNoCompletionHandlerIsCarriedWhenThereWasNone() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: CreateMesocycleDelegate())

        #expect(screen.router.nameDelegates.first?.onComplete == nil)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["CreateProgramView_Appear"])
    }
}

/// Naming the mesocycle.
///
/// The name typed here is the only thing this screen produces, and it has two more screens to
/// travel through before it reaches the saved mesocycle.
@MainActor
struct MesocycleFlowNameMesocyclePresenterTests {

    private final class Interactor: SpyGlobalInteractor, NameMesocycleInteractor { }

    private final class Router: NameMesocycleRouter {
        private(set) var iconDelegates: [MesocycleIconDelegate] = []

        func showMesocycleIconView(delegate: MesocycleIconDelegate) {
            iconDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: NameMesocyclePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: NameMesocyclePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Someone who has nothing in mind can press Next immediately, so the field starts on today's
    /// date rather than empty.
    @Test("Test The Name Starts As Todays Date")
    func testTheNameStartsAsTodaysDate() {
        let screen = makeScreen()

        #expect(screen.presenter.mesocycleName == Date.now.formattedDate)
        #expect(screen.presenter.canSave)
    }

    @Test("Test An Empty Name Cannot Be Saved")
    func testAnEmptyNameCannotBeSaved() {
        let screen = makeScreen()
        screen.presenter.mesocycleName = ""

        #expect(!screen.presenter.canSave)
    }

    /// Whitespace alone passed the old check.
    @Test("Test A Blank Name Cannot Be Saved And A Padded One Is Trimmed")
    func testABlankNameCannotBeSavedAndAPaddedOneIsTrimmed() {
        let screen = makeScreen()
        screen.presenter.mesocycleName = "  \n"
        #expect(!screen.presenter.canSave)
        screen.presenter.onNextPressed(delegate: NameMesocycleDelegate())
        #expect(screen.router.iconDelegates.isEmpty)

        screen.presenter.mesocycleName = "  Block "
        screen.presenter.onNextPressed(delegate: NameMesocycleDelegate())
        #expect(screen.router.iconDelegates.first?.name == "Block")
    }

    @Test("Test The Typed Name Reaches The Icon Step")
    func testTheTypedNameReachesTheIconStep() {
        let screen = makeScreen()
        screen.presenter.mesocycleName = "Hypertrophy Block"

        screen.presenter.onNextPressed(delegate: NameMesocycleDelegate())

        #expect(screen.router.iconDelegates.first?.name == "Hypertrophy Block")
    }

    @Test("Test The Completion Handler Reaches The Icon Step")
    func testTheCompletionHandlerReachesTheIconStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: NameMesocycleDelegate(onComplete: { flag.fire() }))
        screen.router.iconDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["NameProgramView_Appear"])
    }
}

/// Choosing the mesocycle's colour and icon.
///
/// This is the step that mints the mesocycle's identity: its id and its author. Everything the
/// previous two screens collected has to arrive at the design screen alongside it.
@MainActor
struct MesocycleFlowMesocycleIconPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MesocycleIconInteractor {
        var userId: String?

        init(userId: String? = "user-1") {
            self.userId = userId
        }
    }

    private final class Router: MesocycleIconRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var designDelegates: [MesocycleDesignDelegate] = []

        func showMesocycleDesignView(delegate: MesocycleDesignDelegate) {
            designDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: MesocycleIconPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(userId: String? = "user-1") -> Screen {
        let interactor = Interactor(userId: userId)
        let router = Router()
        return Screen(
            presenter: MesocycleIconPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test A Colour And Icon Are Chosen To Begin With")
    func testAColourAndIconAreChosenToBeginWith() {
        let screen = makeScreen()

        #expect(screen.presenter.selectedColour == MesocycleIconPresenter.defaultColours.first)
        #expect(screen.presenter.selectedIcon == MesocycleIconPresenter.defaultIcons.first)
    }

    @Test("Test Pressing A Colour Selects It")
    func testPressingAColourSelectsIt() {
        let screen = makeScreen()

        screen.presenter.onColourPressed(colour: .green)

        #expect(screen.presenter.selectedColour == .green)
    }

    @Test("Test Pressing An Icon Selects It")
    func testPressingAnIconSelectsIt() {
        let screen = makeScreen()

        screen.presenter.onIconPressed(icon: "sailboat.fill")

        #expect(screen.presenter.selectedIcon == "sailboat.fill")
    }

    /// The name came from two screens back and is never shown here, which is exactly what makes it
    /// easy to drop when this step builds the design screen's delegate by hand.
    @Test("Test The Name Colour And Icon Reach The Design Step")
    func testTheNameColourAndIconReachTheDesignStep() {
        let screen = makeScreen()
        screen.presenter.onColourPressed(colour: .green)
        screen.presenter.onIconPressed(icon: "sailboat.fill")

        screen.presenter.onNextPressed(delegate: MesocycleIconDelegate(name: "Hypertrophy Block"))

        let delegate = screen.router.designDelegates.first
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
        #expect(delegate?.name == "Hypertrophy Block")
        #expect(delegate?.colour == .green)
        #expect(delegate?.icon == "sailboat.fill")
    }

    /// The mesocycle is stamped with its author here, and the saved document is filed under that
    /// user — a mesocycle authored by the wrong person would not come back on the next sign-in.
    @Test("Test The Program Is Authored By The Signed In User")
    func testTheMesocycleIsAuthoredBySignedInUser() {
        let screen = makeScreen(userId: "user-7")

        screen.presenter.onNextPressed(delegate: MesocycleIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.first?.authorId == "user-7")
    }

    /// Two mesocycles created in a row must not share an id, or saving the second overwrites the
    /// first.
    @Test("Test Each Program Is Given Its Own Identifier")
    func testEachMesocycleIsGivenItsOwnIdentifier() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: MesocycleIconDelegate(name: "Block"))
        screen.presenter.onNextPressed(delegate: MesocycleIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.count == 2)
        #expect(screen.router.designDelegates.first?.id.isEmpty == false)
        #expect(screen.router.designDelegates.first?.id != screen.router.designDelegates.last?.id)
    }

    /// Without a signed-in user there is nobody to author the mesocycle, so the step refuses to go
    /// on rather than creating one owned by nobody.
    @Test("Test A Signed Out User Cannot Reach The Design Step")
    func testASignedOutUserCannotReachTheDesignStep() {
        let screen = makeScreen(userId: nil)

        screen.presenter.onNextPressed(delegate: MesocycleIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.isEmpty)
    }

    @Test("Test The Completion Handler Reaches The Design Step")
    func testTheCompletionHandlerReachesTheDesignStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: MesocycleIconDelegate(onComplete: { flag.fire() }, name: "Block"))
        screen.router.designDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["ProgramIconView_Appear"])
    }
}
