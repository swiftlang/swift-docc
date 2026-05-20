/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC
@testable import DocCCommandLine
import DocCTestUtilities
import DocCCommon

class SemanticAnalyzerTests: XCTestCase {
    private let catalogHierarchy = Folder(name: "SemanticAnalyzerTests.docc", content: [
        Folder(name: "Symbols", content: []),
        Folder(name: "Resources", content: [
            TextFile(name: "Oops.md", utf8Content: """
                > Oops! This is a random markdown file with no directives or anything.

                `inlineCode`

                - A

                *******

                ```swift
                func foo() {}
                ```

                This *should not* [crash](test.html) despite not being **valid**.

                ![alt](test.png)
                """),
            TextFile(name: "MyArticle.md", utf8Content: """
                # Check out my article

                My article provides lots of detailed information.

                This is my article's overview.

                ## This is a section.

                ```swift
                func foo() {}
                ```

                ![alt](test.png)
                """),
            ]),
        InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
    ])
    
    func testDoNotCrashOnInvalidContent() async throws {
        let (bundle, context) = try await loadBundle(catalog: catalogHierarchy)
        
        XCTAssertThrowsError(try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/Oops", sourceLanguage: .swift)))
    }
    
    func testWarningsAboutDirectiveSupport() async throws {
        func diagnosticsFromConvertingTestContent(withFileExtension fileExtension: String) async throws -> (unsupportedTopLevelChildDiagnostic: [Diagnostic], missingTopLevelChildDiagnostic: [Diagnostic]) {
            let catalogHierarchy = Folder(name: "SemanticAnalyzerTests.docc", content: [
                TextFile(name: "FileWithDirective.\(fileExtension)", utf8Content: """
                @Article
                """),
                TextFile(name: "FileWithoutDirective.\(fileExtension)", utf8Content: """
                # Article title

                A paragraph of text
                """),
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ])
            let (_, context) = try await loadBundle(catalog: catalogHierarchy)
            
            return (
                context.diagnostics.filter { $0.identifier == "org.swift.docc.unsupportedTopLevelChild" },
                context.diagnostics.filter { $0.identifier == "org.swift.docc.missingTopLevelChild" }
            )
        }
        
        do {
            let diagnostics = try await diagnosticsFromConvertingTestContent(withFileExtension: "md")
            
            XCTAssertEqual(diagnostics.missingTopLevelChildDiagnostic.count, 0)
            XCTAssertEqual(diagnostics.unsupportedTopLevelChildDiagnostic.count, 1)
            
            if let diagnostic = diagnostics.unsupportedTopLevelChildDiagnostic.first {
                XCTAssertEqual(diagnostic.summary, "Found unsupported 'Article' directive in '.md' file")
                XCTAssertEqual(diagnostic.severity, .warning)
                XCTAssertEqual(diagnostic.source?.lastPathComponent, "FileWithDirective.md")
            }
        }
        
        do {
            let diagnostics = try await diagnosticsFromConvertingTestContent(withFileExtension: "tutorial")
            
            XCTAssertEqual(diagnostics.missingTopLevelChildDiagnostic.count, 1)
            XCTAssertEqual(diagnostics.unsupportedTopLevelChildDiagnostic.count, 0)
            
            if let diagnostic = diagnostics.missingTopLevelChildDiagnostic.first {
                XCTAssertEqual(diagnostic.summary, "No valid content was found in this file")
                XCTAssertEqual(diagnostic.explanation, "A '.tutorial' file should contain a top-level directive ('Tutorials', 'Tutorial', or 'Article') and valid child content. Only '.md' files support content without a top-level directive")
                XCTAssertEqual(diagnostic.severity, .warning)
                XCTAssertEqual(diagnostic.source?.lastPathComponent, "FileWithoutDirective.tutorial")
            }
        }
    }
    
    func testDoesNotWarnOnEmptyTutorials() async throws {
        let (_, context) = try await loadBundle(catalog: catalogHierarchy)
        
        let document = Document(parsing: "", options: .parseBlockDirectives)
        var analyzer = SemanticAnalyzer(source: URL(string: "/empty.tutorial"), bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        let semantic = analyzer.visitDocument(document)
        XCTAssertNil(semantic)
        XCTAssert(analyzer.diagnostics.isEmpty)
    }
}
