//
//  CreateProgramFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// A failure for the interactor doubles to throw, so the tests can drive the unhappy path.
private struct ProgramFlowTestError: Error { }

/// A flag a `@Sendable` completion closure can set.
///
/// Every step of this wizard copies the previous step's `onComplete` onto the delegate it builds,
/// and that closure is what returns the user to onboarding once the program is saved. Dropping it
/// cannot be seen by comparing delegates — the only way to know it survived is to call it.
private final class CompletionFlag: @unchecked Sendable {
    private(set) var fired = false

    func fire() {
        fired = true
    }
}

/// The first screen of creating a training program: an explainer with a Next button.
///
/// It holds nothing, so the only thing it can get wrong is losing the caller's completion handler
/// — the one that returns an onboarding user to where they left off once the program is saved.
@MainActor
struct ProgramFlowCreateProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, CreateProgramInteractor { }

    private final class Router: CreateProgramRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var nameDelegates: [NameProgramDelegate] = []

        func showNameProgramView(delegate: NameProgramDelegate) {
            nameDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: CreateProgramPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: CreateProgramPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test Next Opens The Naming Step")
    func testNextOpensTheNamingStep() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: CreateProgramDelegate())

        #expect(screen.router.nameDelegates.count == 1)
    }

    /// When onboarding opens this flow it passes a completion handler, and onboarding cannot
    /// resume without it. It has to be copied onto every delegate from here to the last step.
    @Test("Test The Completion Handler Reaches The Naming Step")
    func testTheCompletionHandlerReachesTheNamingStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: CreateProgramDelegate(onComplete: { flag.fire() }))
        screen.router.nameDelegates.first?.onComplete?()

        #expect(flag.fired)
    }

    /// Opened from the library rather than onboarding, there is no handler to carry, and the next
    /// step must be told that — it is what decides between resuming onboarding and just closing.
    @Test("Test No Completion Handler Is Carried When There Was None")
    func testNoCompletionHandlerIsCarriedWhenThereWasNone() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: CreateProgramDelegate())

        #expect(screen.router.nameDelegates.first?.onComplete == nil)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear()

        #expect(screen.interactor.trackedScreenEventNames == ["CreateProgramView_Appear"])
    }
}

/// Naming the program.
///
/// The name typed here is the only thing this screen produces, and it has two more screens to
/// travel through before it reaches the saved program.
@MainActor
struct ProgramFlowNameProgramPresenterTests {

    private final class Interactor: SpyGlobalInteractor, NameProgramInteractor { }

    private final class Router: NameProgramRouter {
        private(set) var iconDelegates: [ProgramIconDelegate] = []

        func showProgramIconView(delegate: ProgramIconDelegate) {
            iconDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: NameProgramPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: NameProgramPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Someone who has nothing in mind can press Next immediately, so the field starts on today's
    /// date rather than empty.
    @Test("Test The Name Starts As Todays Date")
    func testTheNameStartsAsTodaysDate() {
        let screen = makeScreen()

        #expect(screen.presenter.programName == Date.now.formattedDate)
        #expect(screen.presenter.canSave)
    }

    @Test("Test An Empty Name Cannot Be Saved")
    func testAnEmptyNameCannotBeSaved() {
        let screen = makeScreen()
        screen.presenter.programName = ""

        #expect(!screen.presenter.canSave)
    }

    /// Whitespace alone passed the old check.
    @Test("Test A Blank Name Cannot Be Saved And A Padded One Is Trimmed")
    func testABlankNameCannotBeSavedAndAPaddedOneIsTrimmed() {
        let screen = makeScreen()
        screen.presenter.programName = "  \n"
        #expect(!screen.presenter.canSave)
        screen.presenter.onNextPressed(delegate: NameProgramDelegate())
        #expect(screen.router.iconDelegates.isEmpty)

        screen.presenter.programName = "  Block "
        screen.presenter.onNextPressed(delegate: NameProgramDelegate())
        #expect(screen.router.iconDelegates.first?.name == "Block")
    }

    @Test("Test The Typed Name Reaches The Icon Step")
    func testTheTypedNameReachesTheIconStep() {
        let screen = makeScreen()
        screen.presenter.programName = "Hypertrophy Block"

        screen.presenter.onNextPressed(delegate: NameProgramDelegate())

        #expect(screen.router.iconDelegates.first?.name == "Hypertrophy Block")
    }

    @Test("Test The Completion Handler Reaches The Icon Step")
    func testTheCompletionHandlerReachesTheIconStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: NameProgramDelegate(onComplete: { flag.fire() }))
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

/// Choosing the program's colour and icon.
///
/// This is the step that mints the program's identity: its id and its author. Everything the
/// previous two screens collected has to arrive at the design screen alongside it.
@MainActor
struct ProgramFlowProgramIconPresenterTests {

    private final class Interactor: SpyGlobalInteractor, ProgramIconInteractor {
        var userId: String?

        init(userId: String? = "user-1") {
            self.userId = userId
        }
    }

    private final class Router: ProgramIconRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var designDelegates: [ProgramDesignDelegate] = []

        func showProgramDesignView(delegate: ProgramDesignDelegate) {
            designDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: ProgramIconPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(userId: String? = "user-1") -> Screen {
        let interactor = Interactor(userId: userId)
        let router = Router()
        return Screen(
            presenter: ProgramIconPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    @Test("Test A Colour And Icon Are Chosen To Begin With")
    func testAColourAndIconAreChosenToBeginWith() {
        let screen = makeScreen()

        #expect(screen.presenter.selectedColour == ProgramIconPresenter.defaultColours.first)
        #expect(screen.presenter.selectedIcon == ProgramIconPresenter.defaultIcons.first)
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

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Hypertrophy Block"))

        let delegate = screen.router.designDelegates.first
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection", "selection"])
        #expect(delegate?.name == "Hypertrophy Block")
        #expect(delegate?.colour == .green)
        #expect(delegate?.icon == "sailboat.fill")
    }

    /// The program is stamped with its author here, and the saved document is filed under that
    /// user — a program authored by the wrong person would not come back on the next sign-in.
    @Test("Test The Program Is Authored By The Signed In User")
    func testTheProgramIsAuthoredBySignedInUser() {
        let screen = makeScreen(userId: "user-7")

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.first?.authorId == "user-7")
    }

    /// Two programs created in a row must not share an id, or saving the second overwrites the
    /// first.
    @Test("Test Each Program Is Given Its Own Identifier")
    func testEachProgramIsGivenItsOwnIdentifier() {
        let screen = makeScreen()

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))
        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.count == 2)
        #expect(screen.router.designDelegates.first?.id.isEmpty == false)
        #expect(screen.router.designDelegates.first?.id != screen.router.designDelegates.last?.id)
    }

    /// Without a signed-in user there is nobody to author the program, so the step refuses to go
    /// on rather than creating one owned by nobody.
    @Test("Test A Signed Out User Cannot Reach The Design Step")
    func testASignedOutUserCannotReachTheDesignStep() {
        let screen = makeScreen(userId: nil)

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(name: "Block"))

        #expect(screen.router.designDelegates.isEmpty)
    }

    @Test("Test The Completion Handler Reaches The Design Step")
    func testTheCompletionHandlerReachesTheDesignStep() {
        let screen = makeScreen()
        let flag = CompletionFlag()

        screen.presenter.onNextPressed(delegate: ProgramIconDelegate(onComplete: { flag.fire() }, name: "Block"))
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
