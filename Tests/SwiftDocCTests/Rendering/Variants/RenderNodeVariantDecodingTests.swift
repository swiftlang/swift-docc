/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import SwiftDocC
import Foundation

/// Tests that decoding a render node populates its variant collections from the `variantOverrides` JSON patches.
///
/// Each test describes a Swift render node and a list of JSON patches that turn it into the Objective-C version.
struct RenderNodeVariantDecodingTests {

    // MARK: Primary content sections

    /// A patch that inserts a section in the middle of the list shifts the position of the sections after it,
    /// so the next patch refers to the position of the content section _after_ the insertion.
    @Test func decodesPrimaryContentSectionsWithInsertedSection() {
        let json = makeJSON(
            primaryContentSections: """
            {
              "kind": "declarations",
              "declarations": [
                { "tokens": [{ "kind": "text", "text": "SwiftDeclaration" }], "languages": ["swift"], "platforms": [] }
              ]
            },
            {
              "kind": "content",
              "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Swift discussion" }] }
              ]
            }
            """,
            patches: """
            {
              "op": "replace",
              "path": "/primaryContentSections/0",
              "value": {
                "kind": "declarations",
                "declarations": [
                  { "tokens": [{ "kind": "text", "text": "ObjCDeclaration" }], "languages": ["occ"], "platforms": [] }
                ]
              }
            },
            {
              "op": "add",
              "path": "/primaryContentSections/1",
              "value": {
                "kind": "parameters",
                "parameters": [{ "name": "param", "content": [] }]
              }
            },
            {
              "op": "replace",
              "path": "/primaryContentSections/2",
              "value": {
                "kind": "content",
                "content": [
                  { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "ObjC discussion" }] }
                ]
              }
            }
            """
        )

        expectPrimaryContentSections(
            in: json,
            swift: ["declarations: SwiftDeclaration", "content: Swift discussion"],
            occ: ["declarations: ObjCDeclaration", "parameters", "content: ObjC discussion"]
        )
    }

    /// A patch that adds a section at the end of the list.
    @Test func decodesPrimaryContentSectionsWithAppendedSection() {
        let json = makeJSON(
            primaryContentSections: """
            {
              "kind": "declarations",
              "declarations": [
                { "tokens": [{ "kind": "text", "text": "SwiftDeclaration" }], "languages": ["swift"], "platforms": [] }
              ]
            },
            {
              "kind": "content",
              "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Swift discussion" }] }
              ]
            }
            """,
            patches: """
            {
              "op": "replace",
              "path": "/primaryContentSections/0",
              "value": {
                "kind": "declarations",
                "declarations": [
                  { "tokens": [{ "kind": "text", "text": "ObjCDeclaration" }], "languages": ["occ"], "platforms": [] }
                ]
              }
            },
            {
              "op": "replace",
              "path": "/primaryContentSections/1",
              "value": {
                "kind": "content",
                "content": [
                  { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "ObjC discussion" }] }
                ]
              }
            },
            {
              "op": "add",
              "path": "/primaryContentSections/2",
              "value": {
                "kind": "parameters",
                "parameters": [{ "name": "param", "content": [] }]
              }
            }
            """
        )

        expectPrimaryContentSections(
            in: json,
            swift: ["declarations: SwiftDeclaration", "content: Swift discussion"],
            occ: ["declarations: ObjCDeclaration", "content: ObjC discussion", "parameters"]
        )
    }

    /// A patch that replaces the whole list with a longer list.
    /// The sections beyond the end of the Swift list only exist in the Objective-C variant.
    @Test func decodesReplacingPrimaryContentSectionsWithMoreSections() {
        let json = makeJSON(
            primaryContentSections: """
            {
              "kind": "declarations",
              "declarations": [
                { "tokens": [{ "kind": "text", "text": "SwiftDeclaration" }], "languages": ["swift"], "platforms": [] }
              ]
            }
            """,
            patches: """
            {
              "op": "replace",
              "path": "/primaryContentSections",
              "value": [
                {
                  "kind": "declarations",
                  "declarations": [
                    { "tokens": [{ "kind": "text", "text": "ObjCDeclaration" }], "languages": ["occ"], "platforms": [] }
                  ]
                },
                {
                  "kind": "parameters",
                  "parameters": [{ "name": "param", "content": [] }]
                },
                {
                  "kind": "content",
                  "content": [
                    { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "ObjC discussion" }] }
                  ]
                }
              ]
            }
            """
        )

        expectPrimaryContentSections(
            in: json,
            swift: ["declarations: SwiftDeclaration"],
            occ: ["declarations: ObjCDeclaration", "parameters", "content: ObjC discussion"]
        )
    }

