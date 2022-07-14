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
        let deprecatedSymbolURL = Bundle.module.url(
            forResource: "deprecated-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/init()", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        
        guard let renderNode = translator.visit(symbol) as? RenderNode else {
            XCTFail("Could not compile the node")
            return
        }
        
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, [.text("This initializer has been deprecated.")])
    }

    /// Test for a warning when symbol is not deprecated
    func testIncorrectlyAuthoredDeprecatedSummary() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], configureBundle: { url in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        
        guard let renderNode = translator.visit(symbol) as? RenderNode else {
            XCTFail("Could not compile the node")
            return
        }
        
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
                bundleIdentifier: bundle.identifier,
                path: "/documentation/CoolFramework/CoolClass",
                sourceLanguage: .swift
            )
        )

        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: node.reference,
            source: nil
        )

        guard let renderNode = translator.visit(symbol) as? RenderNode else {
            XCTFail("Could not compile the node")
            return
        }

        let expected: [RenderInlineContent] = [
            .text("Use the "),
            SwiftDocC.RenderInlineContent.reference(
                identifier: SwiftDocC.RenderReferenceIdentifier("doc://org.swift.docc.example/documentation/CoolFramework/CoolClass/coolFunc()"),
                isActive: true,
                overridingTitle: nil,
                overridingTitleInlineContent: nil
            ),
            SwiftDocC.RenderInlineContent.text(" "),
            SwiftDocC.RenderInlineContent.text("initializer instead."),
        ]

        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, expected)
    }
    
    func testSymbolDeprecatedSummary() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/CoolFramework/CoolClass/doUncoolThings(with:)",
                sourceLanguage: .swift
            )
        )
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: node.reference,
            source: nil
        )
        
        guard let renderNode = translator.visit(symbol) as? RenderNode else {
            XCTFail("Could not compile the node")
            return
        }
        
        // `doUncoolThings(with:)` has a blanket deprecation notice from the class, but no curated article - verify that the deprecation notice from the class still shows up on the rendered page
        let expected: [RenderInlineContent] = [
            .text("This class is deprecated."),
        ]
        
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, expected)
    }
  
  func testDeprecationOverride() throws {
      let (bundle, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
      let node = try context.entity(
          with: ResolvedTopicReference(
              bundleIdentifier: bundle.identifier,
              path: "/documentation/CoolFramework/CoolClass/init()",
              sourceLanguage: .swift
          )
      )
      
      // Compile docs and verify contents
      let symbol = node.semantic as! Symbol
      var translator = RenderNodeTranslator(
          context: context,
          bundle: bundle,
          identifier: node.reference,
          source: nil
      )
      
      guard let renderNode = translator.visit(symbol) as? RenderNode else {
          XCTFail("Could not compile the node")
          return
      }
      
      // `init()` has deprecation information in both the symbol graph and the documentation extension; when there are extra headings in an extension file, we need to make sure we correctly parse out the deprecation message from the extension and display that
      let expected: [RenderInlineContent] = [
          .text("Use the "),
          .reference(
              identifier: SwiftDocC.RenderReferenceIdentifier("doc://org.swift.docc.example/documentation/CoolFramework/CoolClass/init(config:cache:)"),
              isActive: true,
              overridingTitle: nil,
              overridingTitleInlineContent: nil
          ),
          .text(" initializer instead."),
      ]
      
      XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, expected)
  }
}
