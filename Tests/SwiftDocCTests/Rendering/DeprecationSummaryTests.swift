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

class DeprecationSummaryTests: XCTestCase {
    func testDecodeDeprecatedSymbol() throws {
        let deprecatedSymbolURL = try XCTUnwrap(Bundle.module.url(
            forResource: "deprecated-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures"))
        
        let data = try Data(contentsOf: deprecatedSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        //
        // Deprecation Details
        //
        
        XCTAssertEqual(symbol.deprecationSummary?.firstParagraph, [.text("This symbol is deprecated.")])
    }
    
    /// This test verifies that a symbol's deprecation summary comes from its sidecar doc
    /// and it's preferred over the original deprecation note in the code docs.
    func testAuthoredDeprecatedSummary() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.id.rawValue, path: "/documentation/SideKit/SideClass/init()", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode, "Could not compile the node")
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [.text("This initializer has been deprecated.")])
    }

    /// Test for a warning when symbol is not deprecated
    func testIncorrectlyAuthoredDeprecatedSummary() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], configureBundle: { url in
            // Add a sidecar file with wrong deprecated summary
            try """
            # ``SideKit/SideClass``

            @DeprecationSummary {
            This class has been deprecated.
            }

            Abstract for `SideClass`.
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        })
        
        // Verify the context contains a warning about it.
        XCTAssertNotNil(context.problems.first { problem -> Bool in
            return problem.diagnostic.identifier == "org.swift.docc.DeprecationSummaryForAvailableSymbol"
        })
        
        // Verify the deprecation is still rendered.
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.id.rawValue, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode, "Could not compile the node")
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [.text("This class has been deprecated.")])
        
        // Verify that the in-abstract directive didn't make the context overflow into the discussion
        XCTAssertEqual((node.semantic as? Symbol)?.abstract?.format().trimmingCharacters(in: .whitespacesAndNewlines), "Abstract for `SideClass`.")
    }

    /// This test verifies that a symbol's deprecation summary comes from its documentation extension file
    /// and it's preferred over the original deprecation note in the code docs.
    /// (r69719494)
    func testAuthoredDeprecatedSummaryAsSoleItemInFile() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.id.rawValue,
                path: "/documentation/CoolFramework/CoolClass",
                sourceLanguage: .swift
            )
        )

        // Compile docs and verify contents
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)

        guard let renderNode = translator.visit(symbol) as? RenderNode else {
            XCTFail("Could not compile the node")
            return
        }

        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [
            .text("Use the "),
            SwiftDocC.RenderInlineContent.reference(
                identifier: SwiftDocC.RenderReferenceIdentifier("doc://org.swift.docc.example/documentation/CoolFramework/CoolClass/coolFunc()"),
                isActive: true,
                overridingTitle: nil,
                overridingTitleInlineContent: nil
            ),
            SwiftDocC.RenderInlineContent.text(" "),
            SwiftDocC.RenderInlineContent.text("initializer instead."),
        ])
    }
    
    func testSymbolDeprecatedSummary() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.id.rawValue,
                path: "/documentation/CoolFramework/CoolClass/doUncoolThings(with:)",
                sourceLanguage: .swift
            )
        )
        
        // Compile docs and verify contents
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode, "Could not compile the node")

        // `doUncoolThings(with:)` has a blanket deprecation notice from the class, but no curated article - verify that the deprecation notice from the class still shows up on the rendered page
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [
            .text("This class is deprecated."),
        ])
    }
  
  func testDeprecationOverride() throws {
      let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
      let node = try context.entity(
          with: ResolvedTopicReference(
              bundleIdentifier: bundle.id.rawValue,
              path: "/documentation/CoolFramework/CoolClass/init()",
              sourceLanguage: .swift
          )
      )
      
      // Compile docs and verify contents
      let symbol = try XCTUnwrap(node.semantic as? Symbol)
      var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
      
      let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode, "Could not compile the node")

      // `init()` has deprecation information in both the symbol graph and the documentation extension; when there are extra headings in an extension file, we need to make sure we correctly parse out the deprecation message from the extension and display that
      XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [
        .text("Use the "),
        .reference(
            identifier: SwiftDocC.RenderReferenceIdentifier("doc://org.swift.docc.example/documentation/CoolFramework/CoolClass/init(config:cache:)"),
            isActive: true,
            overridingTitle: nil,
            overridingTitleInlineContent: nil
        ),
        .text(" initializer instead."),
    ])
  }
    
    func testDeprecationSummaryInDiscussionSection() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.id.rawValue,
                path: "/documentation/CoolFramework/CoolClass/coolFunc()",
                sourceLanguage: .swift
            )
        )
        
        // Compile docs and verify contents
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode, "Could not compile the node")

        // `coolFunc()` has deprecation information in both the symbol graph and the documentation extension; the deprecation information is part of the "Overview" section of the markup but it should still be parsed as expected.
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [
            .text("Use the "),
            .reference(
                identifier: SwiftDocC.RenderReferenceIdentifier("doc://org.swift.docc.example/documentation/CoolFramework/CoolClass/init()"),
                isActive: true,
                overridingTitle: nil,
                overridingTitleInlineContent: nil
            ),
            .text(" initializer instead."),
        ])
    }
    
    func testDeprecationSummaryWithMultiLineCommentSymbol() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.id.rawValue,
                path: "/documentation/CoolFramework/CoolClass/init(config:cache:)",
                sourceLanguage: .swift
            )
        )
        
        // Compile docs and verify contents
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode, "Could not compile the node")
        
        // `init(config:cache:)` has deprecation information in both the symbol graph and the documentation extension; the symbol graph has multiple lines of documentation comments for the function, but adding deprecation information in the documentation extension should still work.
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [
            .text("This initializer is deprecated as of version 1.0.0."),
        ])
    }
}