    /// A patch that replaces the whole list with a shorter list.
    /// The Swift sections beyond the end of the Objective-C list are removed in the Objective-C variant.
    @Test func decodesReplacingPrimaryContentSectionsWithFewerSections() {
        let json = makeJSON(
            primaryContentSections: """
            {
              "kind": "declarations",
              "declarations": [
                { "tokens": [{ "kind": "text", "text": "SwiftDeclaration" }], "languages": ["swift"], "platforms": [] }
              ]
            },
            {
              "kind": "parameters",
              "parameters": [{ "name": "param", "content": [] }]
            },
            {
              "kind": "content",
              "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Swift discussion" }] }
              ]
            }
            """,
            patches: """
            {
              "op": "replace",
              "path": "/primaryContentSections",
              "value": [
                {
                  "kind": "declarations",
                  "declarations": [
                    { "tokens": [{ "kind": "text", "text": "ObjCDeclaration" }], "languages": ["occ"], "platforms": [] }
                  ]
                }
              ]
            }
            """
        )

        expectPrimaryContentSections(
            in: json,
            swift: ["declarations: SwiftDeclaration", "parameters", "content: Swift discussion"],
            occ: ["declarations: ObjCDeclaration"]
        )
    }

    /// A patch that replaces the whole list with `null` removes all the sections in the Objective-C variant only.
    /// The Swift sections are unaffected.
    @Test func decodesReplacingPrimaryContentSectionsWithNull() {
        let json = makeJSON(
            primaryContentSections: """
            {
              "kind": "declarations",
              "declarations": [
                { "tokens": [{ "kind": "text", "text": "SwiftDeclaration" }], "languages": ["swift"], "platforms": [] }
              ]
            },
            {
              "kind": "content",
              "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Swift discussion" }] }
              ]
            }
            """,
            patches: """
            {
              "op": "replace",
              "path": "/primaryContentSections",
              "value": null
            }
            """
        )

        expectPrimaryContentSections(
            in: json,
            swift: ["declarations: SwiftDeclaration", "content: Swift discussion"],
            occ: []
        )
    }

    // MARK: Patches that replace whole top-level properties

