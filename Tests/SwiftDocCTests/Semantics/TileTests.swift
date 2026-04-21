/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class TileTests: XCTestCase {
    
    func testComplex() async throws {
        let directiveNamesAndTitles = [
            (Tile.DirectiveNames.documentation, Tile.Semantics.Title.documentation),
            (Tile.DirectiveNames.sampleCode, Tile.Semantics.Title.sampleCode),
        ].map { ($0.0.rawValue, $0.1.rawValue) }

        for (directiveName, title) in directiveNamesAndTitles {
            do {
                // Empty
                let source = "@\(directiveName)"
                let document = Document(parsing: source, options: .parseBlockDirectives)
                let directive = document.child(at: 0)! as! BlockDirective
                let context = try await makeEmptyContext()
                var diagnostics = [Diagnostic]()
                let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
                XCTAssertNotNil(tile)
                XCTAssertEqual(2, diagnostics.count)
                XCTAssertEqual(diagnostics.map(\.identifier), [
                    "org.swift.docc.Resources.\(directiveName).HasContent",
                    "org.swift.docc.Resources.\(directiveName).HasLinks",
                ])
            }
            
            do {
                // Valid
                let destination = URL(string: "https://www.example.com/documentation/arkit")!
                let source = """
@\(directiveName)(destination: "\(destination)") {
   Browse and search detailed API documentation.
   - <doc://org.swift.docc/arkit/augmented_reality_with_the_back_camera>
   - <doc://org.swift.docc/arkit/augmented_reality_with_the_front_camera>
}
"""
                let document = Document(parsing: source, options: .parseBlockDirectives)
                let directive = document.child(at: 0)! as! BlockDirective
                let context = try await makeEmptyContext()
                var diagnostics = [Diagnostic]()
                let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
                XCTAssertNotNil(tile)
                XCTAssertTrue(diagnostics.isEmpty)
                tile.map { tile in
                    XCTAssertEqual(title, tile.title)
                    XCTAssertEqual(destination, tile.destination)
                }
            }
        }
    }
    
    func testGeneric() async throws {
        let directiveNamesAndTitles = [
            (Tile.DirectiveNames.downloads, Tile.Semantics.Title.downloads),
            (Tile.DirectiveNames.videos, Tile.Semantics.Title.videos),
            (Tile.DirectiveNames.forums, Tile.Semantics.Title.forums),
        ].map { ($0.0.rawValue, $0.1.rawValue) }
        
        for (directiveName, title) in directiveNamesAndTitles {
            do {
                // Empty
                let source = "@\(directiveName)"
                let document = Document(parsing: source, options: .parseBlockDirectives)
                let directive = document.child(at: 0)! as! BlockDirective
                let context = try await makeEmptyContext()
                var diagnostics = [Diagnostic]()
                let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
                XCTAssertNotNil(tile)
                XCTAssertEqual(1, diagnostics.count)
                XCTAssertEqual(diagnostics.map(\.identifier), [
                    "org.swift.docc.Resources.\(directiveName).HasContent",
                ])
            }
            
            do {
                // Valid
                let destination = URL(string: "https://www.example.com/documentation/arkit")!
                let source = """
@\(directiveName)(destination: "\(destination.absoluteString)") {
   Browse and search detailed API documentation.
   - <doc://org.swift.docc/arkit/augmented_reality_with_the_back_camera>
   - <doc://org.swift.docc/arkit/augmented_reality_with_the_front_camera>
}
"""
                let document = Document(parsing: source, options: .parseBlockDirectives)
                let directive = document.child(at: 0)! as! BlockDirective
                let context = try await makeEmptyContext()
                var diagnostics = [Diagnostic]()
                let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
                XCTAssertNotNil(tile)
                XCTAssertTrue(diagnostics.isEmpty)
                tile.map { tile in
                    XCTAssertEqual(title, tile.title)
                    XCTAssertEqual(destination, tile.destination)
                }
            }
        }
    }
    
    func testDestination() async throws {
        do {
            let destination = URL(string: "https://www.example.com/documentation/technology")!
            let source = """
    @SampleCode(destination: "\(destination.absoluteString)") {
    Browse and search detailed API documentation.
    }
    """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0)! as! BlockDirective
            let context = try await makeEmptyContext()
            var diagnostics = [Diagnostic]()
            let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            // Destination is set.
            XCTAssertEqual(destination, tile?.destination)
        }
        
        do {
            let source = """
    @SampleCode {
    Browse and search detailed API documentation.
    - <doc://org.swift.docc/arkit/augmented_reality_with_the_back_camera>
    }
    """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0)! as! BlockDirective
            let context = try await makeEmptyContext()
            var diagnostics = [Diagnostic]()
            let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            // Destination is nil.
            XCTAssertNotNil(tile)
            XCTAssertEqual(nil, tile?.destination)
        }
    }
    
    func testUnknownTile() async throws {
        let source = "@UnknownTile"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let tile = Tile(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(tile)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.Resources.UnknownTile")
        XCTAssertEqual(diagnostics.first?.severity, .warning)
    }

}
