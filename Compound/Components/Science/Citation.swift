//
//  Citation.swift
//  Compound
//
//  A published source behind one of the app's calculations. The catalogue is `Citations.swift`;
//  `MethodInfo` groups citations with the plain-language account of a calculation, and
//  `MethodInfoButton` shows it beside the number it explains.
//

import Foundation

struct Citation: Identifiable, Hashable, Sendable {
    /// The R-number in reports/Defensible fitness app algorithms.md.
    let reportNumber: Int
    /// Authors (year). Title. Journal volume(issue):pages. Not localized.
    let reference: String
    /// Without the https://doi.org/ prefix.
    let doi: String?
    /// For guidelines, books and pages without a DOI.
    let url: String?
    /// False for practitioner books, preprints and web pages, which the sheet labels as such.
    let isPeerReviewed: Bool

    var id: Int { reportNumber }

    init(reportNumber: Int, reference: String, doi: String? = nil, url: String? = nil, isPeerReviewed: Bool = true) {
        self.reportNumber = reportNumber
        self.reference = reference
        self.doi = doi
        self.url = url
        self.isPeerReviewed = isPeerReviewed
    }

    /// Where tapping the citation goes: the DOI resolver, else the stable URL.
    var link: URL? {
        if let doi { return URL(string: "https://doi.org/\(doi)") }
        return url.flatMap(URL.init(string:))
    }

    /// The link as the sheet prints it under the reference.
    var linkText: String? {
        if let doi { return "doi:\(doi)" }
        return url
    }
}