    /// Some legacy variant overrides replace entire top-level properties that don't vary between languages.
    /// Those patches aren't valid, so decoding the render node throws an error instead of ignoring them.
    @Test(arguments: [
        ("schemaVersion", #"{ "major": 0, "minor": 3, "patch": 0 }"#),
        ("kind", #""symbol""#),
        ("topicSectionsStyle", #""compactGrid""#),
        ("diffAvailability", #"{ "major": { "change": "added", "platform": "MyPlatform", "versions": ["1.0", "2.0 beta 1"] } }"#),
        ("sampleCodeDownload", """
            { "action": { "isActive": true, "overridingTitle": "Download", "type": "reference", "identifier": "https://example.com/downloads/MySample.zip" } }
            """),
        ("downloadNotAvailableSummary", #"[{ "type": "paragraph", "inlineContent": [{ "type": "text", "text": "This download isn't available." }] }]"#),
        ("sections", "[]"),
    ])
    func throwsForPatchesToNonVaryingProperties(name: String, value: String) {
        let json = makeJSON(
            primaryContentSections: """
            {
              "kind": "declarations",
              "declarations": [
                { "tokens": [{ "kind": "text", "text": "SwiftDeclaration" }], "languages": ["swift"], "platforms": [] }
              ]
            }
            """,
            patches: """
            { "op": "replace", "path": "/\(name)", "value": \(value) }
            """
        )

        expectUnsupportedPatchError(decoding: json, at: "/\(name)")
    }

    /// The metadata itself isn't a variant: a patch can only apply to one of its properties. A patch that replaces the
    /// whole metadata (as the legacy variant overrides do) isn't valid, so decoding the render node throws an error.
    @Test func throwsForPatchThatReplacesWholeMetadata() {
        let json = makeJSON(
            patches: """
            {
              "op": "replace",
              "path": "/metadata",
              "value": {
                "title": "MY_CONSTANT",
                "role": "symbol",
                "roleHeading": "Macro",
                "symbolKind": "macro"
              }
            }
            """,
            metadata: """
            {
              "title": "MY_CONSTANT",
              "role": "symbol",
              "roleHeading": "Global Variable"
            }
            """
        )

        expectUnsupportedPatchError(decoding: json, at: "/metadata")
    }

    /// The references dictionary isn't a variant: a patch can only apply to a property of one reference. A patch that
    /// replaces all the references (as the legacy variant overrides do) isn't valid, so decoding the render node throws
    /// an error.
    @Test func throwsForPatchThatReplacesAllReferences() {
        let referenceID = "doc://org.swift.docc.test/documentation/MyKit/MyClass"
        let json = makeJSON(
            patches: """
            {
              "op": "replace",
              "path": "/references",
              "value": {
                "\(referenceID)": {
                  "type": "topic",
                  "identifier": "\(referenceID)",
                  "title": "ObjCTitle",
                  "url": "/documentation/mykit/myclass",
                  "kind": "symbol"
                }
              }
            }
            """,
            references: """
            {
              "\(referenceID)": {
                "type": "topic",
                "identifier": "\(referenceID)",
                "title": "SwiftTitle",
                "url": "/documentation/mykit/myclass",
                "kind": "symbol"
              }
            }
            """
        )

        expectUnsupportedPatchError(decoding: json, at: "/references")
    }

    // MARK: Test helpers

    /// Returns the JSON for a Swift render node with the given primary content sections and Objective-C variant overrides.
    ///
    /// - Parameters:
    ///   - primaryContentSections: The JSON for the elements of the render node's `primaryContentSections` array.
    ///   - patches: The JSON for the elements of the `patch` array of the Objective-C variant override.
    ///   - metadata: The JSON for the render node's `metadata` object.
    ///   - references: The JSON for the render node's `references` object.
    private func makeJSON(
        primaryContentSections: String = "",
        patches: String,
        metadata: String = #"{ "title": "myMethod()" }"#,
        references: String = "{}"
    ) -> String {
        """
        {
          "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
          "identifier": { "url": "doc://org.swift.docc.test/documentation/MyKit/MyClass/myMethod()", "interfaceLanguage": "swift" },
          "kind": "symbol",
          "metadata": \(metadata),
          "sections": [],
          "references": \(references),
          "primaryContentSections": [
            \(primaryContentSections)
          ],
          "variantOverrides": [
            {
              "traits": [{ "interfaceLanguage": "occ" }],
              "patch": [
                \(patches)
              ]
            }
          ]
        }
        """
    }

    /// Decodes the render node JSON and checks the primary content sections for each language.
    ///
    /// - Parameters:
    ///   - json: The render node JSON to decode.
    ///   - swift: The expected descriptions of the Swift sections. See ``describe(_:)``.
    ///   - occ: The expected descriptions of the Objective-C sections. See ``describe(_:)``.
    private func expectPrimaryContentSections(
        in json: String,
        swift: [String],
        occ: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let node: RenderNode
        do {
            node = try decodeNode(json)
        } catch {
            // Record the error at the call site. A thrown error is reported at the test function instead.
            Issue.record(error, "Failed to decode the render node", sourceLocation: sourceLocation)
            return
        }

        #expect(describe(sections(of: node, for: "swift")) == swift, "Swift sections", sourceLocation: sourceLocation)
        #expect(describe(sections(of: node, for: "occ")) == occ, "Objective-C sections", sourceLocation: sourceLocation)
    }

    /// Checks that decoding the render node JSON throws the error for a JSON patch that isn't for a variant property.
    ///
    /// - Parameters:
    ///   - json: The render node JSON to decode.
    ///   - path: The path of the patch that can't be decoded.
    private func expectUnsupportedPatchError(
        decoding json: String,
        at path: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(sourceLocation: sourceLocation) {
            try decodeNode(json)
        } throws: { error in
            guard case DecodingError.dataCorrupted(let context) = error else { return false }
            return context.debugDescription.contains("Unsupported JSON patch for non-variant")
                && context.debugDescription.hasSuffix("at \(path)")
        }
    }

    /// Decodes the render node JSON.
    private func decodeNode(_ json: String) throws -> RenderNode {
        try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: Data(json.utf8))
    }

    /// Returns the primary content sections of the render node for the given language.
    ///
    /// Each primary content section is its own variant collection. The section for a language is the collection's
    /// default value with the patches of that language's variants applied. Sections that end up as `nil` are omitted.
    private func sections(of node: RenderNode, for languageID: String) -> [any RenderSection] {
        node.primaryContentSectionsVariants.compactMap { collection -> (any RenderSection)? in
            var section = collection.defaultValue
            for variant in collection.variants where variant.traits == [.interfaceLanguage(languageID)] {
                for patch in variant.patch {
                    switch patch {
                    case .replace(let value), .add(let value):
                        section = value
                    case .remove:
                        section = nil
                    }
                }
            }
            return section?.section
        }
    }

    /// Returns a short description of each section: its kind and, for declarations and content, its text.
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
