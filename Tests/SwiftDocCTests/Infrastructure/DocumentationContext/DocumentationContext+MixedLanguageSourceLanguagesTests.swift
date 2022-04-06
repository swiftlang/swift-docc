/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationContext_MixedLanguageSourceLanguagesTests: XCTestCase {
    func testArticleAvailableSourceLanguagesIsSwiftInSwiftModule() throws {
        try assertArticleAvailableSourceLanguages(
            moduleAvailableLanguages: [.swift],
            expectedArticleDefaultLanguage: .swift
        )
    }
    
    func testArticleAvailableSourceLanguagesIsMixedLanguageInMixedLanguageModule() throws {
        try assertArticleAvailableSourceLanguages(
            moduleAvailableLanguages: [.swift, .objectiveC],
            expectedArticleDefaultLanguage: .swift
        )
    }
    
    func testArticleAvailableSourceLanguagesIsObjectiveCInObjectiveCModule() throws {
        try assertArticleAvailableSourceLanguages(
            moduleAvailableLanguages: [.objectiveC],
            expectedArticleDefaultLanguage: .objectiveC
        )
    }
    
    func assertArticleAvailableSourceLanguages(
        moduleAvailableLanguages: Set<SourceLanguage>,
        expectedArticleDefaultLanguage: SourceLanguage,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        precondition(
            moduleAvailableLanguages.allSatisfy { [.swift, .objectiveC].contains($0) },
            "moduleAvailableLanguages can only contain Swift and Objective-C as languages."
        )
        
        let (_, _, context) = try testBundleAndContext(copying: "MixedLanguageFramework") { url in
            try """
            # MyArticle
            
            The framework this article is documenting is available in the following languages: \
            \(moduleAvailableLanguages.map(\.name).joined(separator: ",")).
            """.write(to: url.appendingPathComponent("myarticle.md"), atomically: true, encoding: .utf8)
            
            func removeSymbolGraph(compiler: String) throws {
                try FileManager.default.removeItem(
                    at: url.appendingPathComponent("symbol-graphs").appendingPathComponent(compiler)
                )
            }
            
            if !moduleAvailableLanguages.contains(.swift) {
                try removeSymbolGraph(compiler: "swift")
            }
            
            if !moduleAvailableLanguages.contains(.objectiveC) {
                try removeSymbolGraph(compiler: "clang")
            }
        }
        
        let articleNode = try XCTUnwrap(
            context.documentationCache.first {
                $0.key.path == "/documentation/MixedLanguageFramework/myarticle"
            }?.value,
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            articleNode.availableSourceLanguages,
            moduleAvailableLanguages,
            "Expected the article's source languages to have inherited from the module's available source languages.",
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            articleNode.sourceLanguage,
            expectedArticleDefaultLanguage,
            file: file,
            line: line
        )
    }
}
