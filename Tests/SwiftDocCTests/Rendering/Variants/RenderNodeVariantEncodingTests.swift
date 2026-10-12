/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import DocCCommon
import SwiftDocC
import Foundation

struct RenderNodeVariantEncodingTests {

    /// Verifies that a render node encodes its variant overrides both with and
    /// without a render reference cache.
    ///
    /// Depending on whether the caller passes a render reference cache, the
    /// accumulated variant overrides are encoded by one of two different
    /// pieces of code:
    ///
    ///  - Without a cache, `RenderNode.encode(to:)` encodes the overrides
    ///    together with the rest of the render node.
    ///  - With a cache, `RenderNode.encode(to:)` skips both the references and
    ///    the overrides---because the references accumulate overrides of their
    ///    own---and `TopicRenderReferenceEncoder.addRenderReferences(to:…)`
    ///    appends both to the encoded data afterwards.
    @Test func variantOverridesAreAlwaysEncoded() throws {

        // Create a vanilla render node
        var node = RenderNode(
            identifier: .init(
                bundleID: "org.swift.docc.test",
                path: "/documentation/mykit/mysymbol",
                sourceLanguage: .swift
            ),
            kind: .symbol
        )

        // Assign a default title
        node.metadata.title = "SwiftTitle"

        // Assign a title variant for Objective-C
        let trait = RenderNode.Variant.Trait.interfaceLanguage("occ")
        let variant = VariantCollection<String?>.Variant(
            traits: [trait],
            patch: [
                .replace(value: "ObjCTitle")
            ]
        )
        node.metadata.titleVariants.variants.append(variant)

        // Add a reference to the render node.
        //
        // Without any references, `RenderNode.encode(to:)` encodes the variant
        // overrides even when the caller passes a render reference cache,
        // which would hide a problem with the code that encodes the references
        // separately.
        let ref = "doc://MyKit/documentation/othersymbol"
        let topicRef = TopicRenderReference(
            identifier: RenderReferenceIdentifier(ref),
            title: "Other Symbol",
            abstract: [],
            url: "/documentation/othersymbol",
            kind: .section
        )
        node.references[ref] = topicRef

        // Test the variant overrides are present after encoding to JSON
        try expectVariantOverridesArePresent(
            in: try node.encodeToJSON(),
            "without a render reference cache"
        )

        // Repeat the test, but this time provide a render reference cache.
        // This will trigger a call to // TopicRenderReferenceEncoder.addRenderReferences
        // from RenderNode.encodeToJSON, which adds the variant overrides in a
        // different manner.
        let cache: RenderReferenceCache = .init([:])
        try expectVariantOverridesArePresent(
            in: try node.encodeToJSON(renderReferenceCache: cache),
            "with a render reference cache"
        )
    }

    /// Verifies that the given encoded render node data contains variant
    /// overrides.
    ///
    /// - Parameters:
    ///   - data: The encoded render node data to check.
    ///   - howItWasEncoded: A description of how the render node was encoded,
    ///     to tell the two checks apart when one of them fails.
    ///   - sourceLocation: The location of the call to this function, so that
    ///     a failure is reported at the call site.
    private func expectVariantOverridesArePresent(
        in data: Data,
        _ howItWasEncoded: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "The encoded render node isn't a JSON object (\(howItWasEncoded))",
            sourceLocation: sourceLocation
        )
        #expect(
            json["variantOverrides"] != nil,
            "The encoded render node is missing its variant overrides (\(howItWasEncoded))",
            sourceLocation: sourceLocation
        )
    }
}
