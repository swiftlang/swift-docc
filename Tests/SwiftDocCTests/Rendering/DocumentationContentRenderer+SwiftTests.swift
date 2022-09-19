/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class DocumentationContentRenderer_SwiftTests: XCTestCase {
    
    // Tokens where the type name is incorrectly identified as "typeIdentifier"
    let typeIdentifierTokens: [DeclarationRenderSection.Token] = [
        .init(text: "class", kind: .keyword),
        .init(text: " ", kind: .text),
        .init(text: "Test", kind: .typeIdentifier),
        .init(text: " : ", kind: .text),
        .init(text: "Object", kind: .typeIdentifier),
    ]
    
    // Tokens where the type name is incorrectly identified as "typeIdentifier", which
    // are additionally prefixed by a module name
    let typeIdentifierTokensWithModule: [DeclarationRenderSection.Token] = [
        .init(text: "class", kind: .keyword),
        .init(text: " ", kind: .text),
        .init(text: "MyModule", kind: .identifier),
        .init(text: ".", kind: .text),
        .init(text: "Test", kind: .typeIdentifier),
        .init(text: " : ", kind: .text),
        .init(text: "Object", kind: .typeIdentifier),
    ]
    
    // Tokens where the type name is correctly identified as "identifier"
    let identifierTokens: [DeclarationRenderSection.Token] = [
        .init(text: "class", kind: .keyword),
        .init(text: " ", kind: .text),
        .init(text: "Test", kind: .identifier),
        .init(text: " : ", kind: .text),
        .init(text: "Object", kind: .typeIdentifier),
    ]
    
    /// Test whether we map to "identifier" if we find an unexpected "typeIdentifier" token kind
    func testNavigatorTitle() {
        do {
            // Verify that the type's own name is mapped from "typeIdentifier" to "identifier" kind
            let mapped = DocumentationContentRenderer.Swift.navigatorTitle(for: typeIdentifierTokens, symbolTitle: "Test")
            
            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text, .typeIdentifier])
            XCTAssertEqual(mapped.map { $0.text }, ["class", " ", "Test", " : ", "Object"])
        }
        
        do {
            // Verify that the type's own name is left as-is if the expect kind is vended
            let mapped = DocumentationContentRenderer.Swift.navigatorTitle(for: identifierTokens, symbolTitle: "Test")

            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text, .typeIdentifier])
            XCTAssertEqual(mapped.map { $0.text }, ["class", " ", "Test", " : ", "Object"])
        }
        
        do {
            // Verify that the type's own name is mapped from "typeIdentifier" to "identifier" kind even when prefixed with
            // a module "identifier".
            let mapped = DocumentationContentRenderer.Swift.navigatorTitle(for: typeIdentifierTokensWithModule, symbolTitle: "Test")
            
            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text, .identifier, .text, .typeIdentifier])
            XCTAssertEqual(mapped.map { $0.text }, ["class", " ", "MyModule", ".", "Test", " : ", "Object"])
        }
    }

    /// Test whether we map to "identifier" if we find an unexpected "typeIdentifier" token kind
    func testSubHeading() {
        do {
            // Verify that the type's own name is mapped from "typeIdentifier" to "identifier" kind
            let mapped = DocumentationContentRenderer.Swift.subHeading(for: typeIdentifierTokens, symbolTitle: "Test", symbolKind: "swift.class")
            
            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text, .typeIdentifier])
            XCTAssertEqual(mapped.map { $0.text }, ["class", " ", "Test", " : ", "Object"])
        }

        do {
            // Verify that the type's own name is not-mapped from "identifier" kind
            let mapped = DocumentationContentRenderer.Swift.subHeading(for: identifierTokens, symbolTitle: "Test", symbolKind: "swift.class")
            
            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text, .typeIdentifier])
            XCTAssertEqual(mapped.map { $0.text }, ["class", " ", "Test", " : ", "Object"])
        }
        
        do {
            // Verify that the type's own name is mapped from "typeIdentifier" to "identifier" kind even when prefixed with
            // a module "identifier".
            let mapped = DocumentationContentRenderer.Swift.subHeading(for: typeIdentifierTokensWithModule, symbolTitle: "Test", symbolKind: "swift.class")
            
            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text, .identifier, .text, .typeIdentifier])
            XCTAssertEqual(mapped.map { $0.text }, ["class", " ", "MyModule", ".", "Test", " : ", "Object"])
        }
    }
    
    // Tokens for an "init" symbol
    let initAsKeywordTokens: [DeclarationRenderSection.Token] = [
        .init(text: "convenience", kind: .keyword),
        .init(text: " ", kind: .text),
        .init(text: "init", kind: .keyword),
        .init(text: "()", kind: .text),
    ]
    
    // Tokens for an "init" symbol
    let initAsIdentifierTokens: [DeclarationRenderSection.Token] = [
        .init(text: "convenience", kind: .keyword),
        .init(text: " ", kind: .text),
        .init(text: "init", kind: .identifier),
        .init(text: "()", kind: .text),
    ]

    /// Test whether we map if we find the wrong "init" token kind but also we don't if it's correct.
    func testSubHeadingInit() {
        do {
            // Verify that the "init" keyword is mapped to an identifier token to enable syntax highlight
            let mapped = DocumentationContentRenderer.Swift.subHeading(for: initAsKeywordTokens, symbolTitle: "Test", symbolKind: "swift.init")

            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text])
            XCTAssertEqual(mapped.map { $0.text }, ["convenience", " ", "init", "()"])
        }

        do {
            // Verify that if the "init" has correct kind it is not mapped to another kind
            let mapped = DocumentationContentRenderer.Swift.subHeading(for: initAsIdentifierTokens, symbolTitle: "Test", symbolKind: "swift.init")

            XCTAssertEqual(mapped.map { $0.kind }, [.keyword, .text, .identifier, .text])
            XCTAssertEqual(mapped.map { $0.text }, ["convenience", " ", "init", "()"])
        }
    }
}
