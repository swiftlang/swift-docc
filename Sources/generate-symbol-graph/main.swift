/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
@testable import SwiftDocC

struct Directive {
    var name: String

    /// The name of the type that implements this directive.
    ///
    /// This information is not presented in the documentation. It's only used to find undocumented directives.
    var implementationName: String
    
    /// `true` if the directive accepts arguments.
    var acceptsArguments: Bool = true

    /// `true` if the directive doesn't expect body content.
    var isLeaf: Bool
    
    init(name: String, implementationName: String? = nil, acceptsArguments: Bool = true, isLeaf: Bool) {
        self.name = name
        self.implementationName = implementationName ?? name
        self.acceptsArguments = acceptsArguments
        self.isLeaf = isLeaf
    }
    
    var usr: String {
        return directiveUSR(name)
    }
}

extension DirectiveMirror.ReflectedDirective {
    var documentableArguments: [DirectiveMirror.ReflectedArgument] {
        arguments.filter { !$0.hiddenFromDocumentation }
    }
}

func directiveUSR(_ directiveName: String) -> String {
    "__docc_universal_symbol_reference_$\(directiveName)"
}

extension SymbolGraph.Symbol.DeclarationFragments.Fragment: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        self.init(kind: .text, spelling: value, preciseIdentifier: nil)
    }
    
    init<S: StringProtocol>(
        _ value: S,
        kind: SymbolGraph.Symbol.DeclarationFragments.Fragment.Kind = .text,
        preciseIdentifier: String? = nil
    ) {
        self.init(kind: kind, spelling: String(value), preciseIdentifier: preciseIdentifier)
    }
}

extension SymbolGraph.LineList.Line: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        self.init(text: value, range: nil)
    }
}

let supportedDirectives: [Directive] = [

    // MARK: Tutorial Table of Contents

    .init(
        name: "Tutorials",
        implementationName: "Technology",
        isLeaf: false
    ),
    .init(
        name: "Volume",
        isLeaf: false
    ),
    .init(
        name: "Resources",
        acceptsArguments: false,
        isLeaf: false
    ),
    .init(
        name: "Documentation",
        implementationName: "Tile",
        isLeaf: false
    ),
    .init(
        name: "SampleCode",
        implementationName: "Tile",
        isLeaf: false
    ),
    .init(
        name: "Downloads",
        implementationName: "Tile",
        isLeaf: false
    ),
    .init(
        name: "Videos",
        implementationName: "Tile",
        isLeaf: false
    ),
    .init(
        name: "Forums",
        implementationName: "Tile",
        isLeaf: false
    ),
    .init(
        name: "Section",
        implementationName: "TutorialSection",
        isLeaf: false
    ),
    .init(
        name: "Article",
        implementationName: "TutorialArticle",
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
        name: "MultipleChoice",
        acceptsArguments: false,
        isLeaf: false
    ),

    // MARK: Shared

    .init(
        name: "Comment",
        acceptsArguments: false,
        isLeaf: false
    ),
] + DirectiveIndex.shared.indexedDirectives.values.filter { directive in
        !directive.hiddenFromDocumentation
    }
    .map { directive in
        return Directive(
            name: directive.name,
            acceptsArguments: !directive.documentableArguments.isEmpty,
            isLeaf: !directive.allowsMarkup && directive.childDirectives.isEmpty
        )
    }

enum SymbolGraphError: Error {
    case noDataReadFromFile(path: String)
}

func generateSwiftDocCFrameworkSymbolGraph() throws -> SymbolGraph {
    let packagePath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent() // generate-symbol-graph
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // swift-docc
    
    let buildDirectory = Bundle.main.executableURL!
        .deletingLastPathComponent()
        .appendingPathComponent(".swift-docc-symbol-graph-build", isDirectory: true)
    
    let symbolGraphOutputDirectory = buildDirectory.appendingPathComponent(
        "symbol-graphs",
        isDirectory: true
    )
    
    try FileManager.default.createDirectory(
        at: symbolGraphOutputDirectory,
        withIntermediateDirectories: true
    )
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"]!)
    process.arguments = [
        "-c",
        """
        swift build --package-path \(packagePath.path) \
          --scratch-path \(buildDirectory.path) \
          --target SwiftDocC \
          -Xswiftc -emit-symbol-graph \
          -Xswiftc -emit-symbol-graph-dir -Xswiftc \(symbolGraphOutputDirectory.path) \
          -Xswiftc -symbol-graph-minimum-access-level -Xswiftc internal
        """
    ]
    
    try process.run()
    process.waitUntilExit()
    
    let symbolGraphURL = symbolGraphOutputDirectory.appendingPathComponent(
        "SwiftDocC.symbols.json",
        isDirectory: false
    )
    
    let symbolGraphFileHandle = try FileHandle(forReadingFrom: symbolGraphURL)
    guard let symbolGraphData = try symbolGraphFileHandle.readToEnd() else {
        throw SymbolGraphError.noDataReadFromFile(path: symbolGraphURL.path)
    }
    return try JSONDecoder().decode(SymbolGraph.self, from: symbolGraphData)
}

