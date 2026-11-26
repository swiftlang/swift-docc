/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import DocCCommon
@testable import SwiftDocC
import Foundation

struct RenderNodeVariantDecodingTests {

    // MARK: Primary content sections

    /// A patch that inserts a section in the middle of the list shifts the position of the sections after it,
    /// so the next patch refers to the position of the content section _after_ the insertion.
    @Test func decodesPrimaryContentSectionsWithInsertedSection() throws {
        let node = makeNode(primaryContentSections: [
            declarations("SwiftDeclaration", language: "swift"),
            discussion("Swift discussion"),
        ])
        let data = try encode(node, patches: [
            .replace(pointer: pointer("primaryContentSections", "0"), encodableValue: declarations("ObjCDeclaration", language: "occ")),
            .add(pointer: pointer("primaryContentSections", "1"), encodableValue: parameters()),
            .replace(pointer: pointer("primaryContentSections", "2"), encodableValue: discussion("ObjC discussion")),
        ])

        expectPrimaryContentSections(
            in: data,
            swift: ["declarations: SwiftDeclaration", "content: Swift discussion"],
            occ: ["declarations: ObjCDeclaration", "parameters", "content: ObjC discussion"]
        )
    }

    @Test func decodesPrimaryContentSectionsWithAppendedSection() throws {
        let node = makeNode(primaryContentSections: [
            declarations("SwiftDeclaration", language: "swift"),
            discussion("Swift discussion"),
        ])
        let data = try encode(node, patches: [
            .replace(pointer: pointer("primaryContentSections", "0"), encodableValue: declarations("ObjCDeclaration", language: "occ")),
            .replace(pointer: pointer("primaryContentSections", "1"), encodableValue: discussion("ObjC discussion")),
            .add(pointer: pointer("primaryContentSections", "2"), encodableValue: parameters()),
        ])

        expectPrimaryContentSections(
            in: data,
            swift: ["declarations: SwiftDeclaration", "content: Swift discussion"],
            occ: ["declarations: ObjCDeclaration", "content: ObjC discussion", "parameters"]
        )
    }

    @Test func decodesReplacingPrimaryContentSectionsWithMoreSections() throws {
        let node = makeNode(primaryContentSections: [
            declarations("SwiftDeclaration", language: "swift"),
        ])
        let data = try encode(node, patches: [
            .replace(pointer: pointer("primaryContentSections"), encodableValue: [
                CodableContentSection(declarations("ObjCDeclaration", language: "occ")),
                CodableContentSection(parameters()),
                CodableContentSection(discussion("ObjC discussion")),
            ]),
        ])

        expectPrimaryContentSections(
            in: data,
            swift: ["declarations: SwiftDeclaration"],
            occ: ["declarations: ObjCDeclaration", "parameters", "content: ObjC discussion"]
        )
    }

    @Test func decodesReplacingPrimaryContentSectionsWithFewerSections() throws {
        let node = makeNode(primaryContentSections: [
            declarations("SwiftDeclaration", language: "swift"),
            parameters(),
            discussion("Swift discussion"),
        ])
        let data = try encode(node, patches: [
            .replace(pointer: pointer("primaryContentSections"), encodableValue: [
                CodableContentSection(declarations("ObjCDeclaration", language: "occ")),
            ]),
        ])

        expectPrimaryContentSections(
            in: data,
            swift: ["declarations: SwiftDeclaration", "parameters", "content: Swift discussion"],
            occ: ["declarations: ObjCDeclaration"]
        )
    }

    @Test func decodesReplacingPrimaryContentSectionsWithNull() throws {
        let node = makeNode(primaryContentSections: [
            declarations("SwiftDeclaration", language: "swift"),
            discussion("Swift discussion"),
        ])
        // An optional `.none` encodes as JSON `null` (a bare `nil` can't be an `any Encodable`):
        // { "op": "replace", "path": "/primaryContentSections", "value": null }
        let data = try encode(node, patches: [
            .replace(pointer: pointer("primaryContentSections"), encodableValue: Int?.none),
        ])

        expectPrimaryContentSections(
            in: data,
            swift: ["declarations: SwiftDeclaration", "content: Swift discussion"],
            occ: []
        )
    }

    // MARK: Patches that replace whole top-level properties

