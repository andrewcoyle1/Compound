//
//  AIChatModel.swift
//  Compound
//
//  Created by Andrew Coyle on 10/15/24.
//

import Foundation

struct AIChatModel: Codable {
    let role: AIChatRole
    let message: String
    
    init(role: AIChatRole, content: String) {
        self.role = role
        self.message = content
    }
    
    enum CodingKeys: String, CodingKey {
        case role
        case message
    }
    
    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "aiChat_\(CodingKeys.role.rawValue)": role,
            "aiChat_\(CodingKeys.message.rawValue)": message
        ]
        return dict.compactMapValues({ $0 })
    }
}

enum AIChatRole: String, Codable {
    case system, user, assistant, tool
}
