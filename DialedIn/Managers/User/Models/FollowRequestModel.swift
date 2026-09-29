//
//  FollowRequestModel.swift
//  DialedIn
//
//  A request to follow a private profile, stored at users/{targetId}/follow_requests/{requesterId}.
//  The target accepts or declines by writing `status`; the `onFollowRequestUpdated` Cloud Function
//  turns an accepted one into a follow, since only the server can write the requester's document.
//

import Foundation

struct FollowRequestModel: Codable, Equatable, Identifiable {

    enum Status: String, Codable {
        case pending
        case accepted
        case declined
    }

    var id: String { requesterId }

    let requesterId: String
    let requesterName: String
    let requesterImageUrl: String?
    let dateCreated: Date
    var status: Status

    enum CodingKeys: String, CodingKey {
        case requesterId = "requester_id"
        case requesterName = "requester_name"
        case requesterImageUrl = "requester_image_url"
        case dateCreated = "date_created"
        case status
    }
}