    /// Legacy variant overrides replace whole properties that don't vary. The decoder rejects them by path, without decoding the value.
    @Test(arguments: [
        "schemaVersion",
        "kind",
        "topicSectionsStyle",
        "diffAvailability",
        "sampleCodeDownload",
        "downloadNotAvailableSummary",
        "sections",
    ])
    func throwsForPatchesToNonVaryingProperties(name: String) throws {
        let node = makeNode(primaryContentSections: [declarations("SwiftDeclaration", language: "swift")])
        let data = try encode(node, patches: [
            .replace(pointer: pointer(name), encodableValue: "legacy value"),
        ])

        expectUnsupportedPatchError(decoding: data, at: "/\(name)")
    }

    /// Only individual metadata properties can vary, so legacy patches that replace the whole metadata are rejected.
    @Test func throwsForPatchThatReplacesWholeMetadata() throws {
        var node = makeNode()
        node.metadata.title = "MY_CONSTANT"
        node.metadata.role = "symbol"
        node.metadata.roleHeading = "Global Variable"

        var objcMetadata = node.metadata
        objcMetadata.roleHeading = "Macro"
        objcMetadata.symbolKind = "macro"

        let data = try encode(node, patches: [
            .replace(pointer: pointer("metadata"), encodableValue: objcMetadata),
        ])

        expectUnsupportedPatchError(decoding: data, at: "/metadata")
    }

    /// Only properties of a single reference can vary, so legacy patches that replace all the references are rejected.
    @Test func throwsForPatchThatReplacesAllReferences() throws {
        let referenceID = "doc://org.swift.docc.test/documentation/MyKit/MyClass"
        var node = makeNode()
        node.references[referenceID] = makeReference(id: referenceID, title: "SwiftTitle")

        let data = try encode(node, patches: [
            .replace(pointer: pointer("references"), encodableValue: [
                referenceID: CodableRenderReference(makeReference(id: referenceID, title: "ObjCTitle")),
            ]),
        ])

        expectUnsupportedPatchError(decoding: data, at: "/references")
    }

    // MARK: Patches with a null value for an optional array

    /// A `null` value for a property that is an optional array (here, the platforms of the metadata) means that the
    /// property has no value for that language. It decodes as `nil`, not as an empty array.
    @Test(arguments: ["add", "replace"])
    func decodesNullPatchForOptionalMetadataArrayAsNil(operation: String) throws {
        var node = makeNode()
        node.metadata.title = "myMethod()"
        // The Swift metadata only has platforms when the patch replaces them.
        if operation == "replace" {
            node.metadata.platforms = [.init(name: "iOS", introduced: "13.0", isBeta: false)]
        }

        let platformsPointer = pointer("metadata", "platforms")
        // { "op": "add" or "replace", "path": "/metadata/platforms", "value": null }
        let data = try encode(node, patches: [
            operation == "replace"
                ? .replace(pointer: platformsPointer, encodableValue: [AvailabilityRenderItem]?.none)
                : .add(pointer: platformsPointer, encodableValue: [AvailabilityRenderItem]?.none),
        ])

        let decoded = try decodeNode(data)

        let swiftPlatforms = resolved(decoded.metadata.platformsVariants, for: "swift")
        if operation == "replace" {
            #expect(swiftPlatforms?.count == 1)
        } else {
            #expect(swiftPlatforms == nil)
        }
        #expect(resolved(decoded.metadata.platformsVariants, for: "occ") == nil, "A null value is nil, not an empty array")
    }

    @Test func decodesNullPatchForOptionalReferenceArrayAsNil() throws {
        let referenceID = "doc://org.swift.docc.test/documentation/MyKit/MyClass"
        var node = makeNode()
        node.references[referenceID] = makeReference(
            id: referenceID,
            title: "MyClass",
            fragments: [.init(text: "class MyClass", kind: .text)]
        )

        // { "op": "replace", "path": "/references/<escaped reference ID>/fragments", "value": null }
        let data = try encode(node, patches: [
            .replace(pointer: pointer("references", referenceID, "fragments"), encodableValue: [DeclarationRenderSection.Token]?.none),
        ])

        let decoded = try decodeNode(data)

        let reference = try #require(decoded.references[referenceID] as? TopicRenderReference)
        #expect(resolved(reference.fragmentsVariants, for: "swift")?.count == 1)
        #expect(resolved(reference.fragmentsVariants, for: "occ") == nil, "A null value is nil, not an empty array")
    }

