//
//  OFFBarcodeResponse.swift
//  Compound
//
//  Created by Andrew Coyle on 12/03/2026.
//

import Foundation

struct OFFBarcodeResponse: Decodable {
    let status: Int
    let product: OFFProductDTO?
}
