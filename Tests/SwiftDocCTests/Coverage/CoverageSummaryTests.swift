/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

// Creates a formatted string in the form of "X/Y% (X/Y)"
func ratio(_ x: Int, _ y: Int, length: Int? = nil) -> String {
    let percentage = RatioStatistic.numberFormatter.string(from: NSNumber(value: Double(x) / Double(y)))!
    let result = percentage
        .appending(" (\(x)/\(y))")
    guard let length = length else { return result }
    
    return result
        .appending(String(repeating: " ", count: length - result.count))
}

class CoverageSummaryTests: XCTestCase {
    func testEmptyTable() throws {
        let source: [CoverageDataEntry] = []

        let result = CoverageDataEntry.generateSummary(
            of: source,
            shouldGenerateBrief: true,
            shouldGenerateDetailed: false
        )
        let expected = """
                | Abstract        | Curated         | Code Listing
Types           | (0/0)           | (0/0)           | (0/0)
Members         | (0/0)           | (0/0)           | (0/0)
Globals         | (0/0)           | (0/0)           | (0/0)

"""
        XCTAssertEqual(result, expected)
    }

    func testTableWithSingleType() {
        let source: [CoverageDataEntry] = [
            CoverageDataEntry(
                title: "MyDocumentedUncuratedClass",
                usr: "doc://org.swift.docc.example/documentation/MyLibrary/MyClass",
                sourceLanguage: .swift,
                availableSourceLanguages: [.swift],
                kind: .class,
                hasAbstract: true,
                isCurated: false,
                hasCodeListing: false,
                availability: nil,
                kindSpecificData: .class(memberStats: [:])),
        ]

        let result = CoverageDataEntry.generateSummary(
            of: source,
            shouldGenerateBrief: true,
            shouldGenerateDetailed: false
        )
        let expected = """
                | Abstract        | Curated         | Code Listing
Types           | \(ratio(1, 1, length: 15)) | \(ratio(0, 1, length: 15)) | \(ratio(0, 1))
Members         | (0/0)           | (0/0)           | (0/0)
Globals         | (0/0)           | (0/0)           | (0/0)

"""
        XCTAssertEqual(result, expected)
    }

    func testTableWithOneMemberOneType() {
        let source: [CoverageDataEntry] = [
            CoverageDataEntry(
                title: "MyDocumentedUncuratedClass",
                usr: "doc://org.swift.docc.example/documentation/MyLibrary/MyClass",
                sourceLanguage: .swift,
                availableSourceLanguages: [.swift],
                kind: .class,
                hasAbstract: true,
                isCurated: false,
                hasCodeListing: true,
                availability: nil,
                kindSpecificData: .class(memberStats: [:])),
            CoverageDataEntry(
                title: "MyDocumentedUncuratedClassProperty",
                usr: "doc://org.swift.docc.example/documentation/MyLibrary/MyClass/myProperty",
                sourceLanguage: .swift,
                availableSourceLanguages: [.swift],
                kind: .instanceProperty,
                hasAbstract: false,
                isCurated: true,
                hasCodeListing: false,
                availability: nil,
                kindSpecificData: .instanceProperty),
        ]

        let result = CoverageDataEntry.generateSummary(
            of: source,
            shouldGenerateBrief: true,
            shouldGenerateDetailed: false
        )
        let expected = """
                | Abstract        | Curated         | Code Listing
Types           | \(ratio(1, 1, length: 15)) | \(ratio(0, 1, length: 15)) | \(ratio(1, 1))
Members         | \(ratio(0, 1, length: 15)) | \(ratio(1, 1, length: 15)) | \(ratio(0, 1))
Globals         | (0/0)           | (0/0)           | (0/0)

"""
        XCTAssertEqual(result, expected)
    }
}
