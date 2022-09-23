/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class AutomaticSeeAlsoTests: XCTestCase {
    
    /// Test that a symbol with no authored See Also and with no curated siblings
    /// does not have a See Also section.
    func testNoSeeAlso() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Article that curates `SideClass`
            try """
            # SideKit
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``SideClass``
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify there is no See Also
        XCTAssertEqual(renderNode.seeAlsoSections.count, 0)
    }

    /// Test that a symbol with authored See Also and with no curated siblings
    /// does include an authored See Also section
    func testAuthoredSeeAlso() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit``
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``SideClass``
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)

            /// Authored See Also
            try """
            # ``SideKit/SideClass``
            SideClass abstract.
            ## See Also
            - ``SideKit``
            """.write(to: root.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify there is an authored See Also from markdown
        XCTAssertEqual(renderNode.seeAlsoSections.count, 1)
        guard renderNode.seeAlsoSections.count == 1 else { return }
        
        XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Related Documentation")
        XCTAssertEqual(renderNode.seeAlsoSections[0].identifiers, ["doc://org.swift.docc.example/documentation/SideKit"])
        XCTAssertFalse(renderNode.seeAlsoSections[0].generated)
    }

    /// Test that a symbol with authored See Also and with curated siblings
    /// does include both in See Also with authored section first
    func testAuthoredAndAutomaticSeeAlso() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit``
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``SideClass``
            - <doc:sidearticle>
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)

            /// Authored See Also
            try """
            # ``SideKit/SideClass``
            SideClass abstract.
            ## See Also
            - ``SideKit``
            """.write(to: root.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)

            /// Article Sibling
            try """
            # Side Article
            Side Article abstract.
            """.write(to: root.appendingPathComponent("documentation/sidearticle.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify there is an authored See Also & automatically created See Also
        XCTAssertEqual(renderNode.seeAlsoSections.count, 2)
        guard renderNode.seeAlsoSections.count == 2 else { return }
        
        XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Related Documentation")
        XCTAssertEqual(renderNode.seeAlsoSections[0].identifiers, ["doc://org.swift.docc.example/documentation/SideKit"])

        XCTAssertEqual(renderNode.seeAlsoSections[1].title, "Basics")
        XCTAssertEqual(renderNode.seeAlsoSections[1].identifiers, ["doc://org.swift.docc.example/documentation/Test-Bundle/sidearticle"])
        XCTAssertEqual(renderNode.seeAlsoSections[1].generated, true)
        
        // Verify that articles get same automatic See Also sections as symbols
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/Test-Bundle/sidearticle", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Article) as! RenderNode
            
            // Verify there is an automacially created See Also
            XCTAssertEqual(renderNode.seeAlsoSections.count, 1)
            guard renderNode.seeAlsoSections.count == 1 else { return }
            
            XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Basics")
            XCTAssertEqual(renderNode.seeAlsoSections[0].identifiers, ["doc://org.swift.docc.example/documentation/SideKit/SideClass"])
            XCTAssertEqual(renderNode.seeAlsoSections[0].generated, true)
        }
    }
    
    // Duplicate of the `testAuthoredAndAutomaticSeeAlso()` test above
    // but with automatic see also creation disabled
    func testAuthoredSeeAlsoWithDisabledAutomaticSeeAlso() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit``
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``SideClass``
            - <doc:sidearticle>
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)

            /// Authored See Also
            try """
            # ``SideKit/SideClass``
            SideClass abstract.
            
            @Options {
                @AutomaticSeeAlso(disabled)
            }
            
            ## See Also
            - ``SideKit``
            """.write(to: root.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)

            /// Article Sibling
            try """
            # Side Article
            
            Side Article abstract.
            """.write(to: root.appendingPathComponent("documentation/sidearticle.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify there is an authored See Also but no automatically created See Also
        XCTAssertEqual(renderNode.seeAlsoSections.count, 1)
        guard renderNode.seeAlsoSections.count == 1 else { return }
        
        XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Related Documentation")
        XCTAssertEqual(renderNode.seeAlsoSections[0].identifiers, ["doc://org.swift.docc.example/documentation/SideKit"])

        // Verify that article without options directive still gets automatic See Also sections
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/Test-Bundle/sidearticle", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Article) as! RenderNode
            
            // Verify there is an automacially created See Also
            XCTAssertEqual(renderNode.seeAlsoSections.count, 1)
            guard renderNode.seeAlsoSections.count == 1 else { return }
            
            XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Basics")
            XCTAssertEqual(renderNode.seeAlsoSections[0].identifiers, ["doc://org.swift.docc.example/documentation/SideKit/SideClass"])
            XCTAssertEqual(renderNode.seeAlsoSections[0].generated, true)
        }
    }
    
    // Duplicate of the `testAuthoredAndAutomaticSeeAlso()` test above
    // but with automatic see also creation globally disabled
    func testAuthoredSeeAlsoWithGloballyDisabledAutomaticSeeAlso() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit``
            SideKit module root symbol
            
            @Options(scope: global) {
                @AutomaticSeeAlso(disabled)
            }
            
            ## Topics
            ### Basics
            - ``SideClass``
            - <doc:sidearticle>
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)

            /// Authored See Also
            try """
            # ``SideKit/SideClass``
            SideClass abstract.
            
            ## See Also
            - ``SideKit``
            """.write(to: root.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)

            /// Article Sibling
            try """
            # Side Article
            
            Side Article abstract.
            """.write(to: root.appendingPathComponent("documentation/sidearticle.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify there is an authored See Also but no automatically created See Also
        XCTAssertEqual(renderNode.seeAlsoSections.count, 1)
        guard renderNode.seeAlsoSections.count == 1 else { return }
        
        XCTAssertEqual(renderNode.seeAlsoSections[0].title, "Related Documentation")
        XCTAssertEqual(renderNode.seeAlsoSections[0].identifiers, ["doc://org.swift.docc.example/documentation/SideKit"])

        // Verify that article without options directive still gets automatic See Also sections
        do {
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/Test-Bundle/sidearticle", sourceLanguage: .swift))
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
            let renderNode = translator.visit(node.semantic as! Article) as! RenderNode
            
            // Verify there is an automacially created See Also
            XCTAssertTrue(renderNode.seeAlsoSections.isEmpty)
        }
    }

}
