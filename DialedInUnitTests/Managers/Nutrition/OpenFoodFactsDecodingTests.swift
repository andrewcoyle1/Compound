//
//  OpenFoodFactsDecodingTests.swift
//  DialedInUnitTests
//

import Foundation
import Testing
@testable import DialedIn

/// A barcode lookup's product, decoded the way `ProductionOpenFoodFactsService` does it.
@MainActor
struct OpenFoodFactsDecodingTests {

    /// Trimmed from `api/v2/product/5010029000061.json` (Weetabix Original).
    private let weetabix = Data("""
    {"code":"5010029000061","status":1,"product":{
      "product_name":"Weetabix Original","brands":"Weetabix Limited","serving_size":"2 biscuits (37.5 g)","serving_quantity":37.5,
      "nutriments":{"energy-kcal_100g":362,"proteins_100g":12,"carbohydrates_100g":69,"fat_100g":2,"sodium_100g":0.112,
        "iron_100g":0.012,"vitamin-b1_100g":0.0012,"vitamin-pp_100g":0.014,"vitamin-d_100g":0.0000025,"energy_unit":"kJ",
        "fiber_100g":""}
    }}
    """.utf8)

    @Test("Test Micronutrients Arrive In The App's Units")
    func testMicronutrientsArriveInTheAppsUnits() throws {
        let response = try JSONDecoder().decode(OFFBarcodeResponse.self, from: weetabix)
        let food = try #require(response.product?.toFoodModel(barcode: "5010029000061"))

        #expect(food.name == "Weetabix Original")
        #expect(food.brandName == "Weetabix Limited")
        #expect(food[.calories] == 362)
        #expect(food[.protein] == 12)
        // OFF stores grams: 0.012 g of iron is 12 mg, 0.0000025 g of vitamin D is 2.5 mcg.
        #expect(abs((food[.ironMg] ?? 0) - 12) < 1e-9)
        #expect(abs((food[.sodiumMg] ?? 0) - 112) < 1e-9)
        #expect(abs((food[.thiaminMg] ?? 0) - 1.2) < 1e-9)
        #expect(abs((food[.niacinMg] ?? 0) - 14) < 1e-9)
        #expect(abs((food[.vitaminDMcg] ?? 0) - 2.5) < 1e-9)
        // A non-numeric field is skipped rather than failing the whole product.
        #expect(food[.fiber] == nil)
    }

    @Test("Test An Unknown Barcode Has No Product")
    func testAnUnknownBarcodeHasNoProduct() throws {
        let data = Data(#"{"code":"00000001","status":0,"status_verbose":"no code or invalid code"}"#.utf8)
        let response = try JSONDecoder().decode(OFFBarcodeResponse.self, from: data)
        #expect(response.status == 0)
        #expect(response.product == nil)
    }
}
