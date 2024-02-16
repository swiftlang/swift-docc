/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities
@testable import SymbolKit

class DoxygenTests: XCTestCase {
    func testDoxygenDiscussionAndNote() throws {
        let documentationLines: [SymbolGraph.LineList.Line] = """
            This is an abstract.

            @discussion This is a discussion linking to ``AnotherClass`` and ``AnotherClass/prop``.

            @note This is a note linking to ``Class3`` and ``Class3/prop2``.
            """
            .splitByNewlines
            .enumerated()
            .map { index, line in
                SymbolGraph.LineList.Line(
                    text: line,
                    range: .init(start: .init(line: 1 + index, character: 1), end: .init(line: 1 + index, character: 1 + line.utf8.count))
                )
            }

        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        SymbolGraph.Symbol(
                            identifier: .init(precise: "some-class-id", interfaceLanguage: SourceLanguage.swift.id),
                            names: .init(title: "SomeClass", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["SomeClass"],
                            docComment: .init(documentationLines),
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                            mixins: [:]
                        ),
                        SymbolGraph.Symbol(
                            identifier: .init(precise: "another-class-id", interfaceLanguage: SourceLanguage.swift.id),
                            names: .init(title: "AnotherClass", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["AnotherClass"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                            mixins: [:]
                        ),
                        SymbolGraph.Symbol(
                            identifier: .init(precise: "another-class-prop-id", interfaceLanguage: SourceLanguage.swift.id),
                            names: .init(title: "prop", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["AnotherClass", "prop"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .property, displayName: "Kind Display Name"),
                            mixins: [:]
                        ),
                        SymbolGraph.Symbol(
                            identifier: .init(precise: "class3-id", interfaceLanguage: SourceLanguage.swift.id),
                            names: .init(title: "Class3", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["Class3"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                            mixins: [:]
                        ),
                        SymbolGraph.Symbol(
                            identifier: .init(precise: "class3-prop-id", interfaceLanguage: SourceLanguage.swift.id),
                            names: .init(title: "prop", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["Class3", "prop"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .property, displayName: "Kind Display Name"),
                            mixins: [:]
                        ),
                    ]
                )),
            ])
        ])

        let (_, bundle, context) = try loadBundle(from: tempURL)
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/SomeClass", sourceLanguage: .swift)

        // Verify the expected content in the in-memory model
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)

        XCTAssertEqual(symbol.abstract?.format(), "This is an abstract.")
        XCTAssertEqual(symbol.discussion?.content.map { $0.format() }, [
            #"\discussion This is a discussion linking to ``doc://unit-test/documentation/ModuleName/AnotherClass`` and ``doc://unit-test/documentation/ModuleName/AnotherClass/prop``."#,
            #"\note This is a note linking to ``doc://unit-test/documentation/ModuleName/Class3`` and ``Class3/prop2``."#
        ])

        // Verify the expected content in the render model
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = try XCTUnwrap(translator.visit(node.semantic) as? RenderNode)

        XCTAssertEqual(renderNode.abstract, [.text("This is an abstract.")])
        XCTAssertEqual(renderNode.primaryContentSections.count, 1)

        let overviewSection = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection)
        XCTAssertEqual(overviewSection.content.count, 3)
        XCTAssertEqual(overviewSection.content, [
            .heading(.init(level: 2, text: "Overview", anchor: "overview")),

            .paragraph(.init(inlineContent: [
                .text("This is a discussion linking to "),
                .reference(
                    identifier: .init("doc://unit-test/documentation/ModuleName/AnotherClass"),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                ),
                .text(" and "),
                .reference(
                    identifier: .init("doc://unit-test/documentation/ModuleName/AnotherClass/prop"),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                ),
                .text(".")
            ])),

            .aside(.init(style: .init(asideKind: .note), content: [
                .paragraph(.init(inlineContent: [
                    .text("This is a note linking to "),
                    .reference(
                        identifier: .init("doc://unit-test/documentation/ModuleName/Class3"),
                        isActive: true,
                        overridingTitle: nil,
                        overridingTitleInlineContent: nil
                    ),
                    .text(" and "),
                    .codeVoice(code: "Class3/prop2"),
                    .text(".")
                ]))
            ])),
        ])
    }
}
