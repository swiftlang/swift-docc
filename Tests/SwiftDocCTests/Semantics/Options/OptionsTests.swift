/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class OptionsTests: XCTestCase {
    func testDefaultOptions() async throws {
        let (diagnostics, options) = try await parseDirective(Options.self) {
            """
            @Options {
            
            }
            """
        }
        
        XCTAssertTrue(diagnostics.isEmpty)
        let unwrappedOptions = try XCTUnwrap(options)
        
        XCTAssertNil(unwrappedOptions.automaticTitleHeadingEnabled)
        XCTAssertNil(unwrappedOptions.automaticSeeAlsoEnabled)
        XCTAssertNil(unwrappedOptions.topicsVisualStyle)
        XCTAssertEqual(unwrappedOptions.scope, .local)
    }
    
    func testOptionsParameters() async throws {
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options(scope: global) {
                
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.scope, .global)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options(scope: local) {
                
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.scope, .local)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options(scope: global, random: foo) {
                
                }
                """
            }
            
            XCTAssertEqual(options?.scope, .global)
            XCTAssertEqual(diagnostics, [
                "1: warning – org.swift.docc.UnknownArgument",
            ])
        }
    }
    
    func testAutomaticSeeAlso() async throws {
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(disabled)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.automaticSeeAlsoEnabled, false)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(enabled)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.automaticSeeAlsoEnabled, true)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(foo)
                }
                """
            }
            
            
            XCTAssertNotNil(options)
            XCTAssertNil(options?.automaticSeeAlsoEnabled)
            
            XCTAssertEqual(diagnostics, [
                "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed",
            ])
        }
    }
    
    func testTopicsVisualStyle() async throws {
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(detailedGrid)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .detailedGrid)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(compactGrid)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .compactGrid)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(list)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .list)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @TopicsVisualStyle(hidden)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.topicsVisualStyle, .hidden)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticSeeAlso(foo)
                }
                """
            }
            
            
            XCTAssertNotNil(options)
            XCTAssertNil(options?.topicsVisualStyle)
            
            XCTAssertEqual(diagnostics, [
                "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed",
            ])
        }
    }
    
    func testAutomaticTitleHeading() async throws {
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticTitleHeading(disabled)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.automaticTitleHeadingEnabled, false)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticTitleHeading(enabled)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertEqual(options?.automaticTitleHeadingEnabled, true)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticTitleHeading(foo)
                }
                """
            }
            
            
            XCTAssertNotNil(options)
            XCTAssertNil(options?.automaticTitleHeadingEnabled)
            
            XCTAssertEqual(diagnostics, [
                "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed",
            ])
        }
    }
    
    func testMixOfOptions() async throws {
        let (diagnostics, options) = try await parseDirective(Options.self) {
            """
            @Options {
                @AutomaticTitleHeading(enabled)
                @AutomaticSeeAlso(disabled)
                @TopicsVisualStyle(detailedGrid)
                @AutomaticArticleSubheading(enabled)
            }
            """
        }
        
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertEqual(options?.automaticTitleHeadingEnabled, true)
        XCTAssertEqual(options?.automaticSeeAlsoEnabled, false)
        XCTAssertEqual(options?.topicsVisualStyle, .detailedGrid)
        XCTAssertEqual(options?.automaticArticleSubheadingEnabled, true)
    }
    
    func testUnsupportedChild() async throws {
        let (diagnostics, options) = try await parseDirective(Options.self) {
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
        XCTAssertEqual(diagnostics, [
            "1: warning – org.swift.docc.Options.UnexpectedContent",
            "3: warning – org.swift.docc.HasOnlyKnownDirectives",
        ])
    }
    
    func testAutomaticArticleSubheading() async throws {
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertNil(unwrappedOptions.automaticArticleSubheadingEnabled)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticArticleSubheading(randomArgument)
                }
                """
            }
            
            XCTAssertEqual(diagnostics, ["2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed"])
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertNil(unwrappedOptions.automaticArticleSubheadingEnabled)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticArticleSubheading(disabled)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertEqual(unwrappedOptions.automaticArticleSubheadingEnabled, false)
        }
        
        do {
            let (diagnostics, options) = try await parseDirective(Options.self) {
                """
                @Options {
                    @AutomaticArticleSubheading(enabled)
                }
                """
            }
            
            XCTAssertTrue(diagnostics.isEmpty)
            let unwrappedOptions = try XCTUnwrap(options)
            XCTAssertEqual(unwrappedOptions.automaticArticleSubheadingEnabled, true)
        }
    }
}
