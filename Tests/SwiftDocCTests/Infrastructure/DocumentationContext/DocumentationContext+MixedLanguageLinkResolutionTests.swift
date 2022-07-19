/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationContext_MixedLanguageLinkResolutionTests: XCTestCase {
    
    func testResolvingLinksWhenSymbolHasSameNameInBothLanguages() throws {
         let (_, _, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkComplexLinks") { url in
             let swiftSymbolGraph = url.appendingPathComponent("symbol-graph/swift/ObjCLinks.symbols.json")
             try String(contentsOf: swiftSymbolGraph)
                 .replacingOccurrences(of: "FooSwift", with: "FooObjC")
                 .write(to: swiftSymbolGraph, atomically: true, encoding: .utf8)
         }
        
        func assertCanResolveSymbolLinks(
            symbolPaths: String...,
            parentPath: String,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            for symbolPath in symbolPaths {
                let resolutionResult = context.resolve(
                    .unresolved(UnresolvedTopicReference(topicURL: ValidatedURL(symbolPath: symbolPath))),
                    in: ResolvedTopicReference(
                        bundleIdentifier: "org.swift.MixedLanguageFramework",
                        path: "/documentation/MixedLanguageFramework/\(parentPath)",
                        sourceLanguage: .swift
                    ),
                    fromSymbolLink: true
                )
                
                switch resolutionResult {
                case .success:
                    continue
                case .failure(_, let errorMessage):
                    XCTFail(
                        """
                        Link resolution for '\(symbolPath)' in parent '\(parentPath)' unexpectedly failed: \
                        \(errorMessage)
                        """,
                        file: file,
                        line: line
                    )
                }
            }
        }
        
        // See MixedLanguageFrameworkComplexLinks.docc/OriginalSource.h for the class in which this test resolves links.
        
        assertCanResolveSymbolLinks(
            symbolPaths: "first(_:one:)", "first:one:", "second:two:", "second(_:two:)",
            parentPath: "FooObjC"
        )
        
        assertCanResolveSymbolLinks(
            symbolPaths: "FooObjC", "second:two:", "second(_:two:)",
            parentPath: "FooObjC/first(_:one:)"
        )
        
        assertCanResolveSymbolLinks(
            symbolPaths: "FooObjC", "first:one:", "first(_:one:)",
            parentPath: "FooObjC/second(_:two:)"
        )
    }
}
