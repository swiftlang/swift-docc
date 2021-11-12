/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
@testable import SymbolKit

class DiagnosticTests: XCTestCase {

    fileprivate let nonexistentDiagnostic = Diagnostic(source: nil, severity: .error, range: nil, identifier: "blah", summary: "blah")
    fileprivate let basicDiagnostic = Diagnostics.diagnostic(identifier: "org.swift.docc.testdiagnostic")!

    func testLocalizedSummary() {
        let expectedDump = "This is a test diagnostic"

        XCTAssertEqual(expectedDump, basicDiagnostic.localizedSummary)
    }

    func testLocalizedExplanation() {
        XCTAssertNil(nonexistentDiagnostic.localizedExplanation)
        guard let explanation = basicDiagnostic.localizedExplanation else {
            XCTFail("basicDiagnostic.localizedExplanation was nil.")
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
        XCTAssertEqual(expectedDescription, diagnostic.localizedDescription)
    }
    
    /// Test that the file path is printed even when range is nil, indicating a whole-file diagnostic or a diagnostic where the range is unknown.
    func testWholeFileDiagnosticDescription() {
        let path = "/tmp/foo.md"
        let diagnostic = Diagnostic(source: URL(fileURLWithPath: path), severity: .error, range: nil, identifier: "org.swift.docc.test.Diagnostic.localizedDescription", summary: "This is a test diagnostic")
        let expectedDescription = "\(path): error: This is a test diagnostic"
        XCTAssertEqual(expectedDescription, diagnostic.localizedDescription)
    }
    
    /// Test offsetting diagnostic ranges
    func testOffsetDiagnostics() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        let source = "Test a ``Reference`` in a sentence."
        let markup = Document(parsing: source, options: .parseSymbolLinks)
        
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: URL(string: "/tmp/foo.symbols.json"), rootReference: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift))
        
        // Resolve references
        _ = resolver.visitMarkup(markup)
        
        XCTAssertEqual(resolver.problems.first?.diagnostic.range, SourceLocation(line: 1, column: 8, source: nil)..<SourceLocation(line: 1, column: 21, source: nil))
        
        let offset = SymbolGraph.LineList.SourceRange(start: .init(line: 10, character: 10), end: .init(line: 10, character: 20))
        
        XCTAssertEqual((resolver.problems.first?.diagnostic)?.offsetedWithRange(offset).range, SourceLocation(line: 11, column: 18, source: nil)..<SourceLocation(line: 11, column: 31, source: nil))
    }

    func testLocalizedDescription() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"

        let error = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(error.localizedDescription, "\(expectedLocation): error: \(summary)\n\(explanation)")

        let warning = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(warning.localizedDescription, "\(expectedLocation): warning: \(summary)\n\(explanation)")

        let note = Diagnostic(source: source, severity: .information, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(note.localizedDescription, "\(expectedLocation): note: \(summary)\n\(explanation)")

        let notice = Diagnostic(source: source, severity: .hint, range: range, identifier: identifier, summary: summary, explanation: explanation)
        XCTAssertEqual(notice.localizedDescription, "\(expectedLocation): notice: \(summary)\n\(explanation)")
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
        XCTAssertEqual(diagnostic.localizedDescription, """
        \(expectedLocation): error: \(summary)
        \(explanation)
        \(expectedNoteLocation): note: The message of the note.
        """)
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

