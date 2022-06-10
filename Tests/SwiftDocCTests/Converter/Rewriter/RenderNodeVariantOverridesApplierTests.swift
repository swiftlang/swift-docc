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

class RenderNodeVariantOverridesApplierTests: XCTestCase {
    
    func testReplacesTopLevelValue() throws {
        try assertAppliedRenderNode(
            configureOriginalNode: { renderNode in
                renderNode.addVariantOverride(pointerComponents: ["kind"], value: RenderNode.Kind.article)
            },
            assertion: { appliedRenderNode in
                XCTAssertEqual(appliedRenderNode.kind, .article)
            }
        )
    }
    
    func testReplacesValueInDictionary() throws {
        try assertAppliedRenderNode(
            configureOriginalNode: { renderNode in
                renderNode.addVariantOverride(
                    pointerComponents: ["identifier", "interfaceLanguage"],
                    value: "new interface language"
                )
            },
            assertion: { appliedRenderNode in
                XCTAssertEqual(appliedRenderNode.identifier.sourceLanguage.name, "new interface language")
            }
        )
    }
    
    func testReplacesValueInArray() throws {
        try assertAppliedRenderNode(
            configureOriginalNode: { renderNode in
                renderNode.primaryContentSections = [
                    DeclarationsRenderSection(
                        declarations: [
                            DeclarationRenderSection(languages: nil, platforms: [], tokens: []),
                        ]
                    ),
                ]
                
                renderNode.addVariantOverride(
                    pointerComponents: ["primaryContentSections", "0"],
                    value: DeclarationsRenderSection(
                        declarations: [
                            DeclarationRenderSection(languages: nil, platforms: [], tokens: []),
                            DeclarationRenderSection(languages: nil, platforms: [], tokens: []),
                        ]
                    )
                )
            },
            assertion: { appliedRenderNode in
                XCTAssertEqual(
                    (appliedRenderNode.primaryContentSections.first as? DeclarationsRenderSection)?.declarations.count,
                    2
                )
            }
        )
    }
    
    func testReplacesMultipleValues() throws {
        try assertAppliedRenderNode(
            configureOriginalNode: { renderNode in
                renderNode.metadata.title = "Title"
                
                renderNode.addVariantOverride(
                    pointerComponents: ["identifier"],
                    value: ResolvedTopicReference(
                        bundleIdentifier: "new-bundle-identifier",
                        path: "/path",
                        fragment: nil,
                        sourceLanguage: .objectiveC
                    )
                )
                
                renderNode.addVariantOverride(pointerComponents: ["metadata", "title"], value: "New Title")
            },
            assertion: { appliedRenderNode in
                XCTAssertEqual(appliedRenderNode.identifier.sourceLanguage, .objectiveC)
                XCTAssertEqual(appliedRenderNode.metadata.title, "New Title")
            }
        )
    }
    
    func testReplacesValueAtPointerWithEscapedCharacters() throws {
        try assertAppliedRenderNode(
            configureOriginalNode: { renderNode in
                renderNode.references["doc://path/to/symbol"] = TopicRenderReference(
                    identifier: RenderReferenceIdentifier("doc://path/to/symbol"),
                    title: "Title",
                    abstract: [],
                    url: "",
                    kind: .symbol,
                    estimatedTime: nil
                )
                
                renderNode.addVariantOverride(
                    pointerComponents: ["references", "doc://path/to/symbol", "title"],
                    value: "New Title"
                )
            },
            assertion: { appliedRenderNode in
                XCTAssertEqual(
                    (appliedRenderNode.references["doc://path/to/symbol"] as? TopicRenderReference)?.title,
                    "New Title"
                )
            }
        )
    }
    
    func testRemovesVariantOverrides() throws {
        try assertAppliedRenderNode(
            configureOriginalNode: { renderNode in
                renderNode.metadata.title = "Title"
                renderNode.addVariantOverride(pointerComponents: ["metadata", "title"], value: "New Title")
            },
            assertion: { renderNode in
                XCTAssertNil(renderNode.variantOverrides)
            }
        )
    }
    
    func testThrowsErrorForInvalidObjectPointer() {
        XCTAssertThrowsError(
            try assertAppliedRenderNode(
                configureOriginalNode: { renderNode in
                    renderNode.addVariantOverride(pointerComponents: ["foo"], value: "value")
                },
                assertion: { renderNode in }
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Invalid dictionary pointer '/foo'. The component 'foo' is not valid for the object with keys \
                'hierarchy', 'identifier', 'kind', 'metadata', 'references', 'schemaVersion', 'sections', and \
                'variantOverrides'.
                """
            )
        }
    }
    
    func testThrowsErrorForInvalidArrayPointer() {
        XCTAssertThrowsError(
            try assertAppliedRenderNode(
                configureOriginalNode: { renderNode in
                    renderNode.addVariantOverride(pointerComponents: ["sections", "0"], value: "value")
                },
                assertion: { renderNode in }
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid array pointer '/sections/0'. The index '0' is not valid for array of 0 elements."
            )
        }
    }
    
    func testThrowsErrorForInvalidValuePointer() {
        XCTAssertThrowsError(
            try assertAppliedRenderNode(
                configureOriginalNode: { renderNode in
                    renderNode.addVariantOverride(pointerComponents: ["kind", "0"], value: "value")
                },
                assertion: { renderNode in }
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Invalid value pointer '/kind/0'. The component '0' is not valid for the non-traversable value \
                '"symbol"'.
                """
            )
        }
    }
    
    private func assertAppliedRenderNode(
        configureOriginalNode: ((inout RenderNode) -> ())? = nil,
        traits: [RenderNode.Variant.Trait] = [.interfaceLanguage("objc")],
        assertion: (RenderNode) throws -> ()
    ) throws {
        var renderNode = RenderNode(
            identifier: ResolvedTopicReference(
                bundleIdentifier: "bundle-identifier",
                path: "",
                fragment: nil,
                sourceLanguage: .swift
            ),
            kind: .symbol
        )
       
        configureOriginalNode?(&renderNode)
        
        let transformedData = try RenderNodeVariantOverridesApplier()
            .applyVariantOverrides(
                in: try RenderJSONEncoder.makeEncoder().encode(renderNode),
                for: traits
            )
        
        let transformedRenderNode = try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: transformedData)
        try assertion(transformedRenderNode)
    }
}

fileprivate extension RenderNode {
    mutating func addVariantOverride(
        pointerComponents: [String],
        value: Encodable,
        traits: [RenderNode.Variant.Trait] = [.interfaceLanguage("objc")],
        operation: PatchOperation = .replace
    ) {
        let variantOverrides = self.variantOverrides ?? VariantOverrides()
        
        variantOverrides.add(
            VariantOverride(
                traits: traits,
                patch: [
                    .replace(
                        pointer: JSONPointer(pathComponents: pointerComponents),
                        value: AnyCodable(value)
                    ),
                ]
            )
        )
        
        self.variantOverrides = variantOverrides
    }
}
