/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class CoverageDetailedOutputTests: XCTestCase {
    func testEmptyTable() throws {
        let source: [CoverageDataEntry] = []

        let result = CoverageDataEntry.generateSummary(
            of: source,
            shouldGenerateBrief: true,
            shouldGenerateDetailed: true
        )
        let expected = """
                | Abstract        | Curated         | Code Listing
Types           | (0/0)           | (0/0)           | (0/0)
Members         | (0/0)           | (0/0)           | (0/0)
Globals         | (0/0)           | (0/0)           | (0/0)


Symbol Name                      Kind                             Abstract?      Curated?       Code Listing?     Parameters     Language          USR
--No Symbols to display--

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
            shouldGenerateDetailed: true
        )
        let expected = """
                | Abstract        | Curated         | Code Listing
Types           | \(ratio(1, 1, length: 15)) | \(ratio(0, 1, length: 15)) | \(ratio(0, 1))
Members         | (0/0)           | (0/0)           | (0/0)
Globals         | (0/0)           | (0/0)           | (0/0)


Symbol Name                      Kind                             Abstract?      Curated?       Code Listing?     Parameters     Language          USR
MyDocumentedUncuratedClass     | Class                          | true         | false        | false           | -            | Swift           | doc://org.swift.docc.example/documentation/MyLibrary/MyClass

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
            shouldGenerateBrief: false,
            shouldGenerateDetailed: true
        )
        let expected = """
Symbol Name                      Kind                             Abstract?      Curated?       Code Listing?     Parameters     Language          USR
MyDocumentedUncuratedClass     | Class                          | true         | false        | true            | -            | Swift           | doc://org.swift.docc.example/documentation/MyLibrary/MyClass
MyDocumentedUncuratedClassProp | Instance Property              | false        | true         | false           | -            | Swift           | doc://org.swift.docc.example/documentation/MyLibrary/MyClass/myProperty

"""
        XCTAssertEqual(result, expected)
    }
}