func extractDocumentationCommentsForDirectives() throws -> [String : SymbolGraph.LineList] {
    let swiftDocCFrameworkSymbolGraph = try generateSwiftDocCFrameworkSymbolGraph()
    
    let directiveSymbolUSRs: [String] = swiftDocCFrameworkSymbolGraph.relationships.compactMap { relationship in
        guard relationship.kind == .conformsTo
            && relationship.target == "s:9SwiftDocC29AutomaticDirectiveConvertibleP"
        else {
            return nil
        }
    
        return relationship.source
    }
    let directiveSymbols = Set(directiveSymbolUSRs)
        .compactMap { swiftDocCFrameworkSymbolGraph.symbols[$0] }
        .map { (String($0.title.split(separator: ".").last ?? $0.title[...]), $0) }
    
    let missingDirectiveSymbolNames: [String] = swiftDocCFrameworkSymbolGraph.relationships.compactMap { relationship in
        guard relationship.kind == .conformsTo,
              relationship.target == "s:9SwiftDocC20DirectiveConvertibleP",
              !directiveSymbolUSRs.contains(relationship.source),
              let symbol = swiftDocCFrameworkSymbolGraph.symbols[relationship.source]
        else {
            return nil
        }
    
        guard !supportedDirectives.contains(where: { $0.implementationName == symbol.names.title }) else {
            return nil
        }
        
        switch symbol.kind.identifier {
        case .struct, .class:
            return symbol.names.title
        default:
            return nil
        }
    }
    
    for missingDirective in missingDirectiveSymbolNames {
        print("warning: '\(missingDirective)' is not included in the documentation")
    }
    
    let directiveDocComments: [(String, SymbolGraph.LineList)] = directiveSymbols.compactMap {
        let (directiveImplementationName, directiveSymbol) = $0
        
        guard let indexedDirective = DirectiveIndex.shared.reflection(of: directiveImplementationName) else {
            if let docComment = directiveSymbol.docComment {
                return (directiveImplementationName, docComment)
            } else {
                return nil
            }
        }
        
        let directiveSymbolMembers = swiftDocCFrameworkSymbolGraph.relationships.filter {
            return $0.kind == .memberOf && $0.target == directiveSymbol.preciseIdentifier!
        }
        .map(\.source)
        .compactMap { swiftDocCFrameworkSymbolGraph.symbols[$0] }
        
        var parametersDocumentation = [SymbolGraph.LineList.Line]()
        var createdParametersSection = false
        for argument in indexedDirective.documentableArguments {
            let argumentDisplayName: String
            if argument.name.isEmpty {
                argumentDisplayName = argument.propertyLabel
            } else {
                argumentDisplayName = argument.name
            }
            
            let argumentSymbol = directiveSymbolMembers.first { member in
                member.title == argument.propertyLabel && member.docComment != nil
            } ?? directiveSymbolMembers.first { member in
                member.title == argument.name && member.docComment != nil
            }
            
            guard let argumentDocComment = argumentSymbol?.docComment else {
                continue
            }
            
            guard !argumentDocComment.lines.isEmpty else {
                continue
            }
            
            if !createdParametersSection {
                parametersDocumentation.append("- Parameters:")
                createdParametersSection = true
            }
            
            var insertedRequirementText = false
            for (index, line) in argumentDocComment.lines.map(\.text).enumerated() {
                if index == 0 {
                    parametersDocumentation.append("  - \(argumentDisplayName): \(line)")
                } else {
                    parametersDocumentation.append("     \(line)")
                }
                
                guard !insertedRequirementText else {
                    continue
                }
                
                // If we're at the end of the comment or the end of the first paragraph,
                // insert in the required/optional disclaimer.
                if index == argumentDocComment.lines.count - 1
                    || argumentDocComment.lines[index + 1].text.trimmingCharacters(
                           in: .whitespacesAndNewlines
                       ).isEmpty
                {
                    if argument.required {
                        parametersDocumentation.append("     **(required)**")
                    } else {
                        parametersDocumentation.append("     **(optional)**")
                    }
                    
                    insertedRequirementText = true
                }
            }
            
            guard let allowedValues = argument.allowedValues, !allowedValues.isEmpty else {
                continue
            }
            
            let argumentType = argument.typeDisplayName.components(
                separatedBy: CharacterSet(charactersIn: "? ")
            ).first!
            
            let allowedValueType = directiveSymbolMembers.first { member in
                member.title.split(separator: ".").last == argumentType[...]
            }
            
            guard let allowedValueType = allowedValueType?.preciseIdentifier else {
                continue
            }
            
            let childrenOfAllowedValueType = swiftDocCFrameworkSymbolGraph.relationships.filter { relationship in
                return relationship.kind == .memberOf && relationship.target == allowedValueType
            }
            .map(\.source)
            .compactMap { swiftDocCFrameworkSymbolGraph.symbols[$0] }
            
            for allowedValue in allowedValues {
                guard let allowedValueDocComment = childrenOfAllowedValueType.first(where: {
                    $0.title.contains(allowedValue)
                })?.docComment else { continue }
                
                for (index, line) in allowedValueDocComment.lines.map(\.text).enumerated() {
                    if index == 0 {
                        parametersDocumentation.append("     - term `\(allowedValue)`: \(line)")
                    } else {
                        parametersDocumentation.append("        \(line)")
                    }
                }
            }
        }
        
        var docComment = directiveSymbol.docComment ?? SymbolGraph.LineList([])
        docComment.lines = docComment.lines.map { line in
            var line = line
            line.range = nil
            return line
        }
        docComment.moduleName = nil
        docComment.uri = nil
        
        if let topicsSectionIndex = docComment.lines.firstIndex(where: { line in
            line.text.replacingOccurrences(of: " ", with: "").hasPrefix("##Topics")
        }) {
            parametersDocumentation.append("")
            docComment.lines.insert(contentsOf: parametersDocumentation, at: topicsSectionIndex)
        } else {
            docComment.lines.append(contentsOf: parametersDocumentation)
        }
        
        if docComment.lines.isEmpty {
            return nil
        } else {
            return (indexedDirective.name, docComment)
        }
    }
    
    return Dictionary(uniqueKeysWithValues: directiveDocComments)
}

