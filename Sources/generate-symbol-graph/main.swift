/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

struct Directive {
    var name: String

    /// `true` if the directive accepts arguments.
    var acceptsArguments: Bool = true

    /// `true` if the directive doesn't expect body content.
    var isLeaf: Bool

    var usr: String {
        return "__docc_universal_symbol_reference_$\(name)"
    }
}

let supportedDirectives: [Directive] = [
    // MARK: Reference

    .init(
        name: "Metadata",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "DocumentationExtension",
        isLeaf: true
    ),
    .init(
        name: "DisplayName",
        isLeaf: true
    ),

    // MARK: Technology Root

    .init(
        name: "TechnologyRoot",
        acceptsArguments: false,
        isLeaf: true
    ),

    // MARK: Tutorial Table of Contents

    .init(
        name: "Tutorials",
        isLeaf: false
    ),
    .init(
        name: "Volume",
        isLeaf: false
    ),
    .init(
        name: "Chapter",
        isLeaf: false
    ),
    .init(
        name: "TutorialReference",
        isLeaf: true
    ),
    .init(
        name: "Resources",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Documentation",
        isLeaf: false
    ),
    .init(
        name: "SampleCode",
        isLeaf: false
    ),
    .init(
        name: "Downloads",
        isLeaf: false
    ),
    .init(
        name: "Videos",
        isLeaf: false
    ),
    .init(
        name: "Forums",
        isLeaf: false
    ),
    .init(
        name: "Tutorial",
        isLeaf: false
    ),
    .init(
        name: "Intro",
        isLeaf: false
    ),
    .init(
        name: "XcodeRequirement",
        acceptsArguments: true,
        isLeaf: true
    ),
    .init(
        name: "Section",
        isLeaf: false
    ),
    .init(
        name: "ContentAndMedia",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Steps",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Step",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Code",
        isLeaf: false
    ),
    .init(
        name: "Assessments",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "MultipleChoice",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Choice",
        isLeaf: false
    ),
    .init(
        name: "Justification",
        isLeaf: false
    ),

    // MARK: Tutorial Articles

    .init(
        name: "Stack",
        acceptsArguments: false,
        isLeaf: false
    ),

    // MARK: Shared

    .init(
        name: "Comment",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Image",
        isLeaf: true
    ),
    .init(
        name: "Video",
        isLeaf: true
    )
]

let symbols: [SymbolGraph.Symbol] = supportedDirectives.map { directive in
    var extraDeclarationFragments = [SymbolGraph.Symbol.DeclarationFragments.Fragment]()

    /*
        If the directive accepts arguments, then
        render the parentheses which make it look like it can accept arguments.
    */
    if directive.acceptsArguments {
        extraDeclarationFragments.append(.init(kind: .text, spelling: "(...)", preciseIdentifier: nil))
    }

    /*
        If the directive is not a leaf (aka it has child directives or body content), then
        render the curly braces which make it look like it can have children.
    */
    if !directive.isLeaf {
        extraDeclarationFragments.append(.init(kind: .text, spelling: " {\n  ...\n}", preciseIdentifier: nil))
    }

    return SymbolGraph.Symbol(
        identifier: SymbolGraph.Symbol.Identifier(
            precise: directive.usr,
            interfaceLanguage: "swift"
        ),
        names: SymbolGraph.Symbol.Names(
            title: directive.name,
            navigator: [
                .init(kind: .attribute, spelling: "@", preciseIdentifier: nil),
                .init(kind: .identifier, spelling: directive.name, preciseIdentifier: directive.usr)
            ],
            subHeading: [
                .init(kind: .attribute, spelling: "@", preciseIdentifier: nil),
                .init(kind: .identifier, spelling: directive.name, preciseIdentifier: directive.usr)
            ],
            prose: nil
        ),
        pathComponents: [
            directive.name
        ],
        docComment: nil,
        accessLevel: .init(rawValue: "public"),
        kind: .init(parsedIdentifier: .class, displayName: "Directive"),
        mixins: [
            SymbolGraph.Symbol.DeclarationFragments.mixinKey: SymbolGraph.Symbol.DeclarationFragments(
                declarationFragments: [
                    .init(kind: .typeIdentifier, spelling: "@", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: directive.name, preciseIdentifier: nil),
                ] + extraDeclarationFragments
            )
        ]
    )
}

// Emits SGFs for the different directives we support.
let symbolGraph = SymbolGraph(
    metadata: SymbolGraph.Metadata(
        formatVersion: .init(major: 1, minor: 0, patch: 0, prerelease: nil, buildMetadata: nil),
        generator: "docc-generate-symbol-graph"
    ),
    module: SymbolGraph.Module(
        name: "DocC",
        platform: .init(architecture: nil, vendor: nil, operatingSystem: nil, environment: nil),
        version: .init(major: 1, minor: 0, patch: 0, prerelease: nil, buildMetadata: nil),
        bystanders: []
    ),
    symbols: symbols,
    relationships: []
)

let output = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("DocCDocumentation/DocCDocumentation.docc/DocC.symbols.json")
var encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try! encoder.encode(symbolGraph)
try! data.write(to: output)
