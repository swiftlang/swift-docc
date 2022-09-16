/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class DirectiveMirrorTests: XCTestCase {
    func testReflectDisplayNameDirective() {
        let reflectedDirective = DirectiveMirror(reflecting: DisplayName.self).reflectedDirective
        
        XCTAssertEqual(reflectedDirective.name, "DisplayName")
        XCTAssertFalse(reflectedDirective.allowsMarkup)
        XCTAssertEqual(reflectedDirective.arguments.count, 2)
        
        XCTAssertEqual(reflectedDirective.arguments["name"]?.unnamed, true)
        XCTAssertEqual(reflectedDirective.arguments["name"]?.required, true)
        XCTAssertEqual(reflectedDirective.arguments["name"]?.labelDisplayName, "_ name")
        XCTAssertEqual(reflectedDirective.arguments["name"]?.propertyLabel, "name")
        
        XCTAssertEqual(reflectedDirective.arguments["style"]?.unnamed, false)
        XCTAssertEqual(reflectedDirective.arguments["style"]?.required, false)
        XCTAssertEqual(reflectedDirective.arguments["style"]?.labelDisplayName, "style")
        XCTAssertEqual(reflectedDirective.arguments["style"]?.propertyLabel, "style")
        XCTAssertEqual(reflectedDirective.arguments["style"]?.allowedValues, ["conceptual", "symbol"])
    }
    
    func testReflectMetadataDirective() {
        let reflectedDirective = DirectiveMirror(reflecting: Metadata.self).reflectedDirective
        
        XCTAssertEqual(reflectedDirective.name, "Metadata")
        XCTAssertFalse(reflectedDirective.allowsMarkup)
        XCTAssert(reflectedDirective.arguments.isEmpty)
        
        XCTAssertEqual(reflectedDirective.childDirectives.count, 4)
        
        XCTAssertEqual(
            reflectedDirective.childDirectives["DocumentationExtension"]?.propertyLabel,
            "documentationOptions"
        )
        XCTAssertEqual(
            reflectedDirective.childDirectives["DocumentationExtension"]?.requirements,
            .zeroOrOne
        )
        XCTAssertEqual(
            reflectedDirective.childDirectives["DocumentationExtension"]?.storedAsArray,
            false
        )
        XCTAssertEqual(
            reflectedDirective.childDirectives["DocumentationExtension"]?.storedAsOptional,
            true
        )
        
        XCTAssertEqual(
            reflectedDirective.childDirectives["TechnologyRoot"]?.propertyLabel,
            "technologyRoot"
        )
        XCTAssertEqual(
            reflectedDirective.childDirectives["TechnologyRoot"]?.requirements,
            .zeroOrOne
        )
        XCTAssertEqual(
            reflectedDirective.childDirectives["TechnologyRoot"]?.storedAsArray,
            false
        )
        XCTAssertEqual(
            reflectedDirective.childDirectives["TechnologyRoot"]?.storedAsOptional,
            true
        )
    }
    
    func testReflectIntroDirective() {
        let reflectedDirective = DirectiveMirror(reflecting: Intro.self).reflectedDirective
        
        XCTAssertEqual(reflectedDirective.name, "Intro")
        
        XCTAssert(reflectedDirective.allowsMarkup)
        XCTAssertFalse(reflectedDirective.requiresMarkup)
        
        XCTAssertEqual(reflectedDirective.arguments.count, 1)
        XCTAssertEqual(reflectedDirective.arguments["title"]?.unnamed, false)
        XCTAssertEqual(reflectedDirective.arguments["title"]?.required, true)
        XCTAssertEqual(reflectedDirective.arguments["title"]?.labelDisplayName, "title")
        XCTAssertEqual(reflectedDirective.arguments["title"]?.propertyLabel, "title")
        XCTAssertEqual(reflectedDirective.arguments["title"]?.storedAsOptional, false)
        
        XCTAssertEqual(reflectedDirective.childDirectives.count, 2)
        XCTAssertEqual(reflectedDirective.childDirectives["Video"]?.propertyLabel, "video")
        XCTAssertEqual(reflectedDirective.childDirectives["Video"]?.storedAsOptional, true)
        XCTAssertEqual(reflectedDirective.childDirectives["Video"]?.requirements, .zeroOrOne)
        
        XCTAssertEqual(reflectedDirective.childDirectives["Image"]?.propertyLabel, "image")
        XCTAssertEqual(reflectedDirective.childDirectives["Image"]?.storedAsOptional, true)
        XCTAssertEqual(reflectedDirective.childDirectives["Image"]?.requirements, .zeroOrOne)
    }
    
    func testReflectStackDirective() {
        let reflectedDirective = DirectiveMirror(reflecting: Stack.self).reflectedDirective
        
        XCTAssertEqual(reflectedDirective.name, "Stack")
        
        XCTAssertFalse(reflectedDirective.allowsMarkup)
        XCTAssertFalse(reflectedDirective.requiresMarkup)
        
        XCTAssert(reflectedDirective.arguments.isEmpty)
        
        XCTAssertEqual(reflectedDirective.childDirectives.count, 1)
        XCTAssertEqual(reflectedDirective.childDirectives["ContentAndMedia"]?.propertyLabel, "contentAndMedia")
        XCTAssertEqual(reflectedDirective.childDirectives["ContentAndMedia"]?.storedAsOptional, false)
        XCTAssertEqual(reflectedDirective.childDirectives["ContentAndMedia"]?.requirements, .oneOrMore)
        XCTAssertEqual(reflectedDirective.childDirectives["ContentAndMedia"]?.storedAsArray, true)
    }
}

fileprivate extension RandomAccessCollection where Element == DirectiveMirror.ReflectedArgument {
    /// Look for an argument named `name` or log an XCTest failure.
    subscript<S: StringProtocol>(
        _ name: S,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> DirectiveMirror.ReflectedArgument? {
        let match = first { argument in
            if argument.name.isEmpty && argument.propertyLabel == name {
                return true
            } else if argument.name == name {
                return true
            } else {
                return false
            }
        }
        
        guard let match = match else {
            XCTFail("Expected argument named \(name.singleQuoted)", file: file, line: line)
            return nil
        }
        
        return match
    }
}

fileprivate extension RandomAccessCollection where Element == DirectiveMirror.ReflectedChildDirective {
    /// Look for an argument named `name` or log an XCTest failure.
    subscript<S: StringProtocol>(
        _ name: S,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> DirectiveMirror.ReflectedChildDirective? {
        let match = first { childDirective in
            return childDirective.name == name
        }
        
        guard let match = match else {
            XCTFail("Expected child directive named \(name.singleQuoted)", file: file, line: line)
            return nil
        }
        
        return match
    }
}
