/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
private import DocCCommon

#if canImport(os)
private import os
#endif

/// Loads symbol graph files from a collection of documentation inputs.
///
/// A type that groups an inputs' symbol graphs by the module they describe,
/// which makes detecting symbol collisions and overloads easier.
struct SymbolGraphLoader {
    private(set) var symbolGraphs: [URL: SymbolKit.SymbolGraph] = [:]
    private(set) var snippetSymbolGraphs: [URL: SymbolKit.SymbolGraph] = [:]
    private(set) var unifiedGraphs: [String: SymbolKit.UnifiedSymbolGraph] = [:]
    private(set) var graphLocations: [String: [SymbolKit.GraphCollector.GraphKind]] = [:]
    private(set) var platformsFoundInSymbolGraphsByModule: [String: Set<PlatformName>] = [:]
    private let dataProvider: any DataProvider
    private let inputs: DocumentationContext.Inputs
    private let symbolGraphTransformer: ((inout SymbolGraph) -> ())?
    private let shouldCreateOverloadGroups: Bool
    
    /// Creates a new symbol graph loader
    /// - Parameters:
    ///   - inputs: The collection of build inputs that lists the symbol graphs for the loader.
    ///   - dataProvider: A provider that the loader uses to read symbol graph data.
    ///   - shouldCreateOverloadGroups: Whether or not experimental support for combining overloaded symbol pages is enabled.
    ///   - symbolGraphTransformer: An optional closure that transforms the symbol graph after the loader decodes it.
    init(
        inputs: DocumentationContext.Inputs,
        dataProvider: any DataProvider,
        shouldCreateOverloadGroups: Bool,
        symbolGraphTransformer: ((inout SymbolGraph) -> ())? = nil
    ) {
        self.inputs = inputs
        self.dataProvider = dataProvider
        self.symbolGraphTransformer = symbolGraphTransformer
        self.shouldCreateOverloadGroups = shouldCreateOverloadGroups
    }

    /// Loads all symbol graphs in the given inputs.
    ///
    /// - Throws: If loading and decoding any of the symbol graph files throws, this method re-throws one of the encountered errors.
    mutating func loadAll() throws {
        let signposter = ConvertActionConverter.signposter
        
        let loadingLock = Lock()

        var loadedGraphs = [URL: (usesExtensionSymbolFormat: Bool?, isSnippetGraph: Bool, graph: SymbolKit.SymbolGraph)]()
        var loadError: (any Error)?

        let loadGraphAtURL: (URL) -> Void = { [dataProvider] symbolGraphURL in
            // Bail out in case a symbol graph has already errored
            guard loadingLock.sync({ loadError == nil }) else { return }
            
            do {
                // Load and decode a single symbol graph file
                let data = try dataProvider.contents(of: symbolGraphURL)

                var symbolGraph: SymbolGraph = try FastSymbolGraphJSONDecoder.decode(SymbolGraph.self, from: data)

                // Clang can sometimes erroneously emit anonymous structs and unions without a title in the symbol graph.
                // This typically occurs for anonymous types nested within public types, making them technically public
                // but functionally private since they cannot be referenced in any way by any consumers of that header.
                // This causes issues in a few different places for DocC:
                //
                // - Their pages can't be navigated to because their URL path end with a leading slash.
                //   The corresponding static hosting 'index.html' copy also overrides the container's index.html file because
                //   its file path has two slashes, for example "/documentation/ModuleName/ContainerName//index.html".
                // - In cases where the symbol is top-level, its URL path conflicts with the root page of the framework,
                //   leading to incorrect content being rendered.
                //
                // In order to avoid these issues, symbols without valid non-empty path components are dropped.
                let droppedIDs = symbolGraph.symbols.compactMap { $0.value.pathComponents.contains("") ? $0.key : nil }
                if !droppedIDs.isEmpty {
                    for id in droppedIDs { symbolGraph.symbols.removeValue(forKey: id) }
                    symbolGraph.relationships.removeAll { droppedIDs.contains($0.source) || droppedIDs.contains($0.target) }
                }

                symbolGraphTransformer?(&symbolGraph)

                let (moduleName, isMainSymbolGraph) = Self.moduleNameFor(symbolGraph, at: symbolGraphURL)

                // main symbol graphs are ambiguous
                var usesExtensionSymbolFormat: Bool? = nil
                
                // transform extension block based structure emitted by the compiler to a
                // custom structure where all extensions to the same type are collected in
                // one extended type symbol
                if !isMainSymbolGraph {
                    let containsExtensionSymbols = try ExtendedTypeFormatTransformation.transformExtensionBlockFormatToExtendedTypeFormat(&symbolGraph, moduleName: moduleName)
                    
                    // empty symbol graphs are ambiguous (but shouldn't exist)
                    usesExtensionSymbolFormat = symbolGraph.symbols.isEmpty ? nil : containsExtensionSymbols
                }
                
                // If the graph doesn't have any symbols we treat it as a regular, but empty, graph.
                //                                                   v
                let isSnippetGraph = symbolGraph.symbols.values.first?.kind.identifier.isSnippetKind == true
                
                // Store the decoded graph in `loadedGraphs`
                loadingLock.sync {
                    loadedGraphs[symbolGraphURL] = (usesExtensionSymbolFormat, isSnippetGraph, symbolGraph)
                }
            } catch {
                // If the symbol graph was invalid, store the error
                loadingLock.sync { loadError = error }
            }
        }
        
        let numberOfSymbolGraphs = inputs.symbolGraphURLs.count
        let decodeSignpostHandle = signposter.beginInterval("Decode symbol graphs", id: signposter.makeSignpostID(), "Decode \(numberOfSymbolGraphs) symbol graphs")
        inputs.symbolGraphURLs.concurrentPerform(block: loadGraphAtURL)
        signposter.endInterval("Decode symbol graphs", decodeSignpostHandle)
        
        // define an appropriate merging strategy based on the graph formats
        let foundGraphUsingExtensionSymbolFormat = loadedGraphs.values.contains { $0.usesExtensionSymbolFormat == true }
        
        let usingExtensionSymbolFormat = foundGraphUsingExtensionSymbolFormat
        
        let mergeSignpostHandle = signposter.beginInterval("Build unified symbol graph", id: signposter.makeSignpostID())
        let graphLoader = GraphCollector(extensionGraphAssociationStrategy: usingExtensionSymbolFormat ? .extendingGraph : .extendedGraph)
        
        
        // feed the loaded non-snippet graphs into the `graphLoader`
        for (url, (_, isSnippets, graph)) in loadedGraphs where !isSnippets {
            graphLoader.mergeSymbolGraph(graph, at: url)
        }
        
        // In case any of the symbol graphs errors, re-throw the error.
        // We will not process unexpected file formats.
        if let loadError {
            throw loadError
        }
        
        self.symbolGraphs        = loadedGraphs.compactMapValues({ _, isSnippets, graph in isSnippets ? nil   : graph })
        self.snippetSymbolGraphs = loadedGraphs.compactMapValues({ _, isSnippets, graph in isSnippets ? graph : nil   })
        (self.unifiedGraphs, self.graphLocations) = graphLoader.finishLoading(
            createOverloadGroups: shouldCreateOverloadGroups
        )
        signposter.endInterval("Build unified symbol graph", mergeSignpostHandle)
    }
    