let documentationComments = try extractDocumentationCommentsForDirectives()

func declarationFragments(
    for directiveName: String,
    primaryReference: Bool,
    includeFullChildren: Bool,
    includeMinimalChildren: Bool
) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
    guard DirectiveIndex.shared.indexedDirectives[directiveName] == nil else {
        return declarationFragments(
            for: DirectiveIndex.shared.indexedDirectives[directiveName]!,
            primaryReference: primaryReference,
            includeFullChildren: includeFullChildren,
            includeMinimalChildren: includeMinimalChildren
        )
    }
    
    let shouldUseTypeIdentifiers = includeFullChildren || includeMinimalChildren
    
    let directive = supportedDirectives.first { directive in
        directive.name == directiveName
    }!
    
    var fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = [
        .init("@", kind: shouldUseTypeIdentifiers ? .typeIdentifier : .identifier),
        .init(
            directive.name,
            kind: shouldUseTypeIdentifiers ? .typeIdentifier : .identifier,
            preciseIdentifier: primaryReference ? nil : directiveUSR(directive.name)
        ),
    ]
    
    if directive.acceptsArguments {
        fragments.append("(...)")
    }
    
    guard !directive.isLeaf else {
        return fragments
    }
    
    if includeFullChildren {
        fragments.append(" {\n    ...\n}")
    } else if includeMinimalChildren {
        fragments.append(" { ... }")
    }
    
    return fragments
}

