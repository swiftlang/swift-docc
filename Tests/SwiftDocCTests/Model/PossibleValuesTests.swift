/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
import Foundation
@testable import SwiftDocC
import SwiftDocCTestUtilities


class PossibleValuesTests: XCTestCase {
    
    func testPossibleValuesDiagnostics() throws {
        // Check that a problem is emitted when extra possible values are documented.
        var (url, _, context) = try testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValues:
              - January: First
              - February: Second
              - March: Third
              - April: Fourth
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        do {
            XCTAssertEqual(context.problems.count, 1)
            let possibleValueProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Possible value April not found in the possible values defined for this symbol.\nKnown Values:\n\n- February\n- January\n- March\n" }))
            XCTAssertEqual(possibleValueProblem.diagnostic.source, url.appendingPathComponent("Month.md"))
            XCTAssertEqual(possibleValueProblem.diagnostic.range?.lowerBound.line, 9)
            XCTAssertEqual(possibleValueProblem.diagnostic.range?.lowerBound.column, 3)
            XCTAssertEqual(possibleValueProblem.diagnostic.range?.upperBound.line, 9)
            XCTAssertEqual(possibleValueProblem.diagnostic.range?.upperBound.column, 18)
        }
        
        // Check that no problems are emitted if no extra possible values are documented.
        (url, _, context) = try testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValues:
              - January: First
              - February: Second
              - March: Third
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        do {
            XCTAssertEqual(context.problems.count, 0)
        }
        
        // Check that a problem is emitted with possible solutions.
        (url, _, context) = try testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValues:
              - January: First
              - February: Second
              - Marc: Third
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        do {
            XCTAssertEqual(context.problems.count, 1)
            XCTAssertEqual(context.problems.count, 1)
            let possibleValueProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.summary == "Possible value Marc not found in the possible values defined for this symbol.\nKnown Values:\n\n- February\n- January\n- March\n" }))
            XCTAssertEqual(possibleValueProblem.possibleSolutions.count, 1)
            XCTAssertNotNil(possibleValueProblem.possibleSolutions.first(where: { $0.summary == "Replace \'Marc\' with \'March\'" }))
        }
    }
    
    
    func testDocumentedPossibleValuesMatchSymbolGraphPossibleValues() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValues:
              - January: First
              - February: Second
              - March: Third
              - April: Fourth
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }

        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        let possibleValues = try XCTUnwrap(symbol.possibleValuesSectionVariants.firstValue?.possibleValues)
        
        // Check that possible value defined in the markdown but not part of the SymbolGraph is dropped.
        XCTAssertEqual(possibleValues.count, 3)
        XCTAssertEqual(possibleValues.map { $0.value }, ["January", "February", "March"])
    }
    
    func testDocumentedPossibleValues() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValue January: First
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        let possibleValues = try XCTUnwrap(symbol.possibleValuesSectionVariants.firstValue?.possibleValues)
        
        // Check that possible value not defined in the markdown but part of the SymbolGraph are not dropped.
        XCTAssertEqual(possibleValues.map { $0.value }, ["January", "February", "March"])
        let documentedPossibleValue = try XCTUnwrap(
            possibleValues.first(where: { $0.value == "January"})
        )
        // Check that the possible value is documented with the markdown content.
        XCTAssertEqual(documentedPossibleValue.contents.count , 1)
    }
    
    func testPossibleValuesInAttributesSection() throws {
        var (_, bundle, context) = try testBundleAndContext(copying: "DictionaryData")
        var node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        var converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let attributes = try XCTUnwrap(try converter.convert(node).primaryContentSections.first(where: { $0.kind == .attributes}) as? AttributesRenderSection)
        var allowedValues: [String] {
            switch attributes.attributes?.first {
            case .allowedValues(let allowedValues): return allowedValues
            default: return []
            }
        }
        
        // Check that if no possible values were documented they still show under the Attributes section.
        XCTAssertEqual(allowedValues, ["January", "February", "March"])
        
        var symbol = node.semantic as! Symbol
        
        // Check that if no possible values were documented there's no 'Possible Values' render section.
        XCTAssertNil(symbol.possibleValuesSectionVariants.firstValue?.possibleValues)
 
        (_, bundle, context) = try testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValue January: First
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        // Check that if a possible value was documented the list of possible values is not displayed under the 'Attributes' render section.
        XCTAssertNil(try converter.convert(node).primaryContentSections.first(where: { $0.kind == .attributes}))
    }
}
