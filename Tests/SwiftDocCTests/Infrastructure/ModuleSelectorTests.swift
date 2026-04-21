/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Testing
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon

struct ModuleSelectorTests {
    @Test
    func resolvesModuleSelectorLinks() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Delta", symbols: [
                makeSymbol(id: "s:Delta5DeltaV", kind: .struct, pathComponents: ["DeltaStruct"]), // A struct named DeltaStruct
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")

        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let deltaStruct = try tree.find(path: "Delta::DeltaStruct", onlyFindSymbols: true)
        
        let expectedStruct = try tree.find(path: "/Delta/DeltaStruct", onlyFindSymbols: true)
        #expect(deltaStruct == expectedStruct)
    }

    @Test
    func resolvesModuleSelectorLinksWithSameNameAsModule() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Delta", symbols: [
                makeSymbol(id: "s:Delta5DeltaV", kind: .struct, pathComponents: ["Delta"]), // A struct named Delta
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")

        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let deltaStruct = try tree.find(path: "Delta::Delta", onlyFindSymbols: true)
        
        let expectedStruct = try tree.find(path: "/Delta/Delta", onlyFindSymbols: true)
        #expect(deltaStruct == expectedStruct)
    }

    @Test
    func resolvesNestedModuleSelectorLinks() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Delta", symbols: [
                makeSymbol(id: "s:Delta5DeltaV", kind: .struct, pathComponents: ["Delta"]),
                makeSymbol(id: "s:Delta5DeltaV6NestedV", kind: .struct, pathComponents: ["Delta", "Nested"]),
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")

        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let nestedStruct = try tree.find(path: "Delta::Delta/Nested", onlyFindSymbols: true)
        
        let expectedNested = try tree.find(path: "/Delta/Delta/Nested", onlyFindSymbols: true)
        #expect(nestedStruct == expectedNested)
    }
}
