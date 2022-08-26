/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class DisplayNameTests: XCTestCase {
    func testEmpty() throws {
        let source = "@DisplayName"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(displayName)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.HasArgument.unlabeled", problems.first?.diagnostic.identifier)
    }
    
    func testUnlabeledArgumentValue() throws {
        let source = "@DisplayName(\"Custom Symbol Name\")"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(displayName?.style, .conceptual)
    }
    
    func testConceptualStyleArgumentValue() throws {
        let source = "@DisplayName(\"Custom Symbol Name\", style: conceptual)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(displayName?.style, .conceptual)
    }
    
    func testSymbolStyleArgumentValue() throws {
        let source = "@DisplayName(\"Custom Symbol Name\", style: symbol)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(displayName?.style, .symbol)
    }
    
    func testUnknownStyleArgumentValue() throws {
        let source = "@DisplayName(\"Custom Symbol Name\", style: somethingUnknown)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.HasArgument.style.ConversionFailed", problems.first?.diagnostic.identifier)
    }
    
    func testExtraArguments() throws {
        let source = "@DisplayName(\"Custom Symbol Name\", argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName, "Even if there are warnings we can create a displayName value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", problems.first?.diagnostic.identifier)
    }
    
    func testExtraDirective() throws {
        let source = """
        @DisplayName(\"Custom Symbol Name\") {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName, "Even if there are warnings we can create a DisplayName value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(2, problems.count)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.DisplayName.NoInnerContentAllowed", problems.last?.diagnostic.identifier)
    }
    
    func testExtraContent() throws {
        let source = """
        @DisplayName(\"Custom Symbol Name\") {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let displayName = DisplayName(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(displayName, "Even if there are warnings we can create a DisplayName value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.DisplayName.NoInnerContentAllowed", problems.first?.diagnostic.identifier)
        XCTAssertNotNil(problems.first?.possibleSolutions.first)
    }
}
