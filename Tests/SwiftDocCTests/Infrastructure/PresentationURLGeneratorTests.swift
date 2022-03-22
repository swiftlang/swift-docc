/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC

class PresentationURLGeneratorTests: XCTestCase {
    func testInternalURLs() throws {
        let (catalog, context) = try testCatalogAndContext(named: "TestCatalog")
        let generator = PresentationURLGenerator(context: context, baseURL: URL(string: "https://host:1024/webPrefix")!)
        
        // Test resolved tutorial reference
        let reference = ResolvedTopicReference(catalogIdentifier: catalog.identifier, path: "/tutorials/Test-Catalog/TestTutorial", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(reference).absoluteString, "https://host:1024/webPrefix/tutorials/test-catalog/testtutorial")
        
        // Test resolved symbol reference
        let symbol = ResolvedTopicReference(catalogIdentifier: catalog.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(symbol).absoluteString, "https://host:1024/webPrefix/documentation/mykit/myclass")
        
        // Test root
        let root = ResolvedTopicReference(catalogIdentifier: catalog.identifier, path: "/", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(root).absoluteString, "https://host:1024/webPrefix/documentation")
        
        // Fragment
        let fragment = ResolvedTopicReference(catalogIdentifier: catalog.identifier, path: "/path", fragment: "test URL! FRAGMENT", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(fragment).absoluteString, "https://host:1024/webPrefix/path#test-URL!-FRAGMENT")
    }
    
    func testExternalURLs() throws {
        let catalog = DocumentationCatalog(
            info: DocumentationCatalog.Info(
                displayName: "Test",
                identifier: "com.example.test",
                version: "1.0"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: [],
            markupURLs: [],
            miscResourceURLs: []
        )
        
        let provider = PrebuiltLocalFileSystemDataProvider(catalogs: [catalog])
        
        let workspace = DocumentationWorkspace()
        try workspace.registerProvider(provider)
        
        let context = try DocumentationContext(dataProvider: workspace)
        context.externalReferenceResolvers = [
            catalog.identifier: ExternalReferenceResolverTests.TestExternalReferenceResolver(),
        ]
        let reference = ResolvedTopicReference(catalogIdentifier: "com.example.test", path: "/Test/Path", sourceLanguage: .swift)
        
        let generator = PresentationURLGenerator(context: context, baseURL: catalog.baseURL)
        
        XCTAssertEqual(generator.presentationURLForReference(reference), URL(string: "https://example.com/example/Test/Path"))
    }
    
    func testCustomExternalURLs() throws {
        /// Resolver for this test, returns fixed custom URL.
        struct TestLinkResolver: ExternalReferenceResolver {
            let customResolvedURL = URL(string: "https://resolved.com/resolved/path?query=item")!
            
            func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
                return .success(ResolvedTopicReference(catalogIdentifier: "com.example.test", path: "/path", sourceLanguage: .swift))
            }
            
            func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
                enum Error: DescribedError {
                    case empty
                    var errorDescription: String {
                        return "empty"
                    }
                }
                throw Error.empty
            }
            
            func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
                return customResolvedURL
            }
        }
        
        let catalog = DocumentationCatalog(
            info: DocumentationCatalog.Info(
                displayName: "Test",
                identifier: "com.example.test",
                version: "1.0"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: [],
            markupURLs: [],
            miscResourceURLs: []
        )
        let provider = PrebuiltLocalFileSystemDataProvider(catalogs: [catalog])
        
        let workspace = DocumentationWorkspace()
        try workspace.registerProvider(provider)
        
        let testResolver = TestLinkResolver()
        let context = try DocumentationContext(dataProvider: workspace)
        context.externalReferenceResolvers = [
            catalog.identifier: testResolver,
        ]
        
        let reference = ResolvedTopicReference(catalogIdentifier: "com.example.test", path: "/Test/Path", sourceLanguage: .swift)
        let generator = PresentationURLGenerator(context: context, baseURL: catalog.baseURL)
        
        /// Check that the presentation generator got a custom final URL from the resolver.
        XCTAssertEqual(
            generator.presentationURLForReference(reference),
            testResolver.customResolvedURL 
        )
    }
}