    // Alias to declutter code
    private typealias AvailabilityItem = SymbolGraph.Symbol.Availability.AvailabilityItem
    
    
    /// Returns the module name, if any, in the file name of a given symbol-graph URL.
    ///
    /// Returns "Combine", if it's a main symbol-graph file, such as "Combine.symbols.json".
    /// Returns "Swift", if it's an extension file such as, "Combine@Swift.symbols.json".
    /// - parameter url: A URL to a symbol graph file.
    /// - returns: A module name, or `nil` if the file name cannot be parsed.
    static func moduleNameFor(_ url: URL) -> String? {
        let fileName = url.lastPathComponent.components(separatedBy: ".symbols.json")[0]

        let fileNameComponents = fileName.components(separatedBy: "@")
        if fileNameComponents.count > 2 {
            // Two "@"s found in the name - it's a cross import symbol graph:
            // "Framework1@Framework2@_Framework1_Framework2.symbols.json"
            return fileNameComponents[0]
        }
        
        return fileName.split(separator: "@", maxSplits: 1).last.map({ String($0) })
    }
    
    /// Returns the module name of a symbol graph based on the JSON data and file name.
    ///
    /// Useful during decoding the symbol graphs to implement the correct name logic starting with the module name in the JSON.
    private static func moduleNameFor(_ symbolGraph: SymbolGraph, at url: URL) -> (String, Bool) {
        let isMainSymbolGraph = !url.lastPathComponent.contains("@")
        
        let moduleName: String
        if isMainSymbolGraph || symbolGraph.module.bystanders != nil {
            // For main symbol graphs, get the module name from the symbol graph's data

            // When bystander modules are present, the symbol graph is a cross-import overlay, and
            // we need to preserve the original module name to properly render it. It is still
            // kept with the extension symbols, due to the merging behavior of UnifiedSymbolGraph.
            moduleName = symbolGraph.module.name
        } else {
            // For extension symbol graphs, derive the extended module's name from the file name.
            //
            // The per-symbol `extendedModule` value is the same as the main module for most symbols, so it's not a good way to find the name
            // of the module that was extended (rdar://63200368).
            moduleName = SymbolGraphLoader.moduleNameFor(url)!
        }
        return (moduleName, isMainSymbolGraph)
    }
}

extension SymbolGraph.SemanticVersion {
    /// Creates a new semantic version from the given string. 
    ///
    /// Returns `nil` if the string doesn't contain 1, 2, or 3 numeric components separated by periods.
    /// - parameter string: A version number as a string.
    init?(string: String) {
        let componentStrings = string.components(separatedBy: ".")
        let components = componentStrings.compactMap(Int.init)

        // Check that all components parsed to an `Int` successfully.
        guard components.count == componentStrings.count else {
            return nil
        }

        // Check that there is at least one component but no more than three
        guard (1...3).contains(components.count) else {
            return nil
        }

        var componentIterator = components.makeIterator()

        self.init(major: componentIterator.next()!,
                  minor: componentIterator.next() ?? 0,
                  patch: componentIterator.next() ?? 0)
    }
}

private extension SymbolGraph.Symbol.Availability {
    func contains(_ platform: PlatformName) -> Bool {
        availability.contains(where: { $0.matches(platform) })
    }
}

private extension SymbolGraph.Symbol.Availability.AvailabilityItem {
    func matches(_ platform: PlatformName) -> Bool {
        domain?.rawValue.lowercased() == platform.rawValue.lowercased()
    }
}

extension SymbolGraph.Symbol.KindIdentifier {
    var isSnippetKind: Bool {
        self == .snippet || self == .snippetGroup
    }
}
