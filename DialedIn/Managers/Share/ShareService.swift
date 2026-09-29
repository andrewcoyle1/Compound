//
//  ShareService.swift
//  DialedIn
//

import Foundation

@MainActor
protocol ShareService: AnyObject {
    func sendShare(_ share: ShareModel) async throws
    func fetchShare(id: String) async throws -> ShareModel
    func updateShareStatus(_ status: ShareModel.Status, id: String) async throws
}

@MainActor
final class ShareManager {
    private let service: ShareService

    init(service: ShareService) {
        self.service = service
    }

    func sendShare(_ share: ShareModel) async throws {
        try await service.sendShare(share)
    }

    func fetchShare(id: String) async throws -> ShareModel {
        try await service.fetchShare(id: id)
    }

    func updateShareStatus(_ status: ShareModel.Status, id: String) async throws {
        try await service.updateShareStatus(status, id: id)
    }
}

@MainActor
final class MockShareService: ShareService {
    private(set) var shares: [ShareModel]

    init(shares: [ShareModel] = ShareModel.mocks) {
        self.shares = shares
    }

    func sendShare(_ share: ShareModel) async throws {
        shares.append(share)
    }

    func fetchShare(id: String) async throws -> ShareModel {
        guard let share = shares.first(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
        return share
    }

    func updateShareStatus(_ status: ShareModel.Status, id: String) async throws {
        guard let index = shares.firstIndex(where: { $0.id == id }) else { throw URLError(.fileDoesNotExist) }
        shares[index].status = status
    }
}
