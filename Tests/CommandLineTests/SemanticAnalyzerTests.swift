/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC
@testable import CommandLine
import SwiftDocCTestUtilities

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
        func problemsConvertingTestContent(withFileExtension fileExtension: String) async throws -> (unsupportedTopLevelChildProblems: [Problem], missingTopLevelChildProblems: [Problem]) {
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
                context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.unsupportedTopLevelChild" }),
                context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.missingTopLevelChild" })
            )
        }
        
        do {
            let problems = try await problemsConvertingTestContent(withFileExtension: "md")
            
            XCTAssertEqual(problems.missingTopLevelChildProblems.count, 0)
            XCTAssertEqual(problems.unsupportedTopLevelChildProblems.count, 1)
            
            if let diagnostic = problems.unsupportedTopLevelChildProblems.first?.diagnostic {
                XCTAssertEqual(diagnostic.summary, "Found unsupported 'Article' directive in '.md' file")
                XCTAssertEqual(diagnostic.severity, .warning)
                XCTAssertEqual(diagnostic.source?.lastPathComponent, "FileWithDirective.md")
            }
        }
        
        do {
            let problems = try await problemsConvertingTestContent(withFileExtension: "tutorial")
            
            XCTAssertEqual(problems.missingTopLevelChildProblems.count, 1)
            XCTAssertEqual(problems.unsupportedTopLevelChildProblems.count, 0)
            
            if let diagnostic = problems.missingTopLevelChildProblems.first?.diagnostic {
                XCTAssertEqual(diagnostic.summary, "No valid content was found in this file")
                XCTAssertEqual(diagnostic.explanation, "A '.tutorial' file should contain a top-level directive ('Tutorials', 'Tutorial', or 'Article') and valid child content. Only '.md' files support content without a top-level directive")
                XCTAssertEqual(diagnostic.severity, .warning)
                XCTAssertEqual(diagnostic.source?.lastPathComponent, "FileWithoutDirective.tutorial")
            }
        }
    }
    
    func testDoesNotWarnOnEmptyTutorials() async throws {
        let (bundle, _) = try await loadBundle(catalog: catalogHierarchy)
        
        let document = Document(parsing: "", options: .parseBlockDirectives)
        var analyzer = SemanticAnalyzer(source: URL(string: "/empty.tutorial"), bundle: bundle)
        let semantic = analyzer.visitDocument(document)
        XCTAssertNil(semantic)
        XCTAssert(analyzer.problems.isEmpty)
    }
}
