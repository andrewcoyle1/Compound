//
//  CoachInteractor.swift
//  Compound
//

import Foundation

@MainActor
protocol CoachInteractor: GlobalInteractor {
    var isPremium: Bool { get }
    var coachHasConsented: Bool { get }
    var coachChats: [CoachChat] { get }
    var coachRemainingToday: Int? { get }
    func coachChat(id: String) -> CoachChat?
    func coachGiveConsent() async throws
    func coachWithdrawConsent() async throws
    func coachDeleteChat(id: String) async throws
    func coachSend(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error>
}

extension CoreInteractor: CoachInteractor {
    var coachHasConsented: Bool { coachManager.hasConsented }
    var coachChats: [CoachChat] { coachManager.chats }
    var coachRemainingToday: Int? { coachManager.remainingToday }

    func coachChat(id: String) -> CoachChat? {
        coachManager.chat(id: id)
    }

    func coachGiveConsent() async throws {
        try await coachManager.giveConsent()
    }

    func coachWithdrawConsent() async throws {
        try await coachManager.withdrawConsent()
    }

    func coachDeleteChat(id: String) async throws {
        try await coachManager.deleteChat(id: id)
    }

    func coachSend(message: String, chatId: String?, context: CoachContext?) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        coachManager.send(message: message, chatId: chatId, context: context)
    }
}
