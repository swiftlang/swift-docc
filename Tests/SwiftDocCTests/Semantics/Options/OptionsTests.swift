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

class OptionsTests: XCTestCase {
    func testDefaultOptions() throws {
        let (problems, options) = try parseDirective(Options.self) {
            """
            @Options {
            
            }
            """
        }
        
        XCTAssertTrue(problems.isEmpty)
        let unwrappedOptions = try XCTUnwrap(options)
        
        XCTAssertNil(unwrappedOptions.automaticTitleHeadingEnabled)
        XCTAssertNil(unwrappedOptions.automaticSeeAlsoEnabled)
        XCTAssertNil(unwrappedOptions.topicsVisualStyle)
        XCTAssertEqual(unwrappedOptions.scope, .local)
    }
    
    func testOptionsParameters() throws {
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options(scope: global) {
                
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.scope, .global)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options(scope: local) {
                
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.scope, .local)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options(scope: global, random: foo) {
                
                }
                """
            }
            
            XCTAssertEqual(options?.scope, .global)
            XCTAssertEqual(
                problems,
                [
                    "1: warning – org.swift.docc.UnknownArgument",
                ]
            )
        }
    }
    
    func testAutomaticSeeAlso() throws {
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(disabled)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.automaticSeeAlsoEnabled, false)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(enabled)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.automaticSeeAlsoEnabled, true)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(foo)
                }
                """
            }
            
            
            XCTAssertNotNil(options)
            XCTAssertNil(options?.automaticSeeAlsoEnabled)
            
            XCTAssertEqual(
                problems,
                [
                    "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed",
                ]
            )
        }
    }
    
    func testTopicsVisualStyle() throws {
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(detailedGrid)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .detailedGrid)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(compactGrid)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .compactGrid)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(list)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .list)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(hidden)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .hidden)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(foo)
                }
                """
            }
            
            
            XCTAssertNotNil(options)
            XCTAssertNil(options?.topicsVisualStyle)
            
            XCTAssertEqual(
                problems,
                [
                    "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed",
                ]
            )
        }
    }
    
    func testAutomaticTitleHeading() throws {
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticTitleHeading(disabled)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.automaticTitleHeadingEnabled, false)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticTitleHeading(enabled)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            XCTAssertEqual(options?.automaticTitleHeadingEnabled, true)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticTitleHeading(foo)
                }
                """
            }
            
            
            XCTAssertNotNil(options)
            XCTAssertNil(options?.automaticTitleHeadingEnabled)
            
            XCTAssertEqual(
                problems,
                [
                    "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed",
                ]
            )
        }
    }
    
    func testMixOfOptions() throws {
        let (problems, options) = try parseDirective(Options.self) {
            """
            @Options {
                @AutomaticTitleHeading(enabled)
                @AutomaticSeeAlso(disabled)
                @TopicsVisualStyle(detailedGrid)
                @AutomaticArticleSubheading(enabled)
            }
            """
        }
        
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(options?.automaticTitleHeadingEnabled, true)
        XCTAssertEqual(options?.automaticSeeAlsoEnabled, false)
        XCTAssertEqual(options?.topicsVisualStyle, .detailedGrid)
        XCTAssertEqual(options?.automaticArticleSubheadingEnabled, true)
    }
    
    func testUnsupportedChild() throws {
        let (problems, options) = try parseDirective(Options.self) {
            """
            @Options {
                @AutomaticTitleHeading(enabled)
                @Row {
                    @Column {
                        Hi!
                    }
                }
            }
            """
        }
        
        XCTAssertEqual(options?.automaticTitleHeadingEnabled, true)
        XCTAssertEqual(
            problems,
            [
                "1: warning – org.swift.docc.Options.UnexpectedContent",
                "3: warning – org.swift.docc.HasOnlyKnownDirectives",
            ]
        )
    }
    
    func testAutomaticArticleSubheading() throws {
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertNil(unwrappedOptions.automaticArticleSubheadingEnabled)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticArticleSubheading(randomArgument)
                }
                """
            }
            
            XCTAssertEqual(problems, ["2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed"])
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertNil(unwrappedOptions.automaticArticleSubheadingEnabled)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticArticleSubheading(disabled)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertEqual(unwrappedOptions.automaticArticleSubheadingEnabled, false)
        }
        
        do {
            let (problems, options) = try parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticArticleSubheading(enabled)
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty)
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertEqual(unwrappedOptions.automaticArticleSubheadingEnabled, true)
        }
    }
}
