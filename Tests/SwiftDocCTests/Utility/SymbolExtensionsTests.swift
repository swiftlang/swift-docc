/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC

class SymbolExtensionsTests: XCTestCase {

    func testOffsetAdjustedForInterfaceLanguage() throws {

        func lineListFrom(docs: String?) -> SymbolGraph.LineList? {
            guard let str = docs else {
                return nil
            }
            let range = SymbolGraph.LineList.SourceRange(
                start: .init(line: 1, character: 2),
                end: .init(line: 3, character: 4)
            )
            let line = SymbolGraph.LineList.Line(text: str, range: range)
            return SymbolGraph.LineList([line])
        }

        func createSymbol(interfaceLanguage: String, docs: String? = nil) -> SymbolGraph.Symbol {
            return SymbolGraph.Symbol(
                identifier: .init(precise: "abcd", interfaceLanguage: interfaceLanguage),
                names: .init(title: "abcd-in-\(interfaceLanguage)", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["abcd"],
                docComment: lineListFrom(docs: docs),
                accessLevel: .init(rawValue: "public"),
                kind: .init(parsedIdentifier: .struct, displayName: "ABCD Name"),
                mixins: [:]
            )
        }

        // Swift Symbol with no documentation
        var symbol = createSymbol(interfaceLanguage: "swift")
        var offset = symbol.offsetAdjustedForInterfaceLanguage()
        XCTAssertNil(offset)

        // Swift Symbol with documentation
        symbol = createSymbol(interfaceLanguage: "swift", docs: "Swift docs")
        offset = symbol.offsetAdjustedForInterfaceLanguage()
        var expectedRange = SymbolGraph.LineList.SourceRange(
            start: .init(line: 1, character: 2),
            end: .init(line: 3, character: 4)
        )
        XCTAssertEqual(expectedRange, offset)

        // Objective-C Symbol with no documentation
        symbol = createSymbol(interfaceLanguage: "objective-c")
        offset = symbol.offsetAdjustedForInterfaceLanguage()
        XCTAssertNil(offset)

        // Objective-C Symbol with documentation - expect the line
        // and character values to be one less than the origionals
        // from the symbol graphs.
        symbol = createSymbol(interfaceLanguage: "objective-c", docs: "ObjC docs")
        offset = symbol.offsetAdjustedForInterfaceLanguage()
        expectedRange = SymbolGraph.LineList.SourceRange(
            start: .init(line: 0, character: 1),
            end: .init(line: 2, character: 3)
        )
        XCTAssertEqual(expectedRange, offset)
    }
}
