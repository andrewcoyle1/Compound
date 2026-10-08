//
//  MacrocyclesPresenterTests.swift
//  CompoundUnitTests
//
//  The Macrocycles list: a program imported from here opens as its macrocycle once saved.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct MacrocyclesPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MacrocyclesInteractor {
        var macrocycles: [Macrocycle] = []
        var currentMacrocycle: Macrocycle?
    }

    private final class Router: MacrocyclesRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var detailMacrocycleIds: [String?] = []
        private(set) var importDelegates: [ImportProgramDelegate] = []

        func showMacrocycleDetailView(delegate: MacrocycleDetailDelegate) {
            detailMacrocycleIds.append(delegate.macrocycle?.id)
        }

        func showImportProgramView(delegate: ImportProgramDelegate) {
            importDelegates.append(delegate)
        }
    }

    @Test("Test Import Opens The Importer And Then The Saved Macrocycle")
    func testImportOpensTheSavedMacrocycle() async {
        let interactor = Interactor()
        let router = Router()
        let presenter = MacrocyclesPresenter(interactor: interactor, router: router)
        let saved = Macrocycle(authorId: "user", name: "Imported", mesocycleIds: ["m1", "m2"], status: .notStarted)

        presenter.onImportProgramPressed()

        #expect(router.importDelegates.count == 1)
        #expect(interactor.trackedEventNames.contains("MacrocyclesView_ImportProgram_Pressed"))
        #expect(router.detailMacrocycleIds.isEmpty)

        router.importDelegates.first?.onImported?(saved)

        #expect(await TestManagers.eventually { router.detailMacrocycleIds == [saved.id] })
    }

    @Test("Test New Opens An Empty Detail")
    func testNewOpensEmptyDetail() {
        let router = Router()
        let presenter = MacrocyclesPresenter(interactor: Interactor(), router: router)

        presenter.onNewMacrocyclePressed()

        #expect(router.detailMacrocycleIds == [nil])
    }
}
