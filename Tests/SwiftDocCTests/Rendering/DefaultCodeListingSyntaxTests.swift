/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class DefaultCodeBlockSyntaxTests: XCTestCase {
    func testCodeBlockWithoutAnyLanguageOrDefault() async throws {
        let codeListing = try await makeCodeBlock(fenceLanguage: nil, infoPlistLanguage: nil)
        XCTAssertEqual(codeListing.language, nil)
    }
    
    func testExplicitFencedCodeBlockLanguage() async throws {
        let codeListing = try await makeCodeBlock(fenceLanguage: "swift", infoPlistLanguage: nil)
        XCTAssertEqual(codeListing.language, "swift")
    }

    func testDefaultCodeBlockLanguage() async throws {
        let codeListing = try await makeCodeBlock(fenceLanguage: nil, infoPlistLanguage: "swift")
        XCTAssertEqual(codeListing.language, "swift")
    }

    func testExplicitlySetLanguageOverridesDefaultLanguage() async throws {
        let codeListing = try await makeCodeBlock(fenceLanguage: "objective-c", infoPlistLanguage: "swift")
        XCTAssertEqual(codeListing.language, "objective-c", "The explicit language of the code listing should override the bundle's default language")
    }

    private struct CodeListing {
        var language: String?
        var lines: [String]
    }
    
    private func makeCodeBlock(fenceLanguage: String?, infoPlistLanguage: String?) async throws -> CodeListing {
        let catalog = Folder(name: "Something.docc", content: [
            InfoPlist(defaultCodeListingLanguage: infoPlistLanguage),
            
            TextFile(name: "Root.md", utf8Content: """
            # Root
                
            This article contains a code block
            
            ```\(fenceLanguage ?? "")
            Some code goes 
            ```
            """)
        ])
        
        let (_, context) = try await loadBundle(catalog: catalog)
        let reference = try XCTUnwrap(context.soleRootModuleReference)
        let converter = DocumentationNodeConverter(bundle: context.inputs, context: context)
        
        let renderNode = converter.convert(try context.entity(with: reference))
        let renderSection = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection)
        
        guard case .codeListing(let codeListing)? = renderSection.content.last else {
            struct Error: DescribedError {
                let errorDescription = "Didn't fide code block is known markup"
            }
            throw Error()
        }
        return CodeListing(language: codeListing.syntax, lines: codeListing.code)
    }
}
