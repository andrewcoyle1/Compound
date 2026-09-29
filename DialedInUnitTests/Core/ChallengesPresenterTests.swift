//
//  ChallengesPresenterTests.swift
//  DialedInUnitTests
//

import Testing
import SwiftUI
@testable import DialedIn

/// Circle challenges: the create screen's validation, the standings order and the progress ring,
/// on the detail screen and on the Dashboard card.
private struct CreatedChallenge {
    let title: String
    let target: Int
    let days: Int
    let members: [String]
}

@MainActor
struct ChallengesPresenterTests {

    // MARK: Doubles

    private final class CreateInteractor: SpyGlobalInteractor, CreateChallengeInteractor {
        var currentUser: UserModel? = UserModel(userId: "me", submittedFirstName: "Me", blockedUserIds: ["blocked"])
        var followingUsers: [UserModel] = [
            UserModel(userId: "mutual", submittedFirstName: "Mutual", followingIds: ["me"]),
            UserModel(userId: "oneway", submittedFirstName: "One Way", followingIds: []),
            UserModel(userId: "blocked", submittedFirstName: "Blocked", followingIds: ["me"])
        ]
        var error: Error?
        private(set) var created: [CreatedChallenge] = []

        func createChallenge(title: String, targetSessions: Int, durationDays: Int, memberIds: [String]) async throws -> ChallengeModel {
            if let error { throw error }
            created.append(CreatedChallenge(title: title, target: targetSessions, days: durationDays, members: memberIds))
            return ChallengeModel(ownerId: "me", title: title, targetSessions: targetSessions, startsAt: .now, endsAt: .now, memberIds: memberIds)
        }
    }

