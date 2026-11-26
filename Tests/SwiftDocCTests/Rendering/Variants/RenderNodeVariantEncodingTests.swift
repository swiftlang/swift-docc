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

    @Test func variantOverridesAreEncodedAlongsideReferences() throws {
        var node = RenderNode(
            identifier: .init(bundleID: "org.swift.docc.test", path: "/documentation/mykit/mysymbol", sourceLanguage: .swift),
            kind: .symbol
        )
        node.metadata.title = "SwiftTitle"
        node.metadata.titleVariants.variants.append(
            .init(traits: [.interfaceLanguage("occ")], patch: [.replace(value: "ObjCTitle")])
        )
        
        // Without references, `RenderNode.encode(to:)` encodes the variant overrides itself.
        // With references, it leaves that to `TopicRenderReferenceEncoder.addRenderReferences`,
        // which is the code this test is about.
        node.references["doc://MyKit/documentation/othersymbol"] = TopicRenderReference(
            identifier: .init("doc://MyKit/documentation/othersymbol"),
            title: "Other Symbol",
            abstract: [],
            url: "/documentation/othersymbol",
            kind: .section
        )

        let data = try node.encodeToJSON(renderReferenceCache: .init([:]))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["variantOverrides"] != nil)
    }
}
