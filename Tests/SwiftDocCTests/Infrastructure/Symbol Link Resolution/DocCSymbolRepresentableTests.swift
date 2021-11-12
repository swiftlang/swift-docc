/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC

class DocCSymbolRepresentableTests: XCTestCase {
    func testDisambiguatedByType() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.property
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.method",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.enum.case",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName",
            ],
            symbolTitle: "secondTestMemberName",
            expectedNumberOfAmbiguousSymbols: 2
        )
    }
    
    func testOverloadedByCaseInsensitivity() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/ThirdTestMemberName-5vyx9
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/ThirdTestMemberName",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/ThirdTestMemberName-swift.enum.case",
            ],
            symbolTitle: "thirdtestmembername",
            expectedNumberOfAmbiguousSymbols: 4
        )
    }
    
    func testOverloadedParentAndMember() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember-swift.type.property
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember-swift.enum.case",
            ],
            symbolTitle: "fifthTestMember",
            expectedNumberOfAmbiguousSymbols: 2
        )
    }
    
    func testProtocolMemberWithUSRHash() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-961zx
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthtestmembername(test:)-961zx",
            ],
            symbolTitle: "fourthTestMemberName(test:)",
            expectedNumberOfAmbiguousSymbols: 4
        )
    }
    
    func testFunctionWithKindIdentifierAndUSRHash() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method-14g8s
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14g8s",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)",
            ],
            symbolTitle: "firstTestMemberName(_:)",
            expectedNumberOfAmbiguousSymbols: 6
        )
    }
    
    func testSymbolWithNoDisambiguation() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/firstMember
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/firstMember-961zx",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/firstMember-swift.property",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/firstMember-swift.property-961zx",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/firstmember",
            ],
            symbolTitle: "firstMember",
            expectedNumberOfAmbiguousSymbols: 1
        )
    }
    
    func testAmbigousProtocolMember() throws {
        try performOverloadSymbolDisambiguationTest(
            correctLink: """
            doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/firstMember
            """,
            incorrectLinks: [
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/firstMember-961zx",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/firstMember-swift.property",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/firstMember-swift.property-961zx",
                "doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/firstmember",
            ],
            symbolTitle: "firstMember",
            expectedNumberOfAmbiguousSymbols: 1
        )
    }
    
    func performOverloadSymbolDisambiguationTest(
        correctLink: String,
        incorrectLinks: [String],
        symbolTitle: String,
        expectedNumberOfAmbiguousSymbols: Int
    ) throws {
        // Build a bundle with an unusual number of overloaded symbols
        let (url, _, context) = try testBundleAndContext(
            copying: "OverloadedSymbols",
            excludingPaths: [],
            codeListings: [:]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        
        // Collect the overloaded symbols nodes from the built bundle
        let ambiguousSymbols = context.symbolIndex.values.compactMap(\.symbol).filter {
            $0.names.title.lowercased() == symbolTitle.lowercased()
        }
        XCTAssertEqual(ambiguousSymbols.count, expectedNumberOfAmbiguousSymbols)
        
        // Find the documentation node based on what we expect the correct link to be
        let correctDocumentionNodeToSelect = try XCTUnwrap(
            context.symbolIndex.values.first {
                $0.reference.absoluteString == correctLink
            }
        )
        let correctSymbolToSelect = try XCTUnwrap(
            correctDocumentionNodeToSelect.symbol
        )
        
        // First confirm the first link does resolve as expected
        do {
            // Build an absolute symbol link
            let absoluteSymbolLinkLastPathComponent = try XCTUnwrap(
                AbsoluteSymbolLink(string: correctLink)?.basePathComponents.last
            )
            
            // Pass it all of the ambiguous symbols to disambiguate between
            let selectedSymbols = absoluteSymbolLinkLastPathComponent.disambiguateBetweenOverloadedSymbols(
                ambiguousSymbols
            )
            
            // Assert that it selects a single symbol
            XCTAssertEqual(selectedSymbols.count, 1)
            
            // Assert that the correct symbol is selected
            let selectedSymbol = try XCTUnwrap(selectedSymbols.first)
            XCTAssertEqual(correctSymbolToSelect, selectedSymbol)
        }
        
        // Now we'll try a couple of inprecise links and verify they don't resolve
        try incorrectLinks.forEach { incorrectLink in
            let absoluteSymbolLinkLastPathComponent = try XCTUnwrap(
                AbsoluteSymbolLink(string: incorrectLink)?.basePathComponents.last
            )
            
            // Pass it all of the ambiguous symbols to disambiguate between
            let selectedSymbols = absoluteSymbolLinkLastPathComponent.disambiguateBetweenOverloadedSymbols(
                ambiguousSymbols
            )
            
            // We expect it to return an empty array since the given
            // absolute symbol link isn't correct
            XCTAssertTrue(selectedSymbols.isEmpty)
        }
    }
    
    func testLinkComponentInitialization() throws {
        let (url, _, context) = try testBundleAndContext(
            copying: "OverloadedSymbols",
            excludingPaths: [],
            codeListings: [:]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        
        var count = 0
        try context.symbolIndex.values.forEach { documentationNode in
            guard let symbolLink = AbsoluteSymbolLink(string: documentationNode.reference.absoluteString) else {
                return
            }
            
            // The `asLinkComponent` property of DocCSymbolRepresentable doesn't have the context
            // to know what type disambiguation information it should use, so it always includes
            // all the available disambiguation information. Because of this,
            // we want to restrict to symbols that require both.
            guard case .kindAndPreciseIdentifier = symbolLink.basePathComponents.last?.disambiguationSuffix else {
                return
            }
            
            // Create a link component from the symbol information
            let linkComponent = try XCTUnwrap(
                documentationNode.symbol?.asLinkComponent
            )
            
            // Confirm that link component we created is the same on the compiler
            // created in a full documentation build.
            XCTAssertEqual(
                linkComponent.asLinkComponentString,
                documentationNode.reference.lastPathComponent
            )
            
            count += 1
        }
        
        // We expect this bundle to contain 5 symbols that need both type and usr
        // disambiguation.
        XCTAssertEqual(count, 5)
    }
}
