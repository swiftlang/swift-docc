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
import DocCCommon

struct VariantOverridesEndToEndTests {
    func decodedRendedNodeHasSamePropertyListDetailsVariantsAsOriginal() async throws {
        // Test bundle with plist symbols in minor language variants
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(
                name: "TestModule-swift.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "TestModule",
                    symbols: [createPlistSymbol(language: .swift, includePlistDetails: true)]
                )
            )
            JSONFile(
                name: "TestModule-objc.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "TestModule",
                    symbols: [createPlistSymbol(language: .objectiveC, includePlistDetails: false)]
                )
            )
            
            TextFile(name: "MySymbol.md", utf8Content: """
                # ``MySymbol``
                
                @Metadata {
                  @DocumentationExtension(mergeBehavior: override)
                }
                
                A property list symbol for testing.
                """)
        }

        // Load the bundle
        let context = try await load(catalog: catalog)

        let plistReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "MySymbol" }))
        let node = try #require(context.documentationCache[plistReference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let originalRenderNode = try #require(converter.renderNode(for: node))

        // We need to round-trip the render node because the JSON patches are only created at render time
        let encoded = try RenderJSONEncoder.makeEncoder().encode(originalRenderNode)
        let roundTripRenderNode = try JSONDecoder().decode(RenderNode.self, from: encoded)
        
        #expect(originalRenderNode.primaryContentSectionsVariants == roundTripRenderNode.primaryContentSectionsVariants)
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
