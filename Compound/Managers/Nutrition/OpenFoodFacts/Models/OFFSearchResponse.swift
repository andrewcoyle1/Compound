//
//  OFFSearchResponse.swift
//  Compound
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

struct OFFSearchResponse: Decodable {
    let products: [OFFProductDTO]?
}
