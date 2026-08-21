/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import SwiftDocC

import DocCTestUtilities
import Foundation
import SymbolKit
import Testing

struct VariantOverridesEndToEndTests {
    @Test("Renders correct JSON Patches when building variant overrides for plist symbols")
    func testPlistVariantOverridesFromSymbolGraphs() async throws {
        // Test bundle with plist symbols in minor language variants
        let catalog = Folder(name: "TestBundle.docc", content: [
            JSONFile(
                name: "TestModule-swift.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "TestModule",
                    symbols: [createPlistSymbol(language: .swift, includePlistDetails: true)]
                )
            ),
            JSONFile(
                name: "TestModule-objc.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "TestModule",
                    symbols: [createPlistSymbol(language: .objectiveC, includePlistDetails: false)]
                )
            ),

            TextFile(name: "MySymbol.md", utf8Content: """
                # ``MySymbol``

                @Metadata {
                  @DocumentationExtension(mergeBehavior: override)
                }

                A property list symbol for testing.
                """)
        ])

        // Load the bundle
        let context = try await load(catalog: catalog)

        let plistReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "MySymbol" }))
        let node = try #require(context.documentationCache[plistReference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let originalRenderNode = try #require(converter.renderNode(for: node))

        // We need to round-trip the render node because the JSON patches are only created at render time
        let renderJSON = try RenderJSONEncoder.makeEncoder().encode(originalRenderNode)
        let roundTripRenderNode = try JSONDecoder().decode(RenderNode.self, from: renderJSON)
        let variantOverrides = try #require(roundTripRenderNode.variantOverrides)

        // This combination of symbols generates several variant overrides,
        // so we need to hunt for the one that updates the primaryContentSections.
        let contentSectionPatch = try #require(variantOverrides.values.compactMap({
            $0.patch.first(where: {
                $0.pointer.pathComponents.contains("primaryContentSections")
            })
        }).first)

        // Previously, the index referenced by this override was out-of-bounds of the actual
        // primaryContentSections list, which could cause the JSONPatchApplier to throw an error.
        // Make sure that we're generating a valid index for this patch.
        let sectionIndex = try #require(Int(contentSectionPatch.pointer.pathComponents.last!))
        let primaryContentSections = roundTripRenderNode.primaryContentSections
        #expect(sectionIndex < primaryContentSections.count)

        // Also make sure that the generated patch can be applied using DocC's JSON patch applier.
        // This is a more generalized version of the above assertion in case the index moves around more,
        // but the above assertions are there to ensure that the patch is being generated in the first place.
        var updatedRenderJSON = renderJSON
        for variantOverride in variantOverrides.values {
            updatedRenderJSON = try JSONPatchApplier().apply(variantOverride.patch, to: updatedRenderJSON)
        }
        // We don't need to inspect the resulting render node, so just discard it.
        let _ = try JSONDecoder().decode(RenderNode.self, from: updatedRenderJSON)
    }
}

/// Generate a SymbolKit Symbol with data based on real-world symbol graphs.
///
/// - Parameter language: Which language to associate the symbol with.
/// - Parameter includePlistDetails: Whether to include the `plistDetails` mixin. In the real-world
///   case that inspired this test, the symbol had Swift and Objective-C variants where one variant
///   included this mixin and the other did not.
func createPlistSymbol(language: SourceLanguage, includePlistDetails: Bool) -> SymbolGraph.Symbol {
    var mixins: [any Mixin] = [
        SymbolGraph.Symbol.TypeDetails([
            .init(
                fragments: [
                    .init(kind: .text, spelling: "string", preciseIdentifier: nil)
                ],
                baseType: "string"
            ),
            .init(
                fragments: [
                    .init(kind: .text, spelling: "number", preciseIdentifier: nil)
                ],
                baseType: "number"
            ),
            .init(
                fragments: [
                    .init(kind: .text, spelling: "[*]", preciseIdentifier: nil)
                ],
                arrayMode: true
            ),
            .init(
                fragments: [
                    .init(kind: .text, spelling: "dictionary", preciseIdentifier: nil)
                ],
                baseType: "dictionary"
            ),
        ])
    ]
    if includePlistDetails {
        mixins.append(
            SymbolGraph.Symbol.PlistDetails(
                rawKey: "MySymbol",
                customTitle: "My Symbol",
                baseType: "_conditional",
                arrayMode: false
            )
        )
    }
    return makeSymbol(
        id: "plist:MySymbol",
        language: language,
        kind: .dictionary,
        pathComponents: [
            "MySymbol"
        ],
        accessLevel: .public,
        otherMixins: mixins
    )
}
