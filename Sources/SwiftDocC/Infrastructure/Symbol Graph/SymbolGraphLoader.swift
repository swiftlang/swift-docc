/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// Loads symbol graph files from a documentation bundle.
///
/// A type that groups a bundle's symbol graphs by the module they describe,
/// which makes detecting symbol collisions and overloads easier.
struct SymbolGraphLoader {
    private(set) var symbolGraphs: [URL: SymbolKit.SymbolGraph] = [:]
    private(set) var unifiedGraphs: [String: SymbolKit.UnifiedSymbolGraph] = [:]
    private(set) var graphLocations: [String: [SymbolKit.GraphCollector.GraphKind]] = [:]
    // FIXME: After 6.2, when we no longer have `DocumentationContextDataProvider` we can simply this code to not use a closure to read data.
    private var dataLoader: (URL, DocumentationBundle) throws -> Data
    private var bundle: DocumentationBundle
    private var symbolGraphTransformer: ((inout SymbolGraph) -> ())? = nil
    private var symbolsByPlatformRegisteredPerModule: [String: [String: [SymbolGraph.Symbol.Identifier]]] = [:]
    
    /// Creates a new symbol graph loader
    /// - Parameters:
    ///   - bundle: The documentation bundle from which to load symbol graphs.
    ///   - dataLoader: A closure that the loader uses to read symbol graph data.
    ///   - symbolGraphTransformer: An optional closure that transforms the symbol graph after the loader decodes it.
    init(
        bundle: DocumentationBundle,
        dataLoader: @escaping (URL, DocumentationBundle) throws -> Data,
        symbolGraphTransformer: ((inout SymbolGraph) -> ())? = nil
    ) {
        self.bundle = bundle
        self.dataLoader = dataLoader
        self.symbolGraphTransformer = symbolGraphTransformer
    }

    /// A strategy to decode symbol graphs.
    enum DecodingConcurrencyStrategy {
        /// Decode all symbol graph files on separate threads concurrently.
        case concurrentlyAllFiles
        /// Decode all symbol graph files sequentially, each one split into batches that are decoded concurrently.
        case concurrentlyEachFileInBatches
    }
    
    /// The symbol graph decoding strategy to use.
    private(set) var decodingStrategy: DecodingConcurrencyStrategy = .concurrentlyEachFileInBatches

