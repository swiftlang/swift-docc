/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC

class ExtendedTypesFormatTransformationTests: XCTestCase {
    /// Tests the general transformation structure of ``ExtendedTypesFormatTransformation/transformExtensionBlockFormatToExtendedTypeFormat(_:)``
    /// including the edge case that one extension graph contains extensions for two modules.
    func testExtendedTypesFormatStructure() throws {
        let contents = twoExtensionBlockSymbolsExtendingSameType(extendedModule: "A", extendedType: "A", withExtensionMembers: true)
                        + twoExtensionBlockSymbolsExtendingSameType(extendedModule: "A", extendedType: "ATwo", withExtensionMembers: true)
                        + twoExtensionBlockSymbolsExtendingSameType(extendedModule: "B", extendedType: "B", withExtensionMembers: true)
        
        var graph = makeSymbolGraph(moduleName: "Module",
                                    symbols: contents.symbols,
                                    relationships: contents.relationships)
        
        // check the transformation recognizes the swift.extension symbols & transform
        XCTAssert(try ExtendedTypesFormatTransformation.transformExtensionBlockFormatToExtendedTypeFormat(&graph))
        
        // check the expected symbols exist
        let extendedModuleA = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedModule && symbol.title == "A" }))
        let extendedModuleB = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedModule && symbol.title == "B" }))
        
        let extendedTypeA = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedStructure && symbol.title == "A" }))
        let extendedTypeATwo = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedStructure && symbol.title == "ATwo" }))
        let extendedTypeB = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedStructure && symbol.title == "B" }))
        
        let addedMemberSymbolsTypeA = graph.symbols.values.filter({ symbol in symbol.kind.identifier == .property && symbol.pathComponents[symbol.pathComponents.count-2] == "A" })
        XCTAssertEqual(addedMemberSymbolsTypeA.count, 2)
        let addedMemberSymbolsTypeATwo = graph.symbols.values.filter({ symbol in symbol.kind.identifier == .property && symbol.pathComponents[symbol.pathComponents.count-2] == "ATwo" })
        XCTAssertEqual(addedMemberSymbolsTypeATwo.count, 2)
        let addedMemberSymbolsTypeB = graph.symbols.values.filter({ symbol in symbol.kind.identifier == .property && symbol.pathComponents[symbol.pathComponents.count-2] == "B" })
        XCTAssertEqual(addedMemberSymbolsTypeB.count, 2)
        
        // check the symbols are connected as expected
        [
            SymbolGraph.Relationship(source: addedMemberSymbolsTypeA[0].identifier.precise, target: extendedTypeA.identifier.precise, kind: .memberOf, targetFallback: nil),
            SymbolGraph.Relationship(source: addedMemberSymbolsTypeA[1].identifier.precise, target: extendedTypeA.identifier.precise, kind: .memberOf, targetFallback: nil),
            SymbolGraph.Relationship(source: addedMemberSymbolsTypeATwo[0].identifier.precise, target: extendedTypeATwo.identifier.precise, kind: .memberOf, targetFallback: nil),
            SymbolGraph.Relationship(source: addedMemberSymbolsTypeATwo[1].identifier.precise, target: extendedTypeATwo.identifier.precise, kind: .memberOf, targetFallback: nil),
            SymbolGraph.Relationship(source: addedMemberSymbolsTypeB[0].identifier.precise, target: extendedTypeB.identifier.precise, kind: .memberOf, targetFallback: nil),
            SymbolGraph.Relationship(source: addedMemberSymbolsTypeB[1].identifier.precise, target: extendedTypeB.identifier.precise, kind: .memberOf, targetFallback: nil),
            
            SymbolGraph.Relationship(source: extendedTypeA.identifier.precise, target: extendedModuleA.identifier.precise, kind: .declaredIn, targetFallback: nil),
            SymbolGraph.Relationship(source: extendedTypeATwo.identifier.precise, target: extendedModuleA.identifier.precise, kind: .declaredIn, targetFallback: nil),
            SymbolGraph.Relationship(source: extendedTypeB.identifier.precise, target: extendedModuleB.identifier.precise, kind: .declaredIn, targetFallback: nil),
        ].forEach { test in
            XCTAssert(graph.relationships.contains(where: { sample in
                sample.source == test.source && sample.target == test.target && sample.kind == test.kind
            }))
        }
        
        // check there are no additional elements
        XCTAssertEqual(graph.symbols.count, 2 /* extended modules */ + 3 /* extended types */ + 6 /* added properties */)
        XCTAssertEqual(graph.relationships.count, 3 /* .declaredIn */ + 6 /* .memberOf */)
        
        // check correct module name was prepended to pathComponents
        ([extendedModuleA, extendedTypeA, extendedTypeATwo]
         + addedMemberSymbolsTypeA
         + addedMemberSymbolsTypeATwo).forEach { symbol in
            XCTAssertEqual(symbol.pathComponents.first, "A")
        }
        
        ([extendedModuleB, extendedTypeB]
         + addedMemberSymbolsTypeB).forEach { symbol in
            XCTAssertEqual(symbol.pathComponents.first, "B")
        }
    }
    
    /// Tests that an extended type symbol always uses the documentation comment with the highest number
    /// of lines from the relevant extension block symbols.
    ///
    /// ```swift
    /// /// This is shorter...won't be chosen.
    /// extension A { /* ... */ }
    ///
    /// /// This is the longest as it
    /// /// has two lines. It will be chosen.
    /// extension A { /* ... */ }
    /// ```
    func testDocumentationForExtendedTypeSymbolUsesLongestAvailableDocumenation() throws {
        let content = twoExtensionBlockSymbolsExtendingSameType(sameDocCommentLength: false)
        for permutation in allPermutations(of: content.symbols, and: content.relationships) {
            var graph = makeSymbolGraph(moduleName: "Module", symbols: permutation.symbols, relationships: permutation.relationships)
            _ = try ExtendedTypesFormatTransformation.transformExtensionBlockFormatToExtendedTypeFormat(&graph)
            
            let extendedTypeSymbol = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedStructure }))
            XCTAssertEqual(extendedTypeSymbol.docComment?.lines.count, 2)
        }
    }
    
    /// Tests that extended type symbols are always based on the same extension block symbol (if there is more than
    /// one for the same type), which influences the extended type symbol's unique identifier.
    func testBaseSymbolForExtendedTypeSymbolIsStable() throws {
        let content = twoExtensionBlockSymbolsExtendingSameType()
        for permutation in allPermutations(of: content.symbols, and: content.relationships) {
            var graph = makeSymbolGraph(moduleName: "Module", symbols: permutation.symbols, relationships: permutation.relationships)
            _ = try ExtendedTypesFormatTransformation.transformExtensionBlockFormatToExtendedTypeFormat(&graph)
            
            let extendedTypeSymbol = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedStructure }))
            XCTAssertEqual(extendedTypeSymbol.identifier.precise, "s:e:s:AAone") // one < two (alphabetically)
        }
    }
    
    /// Tests that extended module symbols are always based on the same extended type symbol (if there is more than
    /// one for the same module), which influences the extended module symbol's unique identifier.
    func testBaseSymbolForExtendedModuleSymbolIsStable() throws {
        let content = twoExtensionBlockSymbolsExtendingSameType()
        for permutation in allPermutations(of: content.symbols, and: content.relationships) {
            var graph = makeSymbolGraph(moduleName: "Module", symbols: permutation.symbols, relationships: permutation.relationships)
            _ = try ExtendedTypesFormatTransformation.transformExtensionBlockFormatToExtendedTypeFormat(&graph)
            
            let extendedModuleSymbol = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedModule }))
            XCTAssertEqual(extendedModuleSymbol.identifier.precise, "s:m:s:e:s:AAone") // one < two (alphabetically)
        }
    }
    
    /// Tests that an extended type symbol always uses the same documentation comment if there is more than one relevant
    /// extension block symbol that features the highest number of lines in its doc-comment.
    func testDocumentationForExtendedTypeSymbolIsStable() throws {
        let content = twoExtensionBlockSymbolsExtendingSameType(sameDocCommentLength: true)
        for permutation in allPermutations(of: content.symbols, and: content.relationships) {
            var graph = makeSymbolGraph(moduleName: "Module", symbols: permutation.symbols, relationships: permutation.relationships)
            _ = try ExtendedTypesFormatTransformation.transformExtensionBlockFormatToExtendedTypeFormat(&graph)
            
            let extendedTypeSymbol = try XCTUnwrap(graph.symbols.values.first(where: { symbol in symbol.kind.identifier == .extendedStructure }))
            XCTAssertEqual(extendedTypeSymbol.docComment?.lines.first?.text, "one line") // one < two (alphabetically)
        }
    }
    
    /// Tests that if a unified symbol graph contains more than one extended module symbols for the same module, these extended
    /// module symbols are merged into one and that this symbol's identifier does not depend on the graph's order.
    func testCrossModuleNestedTypeExtensionsHandling() throws {
        let aAtB = (graph: makeSymbolGraph(moduleName: "A", symbols: [
            .init(identifier: .init(precise: "s:m:s:e:s:Bone", interfaceLanguage: "swift"),
                  names: .init(title: "B", navigator: nil, subHeading: nil, prose: nil),
                  pathComponents: ["B"],
                  docComment: nil,
                  accessLevel: .public,
                  kind: .init(parsedIdentifier: .extendedModule, displayName: "Extended Module"),
                  mixins: [:])
        ]), url: URL(fileURLWithPath: "A@B.symbols.json"))
        
        let aAtC = (graph: makeSymbolGraph(moduleName: "A", symbols: [
            .init(identifier: .init(precise: "s:m:s:e:s:Btwo", interfaceLanguage: "swift"),
                  names: .init(title: "B", navigator: nil, subHeading: nil, prose: nil),
                  pathComponents: ["B"],
                  docComment: nil,
                  accessLevel: .public,
                  kind: .init(parsedIdentifier: .extendedModule, displayName: "Extended Module"),
                  mixins: [:]),
            .init(identifier: .init(precise: "s:m:s:e:s:C", interfaceLanguage: "swift"),
                  names: .init(title: "C", navigator: nil, subHeading: nil, prose: nil),
                  pathComponents: ["C"],
                  docComment: nil,
                  accessLevel: .public,
                  kind: .init(parsedIdentifier: .extendedModule, displayName: "Extended Module"),
                  mixins: [:])
        ]), url: URL(fileURLWithPath: "A@C.symbols.json"))
        
        for files in allPermutations(of: [aAtB, aAtC]) {
            let unifiedGraph = try XCTUnwrap(UnifiedSymbolGraph(fromSingleGraph: makeSymbolGraph(moduleName: "A"), at: .init(fileURLWithPath: "A.symbols.json")))
            for file in files {
                unifiedGraph.mergeGraph(graph: file.graph, at: file.url)
            }
            
            ExtendedTypesFormatTransformation.mergeExtendedModuleSymbolsFromDifferentFiles(unifiedGraph)
            
            let extendedModuleSymbols = unifiedGraph.symbols.values.filter({ symbol in symbol.kindIdentifier == "swift." + SymbolGraph.Symbol.KindIdentifier.extendedModule.identifier })
            XCTAssertEqual(extendedModuleSymbols.count, 2)
            
            let extendedModuleSymbolForB = try XCTUnwrap(extendedModuleSymbols.first(where: { symbol in symbol.title == "B" }))
            XCTAssertEqual(extendedModuleSymbolForB.uniqueIdentifier, "s:m:s:e:s:Bone") // one < two (alphabetically)
        }
    }
    
    // MARK: Helpers
    
    private struct SymbolGraphContents {
        let symbols: [SymbolGraph.Symbol]
        let relationships: [SymbolGraph.Relationship]
    
        static func +(lhs: Self, rhs: Self) -> Self {
            SymbolGraphContents(symbols: lhs.symbols + rhs.symbols, relationships: lhs.relationships + rhs.relationships)
        }
    }
    
    private func twoExtensionBlockSymbolsExtendingSameType(extendedModule: String = "A", extendedType: String = "A", withExtensionMembers: Bool = false, sameDocCommentLength: Bool = true) -> SymbolGraphContents {
        SymbolGraphContents(symbols: [.init(identifier: .init(precise: "s:e:s:\(extendedModule)\(extendedType)two", interfaceLanguage: "swift"),
              names: .init(title: "\(extendedType)", navigator: nil, subHeading: nil, prose: nil),
              pathComponents: ["\(extendedType)"],
              docComment: .init([
                .init(text: "two", range: nil)
              ] + (sameDocCommentLength ? [] : [.init(text: "lines", range: nil)])),
              accessLevel: .public,
              kind: .init(parsedIdentifier: .extension, displayName: "Extension"),
              mixins: [
                SymbolGraph.Symbol.Swift.Extension.mixinKey: SymbolGraph.Symbol.Swift.Extension(extendedModule: "\(extendedModule)", typeKind: .struct, constraints: [])
              ]),
        .init(identifier: .init(precise: "s:e:s:\(extendedModule)\(extendedType)one", interfaceLanguage: "swift"),
              names: .init(title: "\(extendedType)", navigator: nil, subHeading: nil, prose: nil),
              pathComponents: ["\(extendedType)"],
              docComment: .init([
                .init(text: "one line", range: nil)
              ]),
              accessLevel: .public,
              kind: .init(parsedIdentifier: .extension, displayName: "Extension"),
              mixins: [
                SymbolGraph.Symbol.Swift.Extension.mixinKey: SymbolGraph.Symbol.Swift.Extension(extendedModule: "\(extendedModule)", typeKind: .struct, constraints: [])
              ])
        ] + (withExtensionMembers ? [
        .init(identifier: .init(precise: "s:\(extendedModule)\(extendedType)two", interfaceLanguage: "swift"),
              names: .init(title: "two", navigator: nil, subHeading: nil, prose: nil),
              pathComponents: ["\(extendedType)", "two"],
              docComment: nil,
              accessLevel: .public,
              kind: .init(parsedIdentifier: .property, displayName: "Property"),
              mixins: [
                SymbolGraph.Symbol.Swift.Extension.mixinKey: SymbolGraph.Symbol.Swift.Extension(extendedModule: "\(extendedModule)", typeKind: .struct, constraints: [])
              ]),
        .init(identifier: .init(precise: "s:\(extendedModule)\(extendedType)one", interfaceLanguage: "swift"),
              names: .init(title: "one", navigator: nil, subHeading: nil, prose: nil),
              pathComponents: ["\(extendedType)", "one"],
              docComment: nil,
              accessLevel: .public,
              kind: .init(parsedIdentifier: .property, displayName: "Property"),
              mixins: [
                SymbolGraph.Symbol.Swift.Extension.mixinKey: SymbolGraph.Symbol.Swift.Extension(extendedModule: "\(extendedModule)", typeKind: .struct, constraints: [])
              ])
        ] : [])
        , relationships: [
            .init(source: "s:e:s:\(extendedModule)\(extendedType)two", target: "s:\(extendedModule)\(extendedType)", kind: .extensionTo, targetFallback: "\(extendedModule).\(extendedType)"),
            .init(source: "s:e:s:\(extendedModule)\(extendedType)one", target: "s:\(extendedModule)\(extendedType)", kind: .extensionTo, targetFallback: "\(extendedModule).\(extendedType)")
        ] + (withExtensionMembers ? [
            .init(source: "s:\(extendedModule)\(extendedType)two", target: "s:e:s:\(extendedModule)\(extendedType)two", kind: .memberOf, targetFallback: "\(extendedModule).\(extendedType)"),
            .init(source: "s:\(extendedModule)\(extendedType)one", target: "s:e:s:\(extendedModule)\(extendedType)one", kind: .memberOf, targetFallback: "\(extendedModule).\(extendedType)")
        ] : []))
    }
    
    private func allPermutations(of symbols: [SymbolGraph.Symbol], and relationships: [SymbolGraph.Relationship]) -> [(symbols: [SymbolGraph.Symbol], relationships: [SymbolGraph.Relationship])] {
        let symbolPermutations = allPermutations(of: symbols)
        let relationshipPermutations = allPermutations(of: relationships)
        
        var permutations: [([SymbolGraph.Symbol], [SymbolGraph.Relationship])] = []
        
        for sp in symbolPermutations {
            for rp in relationshipPermutations {
                permutations.append((sp, rp))
            }
        }
        
        return permutations
    }
    
    private func allPermutations<C: Collection>(of a: C) -> [[C.Element]] {
        var a = Array(a)
        var p: [[C.Element]] = []
        p.reserveCapacity(Int(pow(Double(2), Double(a.count))))
        permutations(a.count, &a, calling: { p.append($0) })
        return p
    }

    // https://en.wikipedia.org/wiki/Heap's_algorithm
    private func permutations<C: MutableCollection>(_ n:Int, _ a: inout C, calling report: (C) -> Void) where C.Index == Int {
        if n == 1 {
            report(a)
            return
        }
        for i in 0..<n-1 {
            permutations(n-1, &a, calling: report)
            let temp = a[n-1]
            a[n-1] = a[(n%2 == 1) ? 0 : i]
            a[(n%2 == 1) ? 0 : i] = temp
        }
        permutations(n-1, &a, calling: report)
    }
}
