/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities

struct SymbolGraphLoaderTests {
    @Test
    func loadingDifferentMainSymbolGraphFiles() throws {
        var loader = try makeLoader {
            for moduleName in ["One", "Two", "Three"] {
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: moduleName))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 3, "Loaded all 3 symbol graphs")
        
        var moduleNameFrequency = [String: Int]()
        for graph in loader.unifiedGraphs.values {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        #expect(moduleNameFrequency == ["One": 1, "Two": 1, "Three": 1])
    }
    
    @Test
    func loadingDifferentExtensionSymbolGraphFiles() throws {
        var loader = try makeLoader {
            for moduleName in ["One", "Two", "Three"] {
                JSONFile(name: "Something@\(moduleName).symbols.json", content: makeSymbolGraph(moduleName: moduleName))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 3, "Loaded all 3 symbol graphs")
        
        var moduleNameFrequency = [String: Int]()
        for graph in loader.unifiedGraphs.values {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        #expect(moduleNameFrequency == ["One": 1, "Two": 1, "Three": 1])
    }
    
    @Test
    func doesNotUnifyExtendedModulesWithTheExtendingModule() throws {
        var loader = try makeLoader {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Main")) // This is the extend_ing_ module.
            
            for moduleName in ["One", "Two", "Three"] { // These are all extend_ed_ modules.
                JSONFile(name: "Main@\(moduleName).symbols.json", content: makeSymbolGraph(moduleName: moduleName))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 4, "Loaded all 4 symbol graphs")
        
        var moduleNameFrequency = [String: Int]()
        for graph in loader.unifiedGraphs.values {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        #expect(moduleNameFrequency == ["Main": 1, "One": 1, "Two": 1, "Three": 1])
    }
    
    // This test calls ``SymbolGraph.relationships`` which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated) // `SymbolGraph.relationships` doesn't specify when it will be removed
    @Test
    func loadingHighNumberOfSymbolGraphFilesConcurrently() throws {
        let symbols = (0..<20).map { id in
            makeSymbol(id: "symbol-\(id)", kind: .class, pathComponents: ["SomeClass\(id)"])
        }
        let symbolGraph = makeSymbolGraph(moduleName: "Something", symbols: symbols)
        
        var loader = try makeLoader {
            for number in 0 ..< 100 {
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Something\(number)", symbols: symbols))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 100, "Loaded all 100 symbol graphs")
        
        var loadedGraphs = 0
        for graph in loader.unifiedGraphs.values {
            loadedGraphs += 1
            #expect(graph.symbols.count       == symbolGraph.symbols.count)
            #expect(graph.relationships.count == symbolGraph.relationships.count)
        }
        #expect(loadedGraphs == 100)
    }
    
    @Test
    func bystanderExtensionsAreCombinedWithTheExtendedModule() async throws {
        var loader = try makeLoader {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Main"))
            
            JSONFile(name: "Main@Extending@_Main_Extending.symbols.json", content: SymbolGraph(
                metadata: makeMetadata(),
                module: .init(name: "Main", platform: .init(), bystanders: ["Extending"]),
                symbols: [],
                relationships: []
            ))
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 1, "The extension symbol graph is combined with the extended module")
        
        let graph = try #require(loader.unifiedGraphs.values.first)
        #expect(graph.moduleName == "Main")
        
        #expect(graph.moduleData.values.contains(where: { $0.bystanders == ["Extending"] }))
    }
    
    @Test(arguments: [
        "WithCompletionHandler": false,
        "WithAsyncKeyword": true,
        "DuplicateSymbolAsyncVariants": false,
        "DuplicateSymbolAsyncVariantsReverseOrder": false,
    ])
    func loadingAsyncSymbolsAsOnlySymbolGraphFile(symbolGraphFileName: String, shouldContainAsyncVariant: Bool) throws {
        let symbolGraphURL = try #require(Bundle.module.url(forResource: "\(symbolGraphFileName).symbols", withExtension: "json", subdirectory: "Test Resources"))
        var loader = try makeLoader {
            CopyOfFile(original: symbolGraphURL)
        }
        try loader.loadAll()
        
        let symbolGraph = try #require(loader.unifiedGraphs.values.first)
        
        #expect(symbolGraph.moduleName == "AsyncMethods")
        
        #expect(symbolGraph.symbols.count == 1, "Only one of the symbols should be decoded")
        let symbol = try #require(symbolGraph.symbols.values.first)
        let declaration = try #require(symbol.mixins.values.first?[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)
        
        #expect(shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
            fragment.kind == .keyword && fragment.spelling == "async"
        }), "\(symbolGraphFileName).symbols.json should\(shouldContainAsyncVariant ? "" : " not") contain an async keyword declaration fragment")
        
        #expect(!shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
            fragment.kind == .externalParameter && fragment.spelling == "completionHandler"
        }), "\(symbolGraphFileName).symbols.json should\(!shouldContainAsyncVariant ? "" : " not") contain a completionHandler parameter declaration fragment")
    }
    