    /// Loads all symbol graphs in the given bundle.
    ///
    /// - Throws: If loading and decoding any of the symbol graph files throws, this method re-throws one of the encountered errors.
    mutating func loadAll() throws {
        let loadingLock = Lock()

        var loadedGraphs = [URL: (usesExtensionSymbolFormat: Bool?, graph: SymbolKit.SymbolGraph)]()
        var loadError: Error?

        let loadGraphAtURL: (URL) -> Void = { [dataLoader, bundle] symbolGraphURL in
            // Bail out in case a symbol graph has already errored
            guard loadingLock.sync({ loadError == nil }) else { return }
            
            do {
                // Load and decode a single symbol graph file
                let data = try dataLoader(symbolGraphURL, bundle)

                var symbolGraph: SymbolGraph
                
                switch decodingStrategy {
                case .concurrentlyAllFiles:
                    symbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: data)
                case .concurrentlyEachFileInBatches:
                    symbolGraph = try SymbolGraphConcurrentDecoder.decode(data)
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
                
                // Store the decoded graph in `loadedGraphs`
                loadingLock.sync {
                    // Track the operating system platforms found in the symbol graphs of this module.
                    if let modulePlatform = symbolGraph.module.platform.name {
                        for symbol in symbolGraph.symbols.values {
                            symbolsByPlatformRegisteredPerModule[moduleName, default: [:]][modulePlatform, default: []].append(symbol.identifier)
                        }
                    }
                    // self.addDefaultAvailability(to: &symbolGraph, moduleName: moduleName)
                    loadedGraphs[symbolGraphURL] = (usesExtensionSymbolFormat, symbolGraph)
                }
            } catch {
                // If the symbol graph was invalid, store the error
                loadingLock.sync { loadError = error }
            }
        }
        
        // If we have symbol graph files for multiple platforms
        // load and decode each one on a separate thread.
        // This strategy benchmarks better when we have multiple
        // "larger" symbol graphs.
        #if os(macOS) || os(iOS)
        if bundle.symbolGraphURLs.filter({ !$0.lastPathComponent.contains("@") }).count > 1 {
            // There are multiple main symbol graphs, better parallelize all files decoding.
            decodingStrategy = .concurrentlyAllFiles
        }
        #endif
        
        switch decodingStrategy {
        case .concurrentlyAllFiles:
            // Concurrently load and decode all symbol graphs
            bundle.symbolGraphURLs.concurrentPerform(block: loadGraphAtURL)
            
        case .concurrentlyEachFileInBatches:
            // Serially load and decode all symbol graphs, each one in concurrent batches.
            bundle.symbolGraphURLs.forEach(loadGraphAtURL)
        }
        
        // define an appropriate merging strategy based on the graph formats
        let foundGraphUsingExtensionSymbolFormat = loadedGraphs.values.map(\.usesExtensionSymbolFormat).contains(true)
        
        let usingExtensionSymbolFormat = foundGraphUsingExtensionSymbolFormat
                
        let graphLoader = GraphCollector(extensionGraphAssociationStrategy: usingExtensionSymbolFormat ? .extendingGraph : .extendedGraph)
        
        // feed the loaded graphs into the `graphLoader`
        for (url, (_, graph)) in loadedGraphs {
            graphLoader.mergeSymbolGraph(graph, at: url)
        }
        
        // In case any of the symbol graphs errors, re-throw the error.
        // We will not process unexpected file formats.
        if let loadError {
            throw loadError
        }
        
        self.symbolGraphs = loadedGraphs.mapValues(\.graph)
        (self.unifiedGraphs, self.graphLocations) = graphLoader.finishLoading(
            createOverloadGroups: FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled
        )

        for var unifiedGraph in unifiedGraphs.values {
            var defaultUnavailablePlatforms = [PlatformName]()
            var defaultAvailableInformation = [DefaultAvailability.ModuleAvailability]()

            if let defaultAvailabilities = bundle.info.defaultAvailability?.modules[unifiedGraph.moduleName] {
                let (unavailablePlatforms, availablePlatforms) = defaultAvailabilities.categorize(where: { $0.versionInformation == .unavailable })
                defaultUnavailablePlatforms = unavailablePlatforms.map(\.platformName)
                defaultAvailableInformation = availablePlatforms
            }
            addMissingAvailability(
                unifiedGraph: &unifiedGraph,
                unconditionallyUnavailablePlatformNames: defaultUnavailablePlatforms,
                symbolsByPlatformName: symbolsByPlatformRegisteredPerModule[unifiedGraph.moduleName] ?? [:],
                defaultAvailabilities: defaultAvailableInformation
            )
        }
    }
    
    // Alias to declutter code
    typealias AvailabilityItem = SymbolGraph.Symbol.Availability.AvailabilityItem
    
    /// Cache default availability items as we create them on demand.
    private var cachedAvailabilityItems = [DefaultAvailability.ModuleAvailability: AvailabilityItem]()
    
    /// Returns a symbol graph availability item, given a module availability.
    /// - returns: An availability item, or `nil` if the input data is invalid.
    private func availabilityItem(for defaultAvailability: DefaultAvailability.ModuleAvailability) -> AvailabilityItem? {
        if let cached = cachedAvailabilityItems[defaultAvailability] {
            return cached
        }
        return AvailabilityItem(defaultAvailability)
    }
    
