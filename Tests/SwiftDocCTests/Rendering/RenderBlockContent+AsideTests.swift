/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
@testable import SwiftDocC
import Testing

struct RenderBlockContent_AsideTests {

    typealias Aside = RenderBlockContent.Aside
    typealias AsideStyle = RenderBlockContent.AsideStyle

    let testBlock: RenderBlockContent = .paragraph(
        RenderBlockContent.Paragraph(
            inlineContent: [
                RenderInlineContent.text("This is a test paragraph")
            ]
        )
    )

    private func testStyle(for name: String) -> AsideStyle {
        .init(rawValue: name)
    }

    private func decodeAsideRenderBlock(_ json: String) throws -> Aside? {
        guard let data = json.data(using: .utf8) else {
            Issue.record("Found unexpected string encoding.")
            return nil
        }
        let decodedBlock = try JSONDecoder().decode(RenderBlockContent.self, from: data)
        guard case let .aside(aside) = decodedBlock else {
            Issue.record("Decoded an unexpected type of block.")
            return nil
        }
        return aside
    }

    // Styles supported by DocC Render
    @Test(arguments: [
        "Note", "note",
        "Tip", "tip",
        "Experiment", "experiment",
        "Important", "important",
        "Warning", "warning"
    ])
    func testCreatingSupportedAside(name: String) throws {

        // Creating a style will lowercase the name
        let style = testStyle(for: name)
        #expect(style.rawValue == name.lowercased())

        // Aside created with all three attributes.
        // All three attributes should be retained.
        var aside = Aside(
            style: style,
            name: name,
            content: [testBlock]
        )
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside created from the style only.
        // The name should use the capitalized style raw value.
        aside = Aside(style: style, content: [testBlock])
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name.capitalized)
        #expect(aside.content == [testBlock])

        // Aside created from the name only.
        // The style should use the lowercased name.
        aside = Aside(name: name, content: [testBlock])
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside created from the Swift Markdown aside kind.
        // The style will use the lowercased name.
        // The name use the capitalized style raw value.
        aside = Aside(asideKind: .init(rawValue: name)!, content: [testBlock])
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name.capitalized)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON.
        // The style will normally use the lowercased name.
        // The name will be retained.
        var json = """
            {
              "type": "aside",
              "style": "\(name.lowercased())",
              "name": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON, containing an unexpected capitalized style.
        // The style will be lowercased.
        // The name will be retained.
        json = """
            {
              "type": "aside",
              "style": "\(name)",
              "name": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON - missing name. Render JSON
        // may contain a style but not a name. In this case,
        // the name should use the capitalized style raw value.
        json = """
            {
              "type": "aside",
              "style": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == name.lowercased())
        #expect(aside.name == name.capitalized)
        #expect(aside.content == [testBlock])
    }

    // Custom styles, not supported by DocC Render
    @Test(arguments: ["Custom", "unknown", "Special"])
    func testCreatingCustomAside(name: String) throws {

        let style = testStyle(for: name)

        // Aside created from all three attributes.
        // The style will always be lowercase "note".
        var aside = Aside(
            style: style,
            name: name,
            content: [testBlock]
        )
        #expect(aside.style.rawValue == "note")
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside created from the style only.
        // The name will always be capitalized "Note".
        aside = Aside(style: style, content: [testBlock])
        #expect(aside.style == style)
        #expect(aside.name == "Note")
        #expect(aside.content == [testBlock])

        // Aside created from the name only.
        // The style will always be "note"
        aside = Aside(name: name, content: [testBlock])
        #expect(aside.style.rawValue == "note")
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside created from the Swift Markdown aside kind.
        // The style will always be "note"
        // The name use the capitalized style raw value.
        aside = Aside(asideKind: .init(rawValue: name)!, content: [testBlock])
        #expect(aside.style.rawValue == "note")
        #expect(aside.name == name.capitalized)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON.
        // The style will always be "note" - JSON should not exist with unknown styles
        // The name use the capitalized style raw value.
        var json = """
            {
              "type": "aside",
              "style": "note",
              "name": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "note")
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON, containing an unexpected "Note"
        // capitalized style. The style will be lowercased.
        // The name will be retained.
        json = """
            {
              "type": "aside",
              "style": "Note",
              "name": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "note") // coerced to lowercase
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON - missing name. Custom styles
        // missing a name are coerced to "Note".
        json = """
            {
              "type": "aside",
              "style": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "note")
        #expect(aside.name == "Note")
        #expect(aside.content == [testBlock])
    }

    // Asides with different names and styles.
    @Test(arguments: [
        ("Important", "tip"),
        ("Custom", "warning"),
        ("Special", "note"),
    ])
    func testCreatingSupportedAside(name: String, styleName: String) throws {

        let style = testStyle(for: styleName)

        // Aside created with all three attributes.
        // All three attributes should be retained.
        var aside = Aside(
            style: style,
            name: name,
            content: [testBlock]
        )
        #expect(aside.style.rawValue == styleName)
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON.
        // The style will normally use the lowercased name.
        // The name will be retained.
        var json = """
            {
              "type": "aside",
              "style": "\(styleName)",
              "name": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == styleName)
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])

        // Aside decoded from JSON, containing an unexpected capitalized style.
        // The style will be lowercased.
        // The name will be retained.
        json = """
            {
              "type": "aside",
              "style": "\(styleName.capitalized)",
              "name": "\(name)",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == styleName)
        #expect(aside.name == name)
        #expect(aside.content == [testBlock])
    }

    // In Render JSON, the style should always be "note" or one of the supported
    // DocC Render styles. Test that invalid, known styles are coerced to "note"
    // when decoded.
    @Test
    func testJSONWithInvalidStyle() throws {

        var json = """
            {
              "type": "aside",
              "style": "custom",
              "name": "Custom",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        var aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "note") // not "custom"
        #expect(aside.name == "Custom")
        #expect(aside.content == [testBlock])

        json = """
            {
              "type": "aside",
              "style": "custom",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "note") // not "custom"
        #expect(aside.name == "Note") // discard the invalid style in this case
        #expect(aside.content == [testBlock])
    }

    // If the name and style do not match, retain both.
    @Test
    func testJSONDifferentNameAndStyle() throws {

        var json = """
            {
              "type": "aside",
              "style": "tip",
              "name": "Important",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        var aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "tip")
        #expect(aside.name == "Important")
        #expect(aside.content == [testBlock])

        json = """
            {
              "type": "aside",
              "style": "different",
              "name": "Custom",
              "content": [
                {
                  "inlineContent": [
                    {
                      "text": "This is a test paragraph",
                      "type": "text"
                    }
                  ],
                  "type": "paragraph"
                }
              ]
            }
            """
        aside = try #require(try decodeAsideRenderBlock(json))
        #expect(aside.style.rawValue == "note") // coerced to "note"
        #expect(aside.name == "Custom")
        #expect(aside.content == [testBlock])
    }
}