func declarationFragments(
    for directive: DirectiveMirror.ReflectedDirective,
    primaryReference: Bool,
    includeFullChildren: Bool,
    includeMinimalChildren: Bool
) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
    var fragments = [SymbolGraph.Symbol.DeclarationFragments.Fragment]()
    
    let shouldUseTypeIdentifiers = includeFullChildren || includeMinimalChildren
    
    fragments.append(
        contentsOf: [
            .init("@", kind: shouldUseTypeIdentifiers ? .typeIdentifier : .identifier),
            .init(
                directive.name,
                kind: shouldUseTypeIdentifiers ? .typeIdentifier : .identifier,
                preciseIdentifier: primaryReference ? nil : directiveUSR(directive.name)
            ),
        ]
    )
    
    if !directive.documentableArguments.isEmpty {
        fragments.append("(")
    }
    
    for (index, argument) in directive.documentableArguments.enumerated() {
        if argument.labelDisplayName.hasPrefix("_ ") {
            fragments.append("_ ")
            let adjustedLabel = argument.labelDisplayName.trimmingCharacters(in: CharacterSet(charactersIn: " _"))
            fragments.append(.init(adjustedLabel, kind: .identifier))
        } else {
            fragments.append(.init(argument.labelDisplayName, kind: .identifier))
        }
        
        fragments.append(": ")
        
        let splitLocation = argument.typeDisplayName.firstIndex {
            $0 == " " || $0 == "?"
        }
        
        if let splitLocation = splitLocation {
            fragments.append(
                .init(
                    argument.typeDisplayName.prefix(upTo: splitLocation),
                    kind: .typeIdentifier
                )
            )
            
            if includeFullChildren || includeMinimalChildren {
                fragments.append(.init(argument.typeDisplayName.suffix(from: splitLocation)))
            }
        } else {
            fragments.append(.init(argument.typeDisplayName, kind: .typeIdentifier))
        }
        
        if index < directive.documentableArguments.count - 1 {
            fragments.append(", ")
        } else {
            fragments.append(")")
        }
    }
    
    let requiredChildDirectives = directive.childDirectives.filter(\.required)
    
    if (includeMinimalChildren && !includeFullChildren)
        && (!requiredChildDirectives.isEmpty || directive.allowsMarkup)
    {
        fragments.append(" { ... }")
    }
    
    guard includeFullChildren else {
        return fragments
    }
    
    if !requiredChildDirectives.isEmpty {
        fragments.append(" {\n")
        
        if directive.allowsMarkup {
            fragments.append("    ...\n\n")
        }
        
        for childDirective in requiredChildDirectives {
            guard childDirective.required else {
                continue
            }
            
            let childDeclarationFragments = declarationFragments(
                for: childDirective.name,
                primaryReference: false,
                includeFullChildren: false,
                includeMinimalChildren: true
            )
            
            fragments.append("    ")
            
            for var childDeclarationFragment in childDeclarationFragments {
                childDeclarationFragment.spelling = childDeclarationFragment.spelling.replacingOccurrences(
                    of: "\n",
                    with: "\n    "
                )
                
                fragments.append(childDeclarationFragment)
            }
            
            fragments.append("\n")
        }
        
        fragments.append("}")
    } else if directive.allowsMarkup || !directive.childDirectives.isEmpty {
        fragments.append(" {\n    ...\n}")
    }
    
    return fragments
}

let symbols: [SymbolGraph.Symbol] = supportedDirectives.map { directive in
    let fragments = declarationFragments(
        for: directive.name,
        primaryReference: true,
        includeFullChildren: true,
        includeMinimalChildren: false
    )
    
    let navigatorFragments = declarationFragments(
        for: directive.name,
        primaryReference: true,
        includeFullChildren: false,
        includeMinimalChildren: false
    )
    
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
            subHeading: navigatorFragments,
            prose: nil
        ),
        pathComponents: [
            directive.name
        ],
        docComment: documentationComments[directive.name],
        accessLevel: .init(rawValue: "public"),
        kind: .init(parsedIdentifier: .class, displayName: "Directive"),
        mixins: [
            SymbolGraph.Symbol.DeclarationFragments.mixinKey: SymbolGraph.Symbol.DeclarationFragments(
                declarationFragments: fragments
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
        name: "docc",
        platform: .init(architecture: nil, vendor: nil, operatingSystem: nil, environment: nil),
        version: .init(major: 1, minor: 0, patch: 0, prerelease: nil, buildMetadata: nil),
        bystanders: []
    ),
    symbols: symbols,
    relationships: []
)

private struct SortedSymbolGraph: Codable {
    var wrapped: SymbolGraph
    init(_ symbolGraph: SymbolGraph) {
        wrapped = symbolGraph
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SymbolGraph.CodingKeys.self)
        try container.encode(wrapped.metadata, forKey: .metadata)
        try container.encode(wrapped.module, forKey: .module)
        try container.encode(wrapped.symbols.values.sorted(by: \.identifier.precise), forKey: .symbols)
        try container.encode(wrapped.relationships, forKey: .relationships)
    }
    
    init(from decoder: Decoder) throws {
        try self.init(SymbolGraph(from: decoder))
    }
}

let output = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("docc/DocCDocumentation.docc/docc.symbols.json")
var encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try! encoder.encode(SortedSymbolGraph(symbolGraph))
try! data.write(to: output)