    private func loadSymbolGraph(at url: URL) throws -> (SymbolGraph, isMainSymbolGraph: Bool) {
        // This is a private method, the `url` key is known to exist
        var symbolGraph = symbolGraphs[url]!
        let (moduleName, isMainSymbolGraph) = Self.moduleNameFor(symbolGraph, at: url)
        
        if !isMainSymbolGraph && symbolGraph.module.bystanders == nil {
            // If this is an extending another module, change the module name to match the extended module.
            // This makes the symbols in this graph have a path that starts with the extended module's name.
            symbolGraph.module.name = moduleName
        }

        return (symbolGraph, isMainSymbolGraph)
    }

    
    /**
    Fills lacking availability information with fallback logic and default availability, if available.
     
    This method adds to every symbol the fallback availability items.
    After this, it adds the default availability information if the symbol is available in the given platform.
    
    - parameter unifiedGraph: The generated unified graph.
    - parameter unconditionallyUnavailablePlatformNames: Platforms to not add as synthesized availability items.
    - parameter symbolsByPlatformName: Symbols found in symbolgraph grouped by operating system platform name.
    - parameter defaultAvailabilities: The module default availabilities defined in the Info.plist.
    */
    private func addMissingAvailability(
        unifiedGraph: inout UnifiedSymbolGraph,
        unconditionallyUnavailablePlatformNames: [PlatformName],
        symbolsByPlatformName: [String: [SymbolGraph.Symbol.Identifier]],
        defaultAvailabilities: [DefaultAvailability.ModuleAvailability]
    ) {
        // The fallback platforms that are not marked as unavailable in the default availability.
        let fallbackPlatforms = DefaultAvailability.fallbackPlatforms.filter {
            !unconditionallyUnavailablePlatformNames.contains($0.key)
        }
        
        unifiedGraph.symbols.forEach { (symbolID, symbol) in
            // The platforms the symbol is available at grouped by interface language.
            var platformsAvailableByLanguage: [String: Set<String?>] = [:]
            for (selector, _) in symbol.mixins {
                for item in symbol.availability[selector] ?? [] where item.introducedVersion != nil {
                    platformsAvailableByLanguage[selector.interfaceLanguage, default: []].insert(item.domain?.rawValue)
                }
            }
            // Add fallback availability.
            for (selector, mixins) in symbol.mixins {
        
                // Platforms available for the given symbol in the given language variant.
                var platformsAvailable = platformsAvailableByLanguage[selector.interfaceLanguage] ?? []

                // The symbol availability for the given selector.
                var symbolAvailability = mixins.getValueIfPresent(for: SymbolGraph.Symbol.Availability.self)?.availability ?? []
                
                // Add availability of platforms with an inherited platform (e.g iOS and iPadOS).
                if !symbolAvailability.isEmpty {
                    fallbackPlatforms.forEach { (fallbackPlatform, inheritedPlatform) in
                        // The availability item the fallbak platform fallbacks from.
                        guard var inheritedAvailability = symbolAvailability.first(where: {
                                $0.matches(inheritedPlatform)
                        }) else {
                            return
                        }
                        // Check that the symbol does not have an explicit availability annotation for the fallback platform already.
                        if !platformsAvailable.contains(fallbackPlatform.rawValue) {
                            // Check that the symbol does not have some availability information for the fallback platform.
                            // If it does adds the introduced version from the inherited availability item.
                            if let availabilityForFallbackPlatformIdx = symbolAvailability.firstIndex(where: {
                                $0.domain?.rawValue == fallbackPlatform.rawValue
                            }) {
                                if symbolAvailability[availabilityForFallbackPlatformIdx].isUnconditionallyUnavailable {
                                    return
                                }
                                symbolAvailability[availabilityForFallbackPlatformIdx].introducedVersion = inheritedAvailability.introducedVersion
                                return
                            }
                            // The symbols does not contains any information for the fallback platform
                            inheritedAvailability.domain = SymbolGraph.Symbol.Availability.Domain(rawValue: fallbackPlatform.rawValue)
                            inheritedAvailability.deprecatedVersion = inheritedAvailability.deprecatedVersion
                            symbolAvailability.append(inheritedAvailability)
                            if inheritedAvailability.introducedVersion != nil {
                                platformsAvailable.insert(fallbackPlatform.rawValue)
                            }
                        }
                    }
                }
                
                // Add the module default availability information.
                defaultAvailabilities.forEach { defaultAvailability in
                    
                    // Check that if there was a symbolgraph for this platform, the symbol was present on it,
                    // if not it means that the symbol is not available for the default platform.
                    guard symbolsByPlatformName[defaultAvailability.platformName.rawValue]?.contains(where: {
                        symbolID == $0.precise
                    }) != false else {
                        return
                    }
                    
                    // Check that the symbol does not has explicit availability for this platform already.
                    if !platformsAvailable.contains(defaultAvailability.platformName.rawValue) {
                        // If the  missing availability corresponds to a fallback platform, and there's default availability for the platform that this one fallbacks from, don't add it.
                        if let fallbackPlatform = fallbackPlatforms.first(where: { $0.key == defaultAvailability.platformName }), platformsAvailable.contains(fallbackPlatform.value.rawValue) {
                            return
                        }
                        guard var defaultAvailabilityItem = AvailabilityItem(defaultAvailability) else { return }
                        
                        // Check if the symbol already has this availability item.
                        if let idx = symbolAvailability.firstIndex(where: {
                            $0.domain?.rawValue == defaultAvailability.platformName.rawValue
                        }) {
                            // If the symbol is marked as unavailable don't add the default availability.
                            if symbolAvailability[idx].isUnconditionallyUnavailable || (symbolAvailability[idx].obsoletedVersion != nil) {
                                return
                            }
                            defaultAvailabilityItem.deprecatedVersion = symbolAvailability[idx].deprecatedVersion
                            defaultAvailabilityItem.isUnconditionallyDeprecated = symbolAvailability[idx].isUnconditionallyDeprecated
                            symbolAvailability.remove(at: idx)
                        }
                        symbolAvailability.append(defaultAvailabilityItem)
                        
                        // If the default availability has fallback platforms, add them now.
                        for (fallbackPlatform, inheritedPlatform) in fallbackPlatforms {
                            // Check that the fallback platform has not been added already to the symbol,
                            // and that it does not has it's own default availability information.
                            if (
                                inheritedPlatform == defaultAvailability.platformName &&
                                !platformsAvailable.contains(fallbackPlatform.rawValue) &&
                                !defaultAvailabilities.contains(where: {$0.platformName.rawValue == fallbackPlatform.rawValue})
                            ) {
                                defaultAvailabilityItem.domain =  SymbolGraph.Symbol.Availability.Domain(rawValue: fallbackPlatform.rawValue)
                                symbolAvailability.append(defaultAvailabilityItem)
                            }
                        }
                    }
                }
                symbol.mixins[selector]![SymbolGraph.Symbol.Availability.mixinKey] = SymbolGraph.Symbol.Availability(availability: symbolAvailability)
            }
        }
    }
    
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

extension SymbolGraph.Symbol.Availability.AvailabilityItem {
    /// Create an availability item with a `domain` and an `introduced` version.
    /// - parameter defaultAvailability: Default availability information for symbols that lack availability authored in code.
    /// - Note: If the `defaultAvailability` argument has a introduced version that can't
    /// be parsed as a `SemanticVersion`, returns `nil`.
    init?(_ defaultAvailability: DefaultAvailability.ModuleAvailability) {
        let introducedVersion = defaultAvailability.introducedVersion
        let platformVersion = introducedVersion.flatMap { SymbolGraph.SemanticVersion(string: $0) }
        if platformVersion == nil && introducedVersion != nil {
            return nil
        }
        let domain = SymbolGraph.Symbol.Availability.Domain(rawValue: defaultAvailability.platformName.rawValue)
        self.init(domain: domain,
                  introducedVersion: platformVersion,
                  deprecatedVersion: nil,
                  obsoletedVersion: nil,
                  message: nil,
                  renamed: nil,
                  isUnconditionallyDeprecated: false,
                  isUnconditionallyUnavailable: false,
                  willEventuallyBeDeprecated: false)
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