    @Test(arguments: [
        "WithCompletionHandler": false,
        "WithAsyncKeyword": true,
        "DuplicateSymbolAsyncVariants": false,
        "DuplicateSymbolAsyncVariantsReverseOrder": false,
    ])
    func loadingAsyncSymbolsAlongsideAnotherSymbolGraphFile(symbolGraphFileName: String, shouldContainAsyncVariant: Bool) throws {
        // This tests the decoding behavior when the symbol graph loader is decoding more than one file
        
        let extraSymbolGraphFile = try #require(Bundle.module.url(forResource: "Asides.symbols", withExtension: "json", subdirectory: "Test Resources"))
        let symbolGraphURL       = try #require(Bundle.module.url(forResource: "\(symbolGraphFileName).symbols", withExtension: "json", subdirectory: "Test Resources"))
        var loader = try makeLoader {
            CopyOfFile(original: extraSymbolGraphFile)
            CopyOfFile(original: symbolGraphURL)
        }
        try loader.loadAll()
        
        #expect(loader.unifiedGraphs.values.contains(where: { $0.moduleName == "AsyncMethods" }))
        for symbolGraph in loader.unifiedGraphs.values where symbolGraph.moduleName == "AsyncMethods" {
            #expect(symbolGraph.symbols.count ==  1, "Only one of the symbols should be decoded")
            let symbol = try #require(symbolGraph.symbols.values.first)
            let declaration = try #require(symbol.mixins.values.first?[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)
            
            #expect(shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
                fragment.kind == .keyword && fragment.spelling == "async"
            }), "\(symbolGraphFileName).symbols.json should\(shouldContainAsyncVariant ? "" : " not") contain an async keyword declaration fragment")
            
            #expect(!shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
                fragment.kind == .externalParameter && fragment.spelling == "completionHandler"
            }), "\(symbolGraphFileName).symbols.json should\(!shouldContainAsyncVariant ? "" : " not") contain a completionHandler parameter declaration fragment")
        }
    }
    
    @Test
    func appliesTransformationToLoadedSymbolGraph() throws {
        // This test manually creates the loader so that it can pass the transformation parameter to the initializer
        let (fileSystem, folderURL) = try makeTestFileSystemWith {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName"))
        }
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: folderURL, allowArbitraryCatalogDirectories: true, options: .init())
        
        var loader = SymbolGraphLoader(bundle: inputs, dataProvider: dataProvider, shouldCreateOverloadGroups: false) { symbolGraph in
            // Make any verifiable change to the symbol graph
            symbolGraph.metadata.formatVersion = .init(major: 9, minor: 9, patch: 9)
        }
        try loader.loadAll()
        
        #expect(loader.unifiedGraphs.first?.value.metadata.first?.value.formatVersion.description == "9.9.9")
    }
    
    private func makeLoader(@FileBuilder content: () -> [any File]) throws -> SymbolGraphLoader {
        let (fileSystem, folderURL) = try makeTestFileSystemWith(content: content)
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: folderURL, allowArbitraryCatalogDirectories: true, options: .init())
        
        return SymbolGraphLoader(bundle: inputs, dataProvider: dataProvider, shouldCreateOverloadGroups: false)
    }
}