    private final class CreateRouter: CreateChallengeRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var alertTitles: [String] = []
        func showDevSettingsView() { }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private final class DetailInteractor: SpyGlobalInteractor, ChallengeDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "me", submittedFirstName: "Me")
        var followingUsers: [UserModel] = [
            UserModel(userId: "amy", submittedFirstName: "Amy"),
            UserModel(userId: "zed", submittedFirstName: "Zed")
        ]
        var challenges: [ChallengeModel] = []
        var progress: [String: Int] = [:]
        var fetchable: [UserModel] = [UserModel(userId: "stranger", submittedFirstName: "Stranger")]
        private(set) var left: [String] = []

        func challengeProgress(challengeId: String) -> [String: Int] { progress }
        func refreshChallengeProgress(challengeId: String) async throws { }
        func getUser(userId: String) async throws -> UserModel {
            guard let user = fetchable.first(where: { $0.userId == userId }) else { throw URLError(.fileDoesNotExist) }
            return user
        }
        func leaveChallenge(id: String) async throws { left.append(id) }
    }

    private final class DetailRouter: ChallengeDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []
        func showDevSettingsView() { }
        func showSocialProfileView(delegate: SocialProfileDelegate) { shown.append("profile:\(delegate.user.userId)") }
        func showAlert(title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) { alertTitles.append(title) }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private func challenge(target: Int = 4, members: [String] = ["me", "amy", "zed", "stranger"]) -> ChallengeModel {
        ChallengeModel(
            id: "c1",
            ownerId: "me",
            title: "Grind",
            targetSessions: target,
            startsAt: Date().addingTimeInterval(-86_400),
            endsAt: Date().addingTimeInterval(86_400 * 5),
            memberIds: members
        )
    }

    // MARK: Create

    @Test("Test Create Offers Only Unblocked Mutuals")
    func testCreateOffersOnlyUnblockedMutuals() {
        let presenter = CreateChallengePresenter(interactor: CreateInteractor(), router: CreateRouter())
        #expect(presenter.candidates.map(\.userId) == ["mutual"])
    }

    @Test("Test Create Needs A Name And At Least One Member")
    func testCreateNeedsANameAndAtLeastOneMember() {
        let presenter = CreateChallengePresenter(interactor: CreateInteractor(), router: CreateRouter())
        #expect(!presenter.canCreate)
        #expect(presenter.validationMessage == "Give the challenge a name.")

        presenter.title = "   "
        #expect(presenter.validationMessage == "Give the challenge a name.")

        presenter.title = "October"
        #expect(presenter.validationMessage == "Invite at least one person.")

        presenter.onCandidatePressed(presenter.candidates[0])
        #expect(presenter.validationMessage == nil)
        #expect(presenter.canCreate)

        presenter.onCandidatePressed(presenter.candidates[0])
        #expect(!presenter.canCreate, "tapping again deselects")
    }

    @Test("Test Create Rejects A Long Name, An Out Of Range Target And An Unoffered Duration")
    func testCreateRejectsOutOfRangeValues() {
        let presenter = CreateChallengePresenter(interactor: CreateInteractor(), router: CreateRouter())
        presenter.onCandidatePressed(presenter.candidates[0])

        presenter.title = String(repeating: "a", count: ChallengeModel.titleMaxLength + 1)
        #expect(presenter.validationMessage?.hasPrefix("Keep the name under") == true)

        presenter.title = "Fine"
        presenter.targetSessions = 0
        #expect(presenter.validationMessage?.hasPrefix("Pick a target") == true)

        presenter.targetSessions = 10
        presenter.durationDays = 9
        #expect(presenter.validationMessage == "Pick a duration.")

        presenter.durationDays = 30
        #expect(presenter.canCreate)
    }

    @Test("Test Create Sends The Trimmed Title And Selected Members")
    func testCreateSendsTheTrimmedTitleAndSelectedMembers() async {
        let interactor = CreateInteractor()
        let presenter = CreateChallengePresenter(interactor: interactor, router: CreateRouter())
        presenter.title = "  October Grind "
        presenter.targetSessions = 12
        presenter.durationDays = 30
        presenter.onCandidatePressed(presenter.candidates[0])

        presenter.onCreatePressed()
        await TestManagers.eventually { !interactor.created.isEmpty }

        #expect(interactor.created.count == 1)
        #expect(interactor.created.first?.title == "October Grind")
        #expect(interactor.created.first?.target == 12)
        #expect(interactor.created.first?.days == 30)
        #expect(interactor.created.first?.members == ["mutual"])
        #expect(interactor.trackedEventNames.contains("CreateChallengeView_Create_Success"))
    }

    @Test("Test A Failed Create Alerts And Allows A Retry")
    func testAFailedCreateAlertsAndAllowsARetry() async {
        let interactor = CreateInteractor()
        interactor.error = URLError(.notConnectedToInternet)
        let router = CreateRouter()
        let presenter = CreateChallengePresenter(interactor: interactor, router: router)
        presenter.title = "October"
        presenter.onCandidatePressed(presenter.candidates[0])

        presenter.onCreatePressed()
        await TestManagers.eventually { !router.alertTitles.isEmpty }

        #expect(router.alertTitles == ["Unable to create challenge"])
        #expect(presenter.canCreate)
        #expect(interactor.trackedEventNames.contains("CreateChallengeView_Create_Fail"))
    }

    // MARK: Standings

    @Test("Test Standings Rank By Sessions Then Name, With Absent Members At Zero")
    func testStandingsOrder() async {
        let interactor = DetailInteractor()
        interactor.progress = ["zed": 3, "amy": 3, "me": 5]
        let presenter = ChallengeDetailPresenter(
            interactor: interactor,
            router: DetailRouter(),
            delegate: ChallengeDetailDelegate(challenge: challenge())
        )
        await presenter.loadStandings()

        #expect(presenter.standings.map(\.userId) == ["me", "amy", "zed", "stranger"])
        #expect(presenter.standings.map(\.sessions) == [5, 3, 3, 0])
        #expect(presenter.standings.map(\.isComplete) == [true, false, false, false])
        #expect(presenter.standings.last?.name == "Stranger", "a member the reader does not follow is fetched")
    }

    @Test("Test A Member Who Cannot Be Fetched Still Ranks, As Member")
    func testUnfetchableMemberStillRanks() async {
        let interactor = DetailInteractor()
        interactor.fetchable = []
        let presenter = ChallengeDetailPresenter(
            interactor: interactor,
            router: DetailRouter(),
            delegate: ChallengeDetailDelegate(challenge: challenge())
        )
        await presenter.loadStandings()

        #expect(presenter.standings.count == 4)
        #expect(presenter.standings.first { $0.userId == "stranger" }?.name == "Member")
    }

    @Test("Test Tapping A Known Member Opens Their Profile")
    func testTappingAMemberOpensTheirProfile() {
        let router = DetailRouter()
        let presenter = ChallengeDetailPresenter(
            interactor: DetailInteractor(),
            router: router,
            delegate: ChallengeDetailDelegate(challenge: challenge())
        )
        let amy = presenter.standings.first { $0.userId == "amy" }
        if let amy { presenter.onMemberPressed(amy) }
        #expect(router.shown == ["profile:amy"])
    }

    @Test("Test Leaving Confirms First")
    func testLeavingConfirmsFirst() async {
        let interactor = DetailInteractor()
        let router = DetailRouter()
        let presenter = ChallengeDetailPresenter(
            interactor: interactor,
            router: router,
            delegate: ChallengeDetailDelegate(challenge: challenge())
        )
        presenter.onLeavePressed()
        #expect(router.alertTitles == ["Leave Grind?"])
        #expect(interactor.left.isEmpty)

        presenter.leave()
        await TestManagers.eventually { !interactor.left.isEmpty }
        #expect(interactor.left == ["c1"])
    }

    // MARK: Progress ring

    @Test("Test The Ring Fills In Proportion And Stops At Full")
    func testRingProgress() {
        #expect(ChallengeStandings.ringProgress(sessions: 0, target: 4) == 0)
        #expect(ChallengeStandings.ringProgress(sessions: 1, target: 4) == 0.25)
        #expect(ChallengeStandings.ringProgress(sessions: 4, target: 4) == 1)
        #expect(ChallengeStandings.ringProgress(sessions: 9, target: 4) == 1)
        #expect(ChallengeStandings.ringProgress(sessions: 3, target: 0) == 0)
    }

    @Test("Test The Detail Ring Shows The Readers Own Sessions")
    func testDetailRingShowsTheReadersSessions() {
        let interactor = DetailInteractor()
        interactor.progress = ["me": 2, "amy": 4]
        let presenter = ChallengeDetailPresenter(
            interactor: interactor,
            router: DetailRouter(),
            delegate: ChallengeDetailDelegate(challenge: challenge(target: 8))
        )
        #expect(presenter.mySessions == 2)
        #expect(presenter.myRingProgress == 0.25)
    }

    @Test("Test Days Left Counts Today And Reads Ended Afterwards")
    func testDaysLeft() {
        let now = Date()
        var model = challenge()
        #expect(model.daysLeft(from: now) >= 5)
        model = ChallengeModel(ownerId: "me", title: "Old", targetSessions: 1, startsAt: now.addingTimeInterval(-864_000), endsAt: now.addingTimeInterval(-1), memberIds: ["me"])
        #expect(model.daysLeft(from: now) == 0)
        #expect(!model.isActive(at: now))
    }

    // MARK: Dashboard card

    @Test("Test The Dashboard Card Shows My Sessions And The Top Three")
    func testDashboardCard() async {
        let interactor = DashboardFeedPresenterTests.Interactor()
        interactor.followingUsers = [DashboardFixture.user("amy"), DashboardFixture.user("zed")]
        let running = challenge()
        let ended = ChallengeModel(
            id: "old", ownerId: "me", title: "Old", targetSessions: 1,
            startsAt: Date().addingTimeInterval(-864_000), endsAt: Date().addingTimeInterval(-1), memberIds: ["me"]
        )
        interactor.challenges = [running, ended]
        interactor.challengeProgressById = ["c1": ["amy": 4, "me": 2, "zed": 3, "stranger": 1]]
        let router = DashboardFeedPresenterTests.Router()
        let presenter = DashboardPresenter(interactor: interactor, router: router)

        #expect(presenter.challengeCards.map(\.id) == ["c1"], "ended challenges drop off the Dashboard")
        let card = presenter.challengeCards.first
        #expect(card?.mySessions == 2)
        #expect(card?.topThree.map(\.userId) == ["amy", "zed", "me"])
        #expect(presenter.showsChallengesSection)

        if let card { presenter.onChallengePressed(card) }
        presenter.onCreateChallengePressed()
        #expect(router.shown == ["challenge:c1", "createChallenge"])

        await presenter.loadChallenges()
        #expect(interactor.challengeRefreshCount == 1)
    }

    @Test("Test The Section Hides With No Circle And No Challenges")
    func testSectionHidesWhenEmpty() {
        let presenter = DashboardPresenter(interactor: DashboardFeedPresenterTests.Interactor(), router: DashboardFeedPresenterTests.Router())
        #expect(!presenter.showsChallengesSection)
    }
}
