/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import Foundation
import XCTest
import SymbolKit
import SwiftDocC

// MARK: - Symbol Graph objects

extension XCTestCase {
    
    package func makeSymbolGraph(
        moduleName: String,
        platform: SymbolGraph.Platform = .init(),
        symbols: [SymbolGraph.Symbol] = [],
        relationships: [SymbolGraph.Relationship] = []
    ) -> SymbolGraph {
        return SymbolGraph(
            metadata: makeMetadata(),
            module: makeModule(moduleName: moduleName, platform: platform),
            symbols: symbols,
            relationships: relationships
        )
    }
    
    package func makeMetadata(major: Int = 0, minor: Int = 6, patch: Int = 0) -> SymbolGraph.Metadata {
        SymbolGraph.Metadata(
            formatVersion: SymbolGraph.SemanticVersion(major: major, minor: minor, patch: patch),
            generator: "unit-test"
        )
    }
    
    package func makeModule(moduleName: String, platform: SymbolGraph.Platform = .init()) -> SymbolGraph.Module {
        SymbolGraph.Module(name: moduleName, platform: platform)
    }
    
    // MARK: Line List
    
    package func makeLineList(
        docComment: String,
        startOffset: SymbolGraph.LineList.SourceRange.Position = defaultSymbolPosition,
        url: URL = defaultSymbolURL
    ) -> SymbolGraph.LineList {
        SymbolGraph.LineList(
            // Create a `LineList/Line` for each line of the doc comment and calculate a realistic range for each line.
            docComment.components(separatedBy: .newlines)
                .enumerated()
                .map { lineOffset, line in
                    SymbolGraph.LineList.Line(
                        text: line,
                        range: SymbolGraph.LineList.SourceRange(
                            start: .init(line: startOffset.line + lineOffset, character: startOffset.character),
                            end:   .init(line: startOffset.line + lineOffset, character: startOffset.character + line.count)
                        )
                    )
                },
            // We want to include the file:// scheme here
            uri: url.absoluteString
        )
    }
    
    package func makeMixins(_ mixins: [any Mixin]) -> [String: any Mixin] {
        [String: any Mixin](
            mixins.map { (type(of: $0).mixinKey, $0) },
            uniquingKeysWith: { old, _ in old /* Keep the first encountered value */ }
        )
    }
    
    // MARK: Symbol
    
    package func makeSymbol(
        id: String,
        language: SourceLanguage = .swift,
        kind kindID: SymbolGraph.Symbol.KindIdentifier,
        pathComponents: [String],
        docComment: String? = nil,
        accessLevel: SymbolGraph.Symbol.AccessControl = .init(rawValue: "public"), // Defined internally in SwiftDocC
        location: (position: SymbolGraph.LineList.SourceRange.Position, url: URL)? = (defaultSymbolPosition, defaultSymbolURL),
        signature: SymbolGraph.Symbol.FunctionSignature? = nil,
        otherMixins: [any Mixin] = []
    ) -> SymbolGraph.Symbol {
        precondition(!pathComponents.isEmpty, "Need at least one path component to name the symbol")
        
        var mixins = otherMixins // Earlier mixins are prioritized if there are duplicates
        if let location {
            mixins.append(SymbolGraph.Symbol.Location(uri: location.url.absoluteString /* we want to include the file:// scheme */, position: location.position))
        }
        if let signature {
            mixins.append(signature)
        }
        
        return SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(precise: id, interfaceLanguage: language.id),
            names: makeSymbolNames(name: pathComponents.first!),
            pathComponents: pathComponents,
            docComment: docComment.map {
                makeLineList(
                    docComment: $0,
                    startOffset: location?.position ?? defaultSymbolPosition,
                    url: location?.url ?? defaultSymbolURL
                )
            },
            accessLevel: accessLevel,
            kind: makeSymbolKind(kindID),
            mixins: makeMixins(mixins)
        )
    }
    
    package func makeSymbolNames(name: String) -> SymbolGraph.Symbol.Names {
        SymbolGraph.Symbol.Names(
            title: name,
            navigator: [.init(kind: .identifier, spelling: name, preciseIdentifier: nil)],
            subHeading: [.init(kind: .identifier, spelling: name, preciseIdentifier: nil)],
            prose: nil
        )
    }
    
    package func makeSymbolKind(_ kindID: SymbolGraph.Symbol.KindIdentifier) -> SymbolGraph.Symbol.Kind {
        var documentationNodeKind: DocumentationNode.Kind {
            switch kindID {
            case .associatedtype: .associatedType
            case .class:          .class
            case .deinit:         .deinitializer
            case .enum:           .enumeration
            case .case:           .enumerationCase
            case .func:           .function
            case .operator:       .operator
            case .`init`:         .initializer
            case .ivar:           .instanceVariable
            case .macro:          .macro
            case .method:         .instanceMethod
            case .namespace:      .namespace
            case .property:       .instanceProperty
            case .protocol:       .protocol
            case .snippet:        .snippet
            case .struct:         .structure
            case .subscript:      .instanceSubscript
            case .typeMethod:     .typeMethod
            case .typeProperty:   .typeProperty
            case .typeSubscript:  .typeSubscript
            case .typealias:      .typeAlias
            case .union:          .union
            case .var:            .globalVariable
            case .module:         .module
            case .extension:      .extension
            case .dictionary:     .dictionary
            case .dictionaryKey:  .dictionaryKey
            case .httpRequest:    .httpRequest
            case .httpParameter:  .httpParameter
            case .httpResponse:   .httpResponse
            case .httpBody:       .httpBody
            default:              .unknown
            }
        }
        return SymbolGraph.Symbol.Kind(parsedIdentifier: kindID, displayName: documentationNodeKind.name)
    }
}
    
// MARK: Constants

private let defaultSymbolPosition = SymbolGraph.LineList.SourceRange.Position(line: 11, character: 17) // an arbitrary non-zero start position
private let defaultSymbolURL = URL(fileURLWithPath: "/Users/username/path/to/SomeFile.swift")

// MARK: - JSON strings

extension XCTestCase {
    public func makeSymbolGraphString(moduleName: String, symbols: String = "", relationships: String = "", platform: String = "") -> String {
        return """
        {
          "metadata": {
              "formatVersion": {
                  "major": 0,
                  "minor": 6,
                  "patch": 0
              },
              "generator": "unit-test"
          },
          "module": {
              "name": "\(moduleName)",
              "platform": { \(platform) }
          },
          "relationships" : [
            \(relationships)
          ],
          "symbols" : [
            \(symbols)
          ]
        }
        """
    }
}
