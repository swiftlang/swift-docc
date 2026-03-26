/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
@testable import SymbolKit
import DocCTestUtilities

class DiagnosticTests: XCTestCase {

    fileprivate let nonexistentDiagnostic = Diagnostic(source: nil, severity: .error, range: nil, identifier: "blah", summary: "blah")
    fileprivate let basicDiagnostic = Diagnostics.diagnostic(identifier: "org.swift.docc.testdiagnostic")!

    func testLocalizedSummary() {
        let expectedDump = "This is a test diagnostic"

        XCTAssertEqual(expectedDump, basicDiagnostic.summary)
    }

    func testLocalizedExplanation() {
        XCTAssertNil(nonexistentDiagnostic.explanation)
        guard let explanation = basicDiagnostic.explanation else {
            XCTFail("basicDiagnostic.explanation was nil.")
            return
        }
        let expectedDump = """
            This is the test diagnostic's abstract.

            Further discussion would go here:
            - don't
            - use
            - jargon
            - or
            - be
            - opaque!

            ## Example

            ```swift
            func foo() {}
            ```

            ## Solution

            You should do *this* and **that**.

            ## Solution Example

            ```swift
            func bar() {}
            ```
            """
        XCTAssertEqual(expectedDump, explanation)
    }
    
    func testFilenameAndPosition() {
        let path = "/tmp/foo.md"
        let range = SourceLocation(line: 1, column: 1, source: URL(fileURLWithPath: path))..<SourceLocation(line: 2, column: 2, source: URL(fileURLWithPath: path))
        let diagnostic = Diagnostic(source: URL(fileURLWithPath: path), severity: .error, range: range, identifier: "org.swift.docc.test.Diagnostic.localizedDescription", summary: "This is a test diagnostic")
        let expectedDescription = "\(path):1:1: error: This is a test diagnostic"
        XCTAssertEqual(expectedDescription, DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: .formatConsoleOutputForTools))
    }
    
    /// Test that the file path is printed even when range is nil, indicating a whole-file diagnostic or a diagnostic where the range is unknown.
    func testWholeFileDiagnosticDescription() {
        let path = "/tmp/foo.md"
        let diagnostic = Diagnostic(source: URL(fileURLWithPath: path), severity: .error, range: nil, identifier: "org.swift.docc.test.Diagnostic.localizedDescription", summary: "This is a test diagnostic")
        let expectedDescription = "\(path): error: This is a test diagnostic"
        XCTAssertEqual(expectedDescription, DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: .formatConsoleOutputForTools))
    }
    
    /// Test offsetting diagnostic ranges
    func testOffsetDiagnostics() async throws {
        let (_, context) = try await loadBundle(catalog: Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModuleName.symbols.json", content: makeSymbolGraph(moduleName: "SomeModuleName"))
        ]))

        let content = "Test a ``Reference`` in a sentence."
        let markup = Document(parsing: content, source: URL(string: "/tmp/foo.symbols.json"), options: .parseSymbolLinks)
        
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        var resolver = ReferenceResolver(context: context, rootReference: moduleReference)
        
        // Resolve references
        _ = resolver.visitMarkup(markup)
        
        XCTAssertEqual(resolver.problems.first?.diagnostic.range, SourceLocation(line: 1, column: 10, source: nil)..<SourceLocation(line: 1, column: 19, source: nil))
        let offset = SymbolGraph.LineList.SourceRange(start: .init(line: 10, character: 10), end: .init(line: 10, character: 20))
        
        var problem = try XCTUnwrap(resolver.problems.first)
        problem.offsetWithRange(offset)
        
        XCTAssertEqual(problem.diagnostic.range, SourceLocation(line: 11, column: 20, source: nil)..<SourceLocation(line: 11, column: 29, source: nil))
    }

    func testFormattedDescription() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"

        let error = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: error, options: .formatConsoleOutputForTools), "\(expectedLocation): error: \(summary)\n\(explanation)")

        let warning = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: warning, options: .formatConsoleOutputForTools), "\(expectedLocation): warning: \(summary)\n\(explanation)")

        let note = Diagnostic(source: source, severity: .information, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: note, options: .formatConsoleOutputForTools), "\(expectedLocation): note: \(summary)\n\(explanation)")
    }

    func testLocalizedDescriptionWithNote() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"

        let noteSource = URL(string: "/a/file/path.md")!
        let noteRange = SourceLocation(line: 1, column: 1, source: source)..<SourceLocation(line: 9, column: 7, source: noteSource)
        let note = DiagnosticNote(
            source: noteSource,
            range: noteRange,
            message: "The message of the note."
        )
        let expectedNoteLocation = "/a/file/path.md:1:1"

        let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation, notes: [note])
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: .formatConsoleOutputForTools), """
        \(expectedLocation): error: \(summary)
        \(explanation)
        \(expectedNoteLocation): note: The message of the note.
        """)
    }

    func createTestSymbol(commentText: String) -> SymbolGraph.Symbol {
         let emptyRange = SymbolGraph.LineList.SourceRange(
             start: .init(line: 0, character: 0),
             end: .init(line: 0, character: 0)
         )
        let docCommentLines = commentText.components(separatedBy: .newlines).map { SymbolGraph.LineList.Line(text: $0, range: emptyRange) }
        return SymbolGraph.Symbol(
            identifier: .init(precise: "s:5MyKit0A5ClassC10myFunctionyyF", interfaceLanguage: "occ"),
            names: .init(title: "", navigator: nil, subHeading: nil, prose: nil),
            pathComponents: ["path", "to", "my file.h"],
            docComment: SymbolGraph.LineList(docCommentLines),
            accessLevel: .init(rawValue: "public"),
            kind: .init(parsedIdentifier: .func, displayName: "myFunction"),
            mixins: [:]
        )
    }

    func testDoxygenDiagnostic() throws {
        let commentText = """
          Brief description of this method
          @param something Description of this parameter
          @returns Description of return value
          """
        let symbol = createTestSymbol(commentText: commentText)
        let engine = DiagnosticEngine()

        let _ = DocumentationNode.contentFrom(documentedSymbol: symbol, documentationExtension: nil, engine: engine)
        XCTAssertEqual(engine.problems.count, 0)

        // testing scenario with known directive
        let commentWithKnownDirective = """
          Brief description of this method
          
          @TitleHeading("Fancy Type of Article")
          @returns Description of return value
          """
        let symbolWithKnownDirective = createTestSymbol(commentText: commentWithKnownDirective)
        let engine1 = DiagnosticEngine()

        let _ = DocumentationNode.contentFrom(documentedSymbol: symbolWithKnownDirective, documentationExtension: nil, engine: engine1)
        
        // count should be 1 for the known directive '@TitleHeading'
        // TODO: Consider adding a diagnostic for Doxygen tags (rdar://92184094)
        XCTAssertEqual(engine1.problems.count, 1)
        XCTAssertEqual(engine1.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnsupportedDocCommentDirective"])
    }
}

fileprivate let diagnostics: [String: Diagnostic] = [
    "org.swift.docc.testdiagnostic": Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.testdiagnostic", summary: "This is a test diagnostic", explanation: """
    This is the test diagnostic's abstract.
    
    Further discussion would go here:
    - don't
    - use
    - jargon
    - or
    - be
    - opaque!
    
    ## Example
    
    ```swift
    func foo() {}
    ```
    
    ## Solution
    
    You should do *this* and **that**.
    
    ## Solution Example
    
    ```swift
    func bar() {}
    ```
    """),
]

enum Diagnostics {
    static func diagnostic(identifier: String) -> Diagnostic? {
        return diagnostics[identifier]
    }
}