    // MARK: Test helpers

    private func makeNode(primaryContentSections: [any RenderSection] = []) -> RenderNode {
        var node = RenderNode(
            identifier: .init(bundleID: "org.swift.docc.test", path: "/documentation/MyKit/MyClass/myMethod()", sourceLanguage: .swift),
            kind: .symbol
        )
        node.metadata.title = "myMethod()"
        node.primaryContentSections = primaryContentSections
        return node
    }

    private func makeReference(
        id: String,
        title: String,
        fragments: [DeclarationRenderSection.Token]? = nil
    ) -> TopicRenderReference {
        TopicRenderReference(
            identifier: .init(id),
            title: title,
            abstract: [],
            url: "/documentation/mykit/myclass",
            kind: .symbol,
            fragments: fragments
        )
    }

    private func declarations(_ text: String, language: String) -> DeclarationsRenderSection {
        DeclarationsRenderSection(declarations: [
            .init(languages: [language], platforms: [], tokens: [.init(text: text, kind: .text)])
        ])
    }

    private func discussion(_ text: String) -> ContentRenderSection {
        ContentRenderSection(kind: .content, content: [.paragraph(.init(inlineContent: [.text(text)]))])
    }

    private func parameters() -> ParametersRenderSection {
        ParametersRenderSection(parameters: [.init(name: "param", content: [])])
    }

    private func pointer(_ pathComponents: String...) -> JSONPointer {
        JSONPointer(pathComponents: pathComponents)
    }

    private func encode(_ node: RenderNode, patches: [JSONPatchOperation]) throws -> Data {
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.userInfoVariantOverrides = VariantOverrides(values: [
            VariantOverride(traits: [.interfaceLanguage("occ")], patch: patches)
        ])
        return try encoder.encode(node)
    }

    private func expectPrimaryContentSections(
        in data: Data,
        swift: [String],
        occ: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let node: RenderNode
        do {
            node = try decodeNode(data)
        } catch {
            // Record the error at the call site. A thrown error is reported at the test function instead.
            Issue.record(error, "Failed to decode the render node", sourceLocation: sourceLocation)
            return
        }

        #expect(describe(sections(of: node, for: "swift")) == swift, "Swift sections", sourceLocation: sourceLocation)
        #expect(describe(sections(of: node, for: "occ")) == occ, "Objective-C sections", sourceLocation: sourceLocation)
    }

    private func expectUnsupportedPatchError(
        decoding data: Data,
        at path: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(sourceLocation: sourceLocation) {
            try decodeNode(data)
        } throws: { error in
            guard case DecodingError.dataCorrupted(let context) = error else { return false }
            return context.debugDescription.contains("Unsupported JSON patch for non-variant")
                && context.debugDescription.hasSuffix("at \(path)")
        }
    }

    private func decodeNode(_ data: Data) throws -> RenderNode {
        try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: data)
    }

    private func resolved<Value: VariantCollectionPatchable>(_ collection: VariantCollection<Value>, for languageID: String) -> Value {
        collection.applied(to: collection.defaultValue, for: [.interfaceLanguage(languageID)])
    }

    private func sections(of node: RenderNode, for languageID: String) -> [any RenderSection] {
        node.primaryContentSectionsVariants.compactMap { collection -> (any RenderSection)? in
            var section = collection.defaultValue
            for variant in collection.variants where variant.traits == [.interfaceLanguage(languageID)] {
                for patch in variant.patch {
                    switch patch {
                    case .replace(let value):
                        section = value
                    case .add:
                        Issue.record("Unexpected add patch in a primary content section's variant collection")
                    case .remove:
                        section = nil
                    }
                }
            }
            return section?.section
        }
    }

    private func describe(_ sections: [any RenderSection]) -> [String] {
        sections.map { section in
            switch section {
            case let declarations as DeclarationsRenderSection:
                let text = declarations.declarations.map { $0.tokens.map(\.text).joined() }.joined(separator: "\n")
                return "\(section.kind): \(text)"
            case let content as ContentRenderSection:
                let text = content.content.compactMap { block -> String? in
                    guard case .paragraph(let paragraph) = block else { return nil }
                    return paragraph.inlineContent.map(\.plainText).joined()
                }.joined(separator: "\n")
                return "\(section.kind): \(text)"
            default:
                return "\(section.kind)"
            }
        }
    }
}
