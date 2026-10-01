//
//  String+EXT.swift
//  Compound
//
//  Created by Andrew Coyle on 25/10/2025.
//

import Foundation

extension String {
    static var random: String {
        UUID().uuidString
    }
}
