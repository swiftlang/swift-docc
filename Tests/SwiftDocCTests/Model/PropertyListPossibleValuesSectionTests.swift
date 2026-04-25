/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
import Foundation
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon
import Markdown


class PropertyListPossibleValuesSectionTests: XCTestCase {
    
    func testPossibleValuesDiagnostics() async throws {
        // Check that a diagnostic is emitted when extra possible values are documented.
        var (url, _, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
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
            XCTAssertEqual(context.diagnostics.count, 1)
            let possibleValueDiagnostic = try XCTUnwrap(context.diagnostics.first(where: { $0.summary == "\'April\' is not a known possible value for \'Month\'." }))
            XCTAssertEqual(possibleValueDiagnostic.source, url.appendingPathComponent("Month.md"))
            XCTAssertEqual(possibleValueDiagnostic.range?.lowerBound.line, 9)
            XCTAssertEqual(possibleValueDiagnostic.range?.lowerBound.column, 3)
            XCTAssertEqual(possibleValueDiagnostic.range?.upperBound.line, 9)
            XCTAssertEqual(possibleValueDiagnostic.range?.upperBound.column, 18)
            XCTAssertNotNil(possibleValueDiagnostic.solutions.first(where: { $0.summary == "Remove \'April\' possible value documentation or replace it with a known value." }))
        }
        
        // Check that no diagnostics are emitted if no extra possible values are documented.
        (url, _, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
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
            XCTAssertEqual(context.diagnostics.count, 0)
        }
        
        // Check that a diagnostic is emitted with possible solutions.
        (url, _, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
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
            XCTAssertEqual(context.diagnostics.count, 1)
            let possibleValueDiagnostic = try XCTUnwrap(context.diagnostics.first(where: { $0.summary == "\'Marc\' is not a known possible value for \'Month\'." }))
            XCTAssertEqual(possibleValueDiagnostic.solutions.count, 1)
            XCTAssertNotNil(possibleValueDiagnostic.solutions.first(where: { $0.summary == "Remove \'Marc\' possible value documentation or replace it with a known value." }))
        }
    }
    
    func testAbsenceOfPossibleValues() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "DictionaryData")
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/DictionaryData/Artist", sourceLanguage: .swift))
        let converter = DocumentationNodeConverter(context: context)
        
        // Check that the `Possible Values` section is not rendered if the symbol don't define any possible value.
        XCTAssertNil(converter.convert(node).primaryContentSections.first(where: { $0.kind == .possibleValues}) as? PossibleValuesRenderSection)
    }
    
    func testUndocumentedPossibleValues() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "DictionaryData")
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        let converter = DocumentationNodeConverter(context: context)
        let possibleValuesSection = try XCTUnwrap(converter.convert(node).primaryContentSections.first(where: { $0.kind == .possibleValues}) as? PossibleValuesRenderSection)
        let possibleValues: [PossibleValuesRenderSection.NamedValue] = possibleValuesSection.values
        
        // Check that if no possible values were documented they still show under the Possible Values section.
        XCTAssertEqual(possibleValues.map { $0.name }, ["January", "February", "March"])
    }
    
    func testDocumentedPossibleValuesMatchSymbolGraphPossibleValues() async throws {
        let (_, bundle, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
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

        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        let possibleValues = try XCTUnwrap(symbol.possibleValuesSection?.possibleValues)
        
        // Check that possible value defined in the markdown but not part of the SymbolGraph is dropped.
        XCTAssertEqual(possibleValues.count, 3)
        XCTAssertEqual(possibleValues.map { $0.value }, ["January", "February", "March"])
    }
    
    func testDocumentedPossibleValues() async throws {
        let (_, bundle, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            Month object.
            
            - PossibleValue January: First
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        
        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/DictionaryData/Month", sourceLanguage: .swift))
        let symbol = node.semantic as! Symbol
        let possibleValues = try XCTUnwrap(symbol.possibleValuesSection?.possibleValues)
        
        // Check that possible value not defined in the markdown but part of the SymbolGraph are not dropped.
        XCTAssertEqual(possibleValues.map { $0.value }, ["January", "February", "March"])
        let documentedPossibleValue = try XCTUnwrap(
            possibleValues.first(where: { $0.value == "January"})
        )
        // Check that the possible value is documented with the markdown content.
        XCTAssertEqual(documentedPossibleValue.contents.count , 1)
    }
    
    func testUnresolvedLinkWarnings() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            A month is a unit of time, used with calendars, that is approximately as long as a natural orbital period of the Moon; the words month and Moon are cognates.
            
            - PossibleValues:
                - January: First
                - February: Second links to <doc:NotFoundArticle>
                - March: Third links to ``NotFoundSymbol``
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        
        let diagnostics = context.diagnosticEngine.diagnostics
        let linkResolutionDiagnostics = diagnostics.filter { $0.source?.relativePath.hasSuffix("Month.md") == true }
        XCTAssertEqual(linkResolutionDiagnostics.count, 2)
        XCTAssertEqual(linkResolutionDiagnostics.map(\.summary).sorted(), [
            "\'NotFoundArticle\' doesn\'t exist at \'/DictionaryData/Month\'",
            "\'NotFoundSymbol\' doesn\'t exist at \'/DictionaryData/Month\'",
        ])
    }
    
    func testResolvedLinks() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "DictionaryData") { url in
            try """
            #  ``Month``
            
            A month is a unit of time, used with calendars, that is approximately as long as a natural orbital period of the Moon; the words month and Moon are cognates.
            
            - PossibleValues:
                - January: First links to ``Artist``
            """.write(to: url.appendingPathComponent("Month.md"), atomically: true, encoding: .utf8)
        }
        let diagnostics = context.diagnosticEngine.diagnostics
        let linkResolutionDiagnostics = diagnostics.filter { $0.source?.relativePath.hasSuffix("Month.md") == true }
        XCTAssertEqual(linkResolutionDiagnostics.count, 0)
    }
}
