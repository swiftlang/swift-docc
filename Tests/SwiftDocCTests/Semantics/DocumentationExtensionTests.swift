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
import Markdown

class DocumentationExtensionTests: XCTestCase {
    func testEmpty() throws {
        let source = "@DocumentationExtension"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(options)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.HasArgument.mergeBehavior", problems.first?.diagnostic.identifier)
    }
    
    func testAppendArgumentValue() throws {
        let source = "@DocumentationExtension(mergeBehavior: append)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(options)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(options?.behavior, .append)
    }
    
    func testOverrideArgumentValue() throws {
        let source = "@DocumentationExtension(mergeBehavior: override)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(options)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(options?.behavior, .override)
    }
    
    func testUnknownArgumentValue() throws {
        let source = "@DocumentationExtension(mergeBehavior: somethingUnknown )"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(options)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.HasArgument.mergeBehavior.ConversionFailed", problems.first?.diagnostic.identifier)
    }
    
    func testExtraArguments() throws {
        let source = "@DocumentationExtension(mergeBehavior: append, argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(options, "Even if there are warnings we can create a options value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", problems.first?.diagnostic.identifier)
    }
    
    func testExtraDirective() throws {
        let source = """
        @DocumentationExtension(mergeBehavior: override) {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(options, "Even if there are warnings we can create a DocumentationExtension value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(2, problems.count)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.DocumentationExtension.NoInnerContentAllowed", problems.last?.diagnostic.identifier)
    }
    
    func testExtraContent() throws {
        let source = """
        @DocumentationExtension(mergeBehavior: override) {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(options, "Even if there are warnings we can create a DocumentationExtension value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.DocumentationExtension.NoInnerContentAllowed", problems.first?.diagnostic.identifier)
    }
    
    func testIncorrectArgumentLabel() throws {
        let source = """
        @DocumentationExtension(merge: override)
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let options = DocumentationExtension(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(options)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(2, problems.count)
        
        let expectedIds = [
            "org.swift.docc.UnknownArgument",
            "org.swift.docc.HasArgument.mergeBehavior",
        ]
        
        let problemIds = problems.map(\.diagnostic.identifier)
        
        for id in expectedIds {
            XCTAssertTrue(problemIds.contains(id))
        }
    }
}
