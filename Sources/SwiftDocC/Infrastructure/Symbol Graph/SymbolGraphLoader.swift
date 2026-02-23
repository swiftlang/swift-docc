/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
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

/// Loads symbol graph files from a documentation bundle.
///
/// A type that groups a bundle's symbol graphs by the module they describe,
/// which makes detecting symbol collisions and overloads easier.
struct SymbolGraphLoader {
    private(set) var symbolGraphs: [URL: SymbolKit.SymbolGraph] = [:]
    private(set) var snippetSymbolGraphs: [URL: SymbolKit.SymbolGraph] = [:]
    private(set) var unifiedGraphs: [String: SymbolKit.UnifiedSymbolGraph] = [:]
    private(set) var graphLocations: [String: [SymbolKit.GraphCollector.GraphKind]] = [:]
    private let dataProvider: any DataProvider
    private let bundle: DocumentationBundle
    private let symbolGraphTransformer: ((inout SymbolGraph) -> ())?
    
    /// Creates a new symbol graph loader
    /// - Parameters:
    ///   - bundle: The documentation bundle from which to load symbol graphs.
    ///   - dataProvider: A provider that the loader uses to read symbol graph data.
    ///   - symbolGraphTransformer: An optional closure that transforms the symbol graph after the loader decodes it.
    init(
        bundle: DocumentationBundle,
        dataProvider: any DataProvider,
        symbolGraphTransformer: ((inout SymbolGraph) -> ())? = nil
    ) {
        self.bundle = bundle
        self.dataProvider = dataProvider
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
                
                symbolGraphTransformer?(&symbolGraph)

                let (moduleName, isMainSymbolGraph) = Self.moduleNameFor(symbolGraph, at: symbolGraphURL)
                // If the bundle provides availability defaults add symbol availability data.
                self.addDefaultAvailability(to: &symbolGraph, moduleName: moduleName)

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
        
        let numberOfSymbolGraphs = bundle.symbolGraphURLs.count
        let decodeSignpostHandle = signposter.beginInterval("Decode symbol graphs", id: signposter.makeSignpostID(), "Decode \(numberOfSymbolGraphs) symbol graphs")
        switch decodingStrategy {
        case .concurrentlyAllFiles:
            // Concurrently load and decode all symbol graphs
            bundle.symbolGraphURLs.concurrentPerform(block: loadGraphAtURL)
            
        case .concurrentlyEachFileInBatches:
            // Serially load and decode all symbol graphs, each one in concurrent batches.
            bundle.symbolGraphURLs.forEach(loadGraphAtURL)
        }
        signposter.endInterval("Decode symbol graphs", decodeSignpostHandle)
        
        // define an appropriate merging strategy based on the graph formats
        let foundGraphUsingExtensionSymbolFormat = loadedGraphs.values.map(\.usesExtensionSymbolFormat).contains(true)
        
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
            createOverloadGroups: FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled
        )
        signposter.endInterval("Build unified symbol graph", mergeSignpostHandle)

        let availabilitySignpostHandle = signposter.beginInterval("Add missing availability", id: signposter.makeSignpostID())
        defer {
            signposter.endInterval("Add missing availability", availabilitySignpostHandle)
        }
        
        for var unifiedGraph in unifiedGraphs.values {
            var defaultUnavailablePlatforms = [PlatformName]()
            var defaultAvailableInformation = [DefaultAvailability.ModuleAvailability]()

            if let defaultAvailabilities = bundle.info.defaultAvailability?.modules[unifiedGraph.moduleName] {
                let (unavailablePlatforms, availablePlatforms) = defaultAvailabilities.categorize(where: { $0.versionInformation == .unavailable })
                defaultUnavailablePlatforms = unavailablePlatforms.map(\.platformName)
                defaultAvailableInformation = availablePlatforms
            }
            
            let platformsFoundInSymbolGraphs: [PlatformName] = unifiedGraph.moduleData.compactMap {
                guard let platformName = $0.value.platform.name else { return nil }
                return PlatformName(operatingSystemName: platformName)
            }

            addMissingAvailability(
                unifiedGraph: &unifiedGraph,
                unconditionallyUnavailablePlatformNames: defaultUnavailablePlatforms,
                registeredPlatforms: platformsFoundInSymbolGraphs,
                defaultAvailabilities: defaultAvailableInformation
            )
        }
    }
    
    // Alias to declutter code
    private typealias AvailabilityItem = SymbolGraph.Symbol.Availability.AvailabilityItem
    
    /// Adds the missing fallback and default availability information to the unified symbol graph
    /// in case it didn't exists in the loaded symbol graphs.
    private func addMissingAvailability(
        unifiedGraph: inout UnifiedSymbolGraph,
        unconditionallyUnavailablePlatformNames: [PlatformName],
        registeredPlatforms: [PlatformName],
        defaultAvailabilities: [DefaultAvailability.ModuleAvailability]
    ) {
        // The fallback platforms that are missing from the unified graph correspond to
        // the fallback platforms that have not been registered yet,
        // are not marked as unavailable,
        // and the corresponding inheritance platform has a SGF (has been registered).
        let missingFallbackPlatforms = DefaultAvailability.fallbackPlatforms.filter {
            !registeredPlatforms.contains($0.key) &&
            !unconditionallyUnavailablePlatformNames.contains($0.key) &&
            registeredPlatforms.contains($0.value)
        }
        // Platforms that are defined in the Info.plist that had no corresponding SGF
        // and are not being added as fallback of another platform.
        let missingAvailabilities = defaultAvailabilities.filter {
            !missingFallbackPlatforms.keys.contains($0.platformName) &&
            !registeredPlatforms.contains($0.platformName)
        }
        
        for symbol in unifiedGraph.symbols.values {
            for (selector, _) in symbol.mixins {
                if var symbolAvailability = (symbol.mixins[selector]?["availability"] as? SymbolGraph.Symbol.Availability) {
                    guard !symbolAvailability.availability.isEmpty else { continue }
                    // For platforms with a fallback option (e.g. Catalyst and iPadOS),
                    // if the availability is not explicitly available for the platform,
                    // apply the explicit availability annotation of the fallback platform.
                    for (platform, fallback) in DefaultAvailability.fallbackPlatforms {
                        guard var fallbackAvailability = symbolAvailability.availability.first(where: { $0.matches(fallback) }),
                              let platformAvailabilityIntroducedVersion = symbolAvailability.availability.first(where: { $0.matches(platform) })?.introducedVersion,
                              let defaultAvailabilityIntroducedVersion = defaultAvailabilities.first(where: { $0.platformName ==  platform })?.introducedVersion
                        else {
                            continue
                        }
                        // Ensure that the availability version is not overwritten if the symbol has an explicit availability annotation for that platform.
                        if SymbolGraph.SemanticVersion(string: defaultAvailabilityIntroducedVersion) == platformAvailabilityIntroducedVersion {
                            fallbackAvailability.domain = SymbolGraph.Symbol.Availability.Domain(rawValue: platform.rawValue)
                            symbolAvailability.availability.removeAll(where: {
                                $0.matches(platform)
                            })
                            symbolAvailability.availability.append(fallbackAvailability)
                        }
                    }
                    // Add fallback availability.
                    for (platform, fallback) in missingFallbackPlatforms {
                        if !symbolAvailability.contains(platform) {
                            for var fallbackAvailability in symbolAvailability.availability {
                                // Add the platform fallback to the availability mixin the platform is inheriting from.
                                // The added availability copies the entire availability information,
                                // including deprecated and obsolete versions.
                                if fallbackAvailability.matches(fallback) {
                                    fallbackAvailability.domain = SymbolGraph.Symbol.Availability.Domain(rawValue: platform.rawValue)
                                    symbolAvailability.availability.append(fallbackAvailability)
                                }
                            }
                        }
                    }
                    // Add the missing default platform availability.
                    for missingAvailability in missingAvailabilities where !symbolAvailability.contains(missingAvailability.platformName) {
                        if let defaultAvailability = AvailabilityItem(missingAvailability) {
                            symbolAvailability.availability.append(defaultAvailability)
                        }
                    }
                    symbol.mixins[selector]![SymbolGraph.Symbol.Availability.mixinKey] = symbolAvailability
                }
            }
        }
    }    

    /// If the bundle defines default availability for the symbols in the given symbol graph
    /// this method adds them to each of the symbols in the graph.
    private func addDefaultAvailability(to symbolGraph: inout SymbolGraph, moduleName: String) {
        // Check if there are defined default availabilities for the current module
        if let defaultAvailabilities = bundle.info.defaultAvailability?.modules[moduleName],
            let platformName = symbolGraph.module.platform.name.map(PlatformName.init) {

            // Prepare a default availability versions lookup for this module.
            let defaultAvailabilityVersionByPlatform = defaultAvailabilities
                .reduce(into: [PlatformName: SymbolGraph.SemanticVersion](), { result, defaultAvailability in
                    if let introducedVersion = defaultAvailability.introducedVersion, let version = SymbolGraph.SemanticVersion(string: introducedVersion) {
                        result[defaultAvailability.platformName] = version
                    }
                })
            
            // Map all symbols and add default availability for any missing platforms
            let symbolsWithFilledIntroducedVersions = symbolGraph.symbols.mapValues { symbol -> SymbolGraph.Symbol in
                var symbol = symbol
                let defaultModuleVersion = defaultAvailabilityVersionByPlatform[platformName]
                // The availability item for each symbol of the given module.
                let modulePlatformAvailabilityItem = AvailabilityItem(domain: SymbolGraph.Symbol.Availability.Domain(rawValue: platformName.rawValue), introducedVersion: defaultModuleVersion, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false)
                // Check if the symbol has existing availabilities from source
                var availability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability ?? SymbolGraph.Symbol.Availability(availability: [])
            
                // Fill introduced versions when missing.
                availability.availability = availability.availability.map {
                    let availabilityPlatformName = $0.domain.map { PlatformName(operatingSystemName: $0.rawValue) } ?? platformName
                    return $0.fillingMissingIntroducedVersion(
                        from: defaultAvailabilityVersionByPlatform,
                        fallbackPlatform: DefaultAvailability.fallbackPlatforms[availabilityPlatformName]?.rawValue
                    )
                }
                // Add the module availability information to each of the symbols availability mixin.
                if !availability.contains(platformName) {
                    availability.availability.append(modulePlatformAvailabilityItem)
                }
                symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] = availability
                
                return symbol
            }
            symbolGraph.symbols = symbolsWithFilledIntroducedVersions
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

    /**
     Fills lacking availability information with defaults, if available.
     
     If this item does not have an `introducedVersion`, attempt to fill it
     in from the `defaults`. If the defaults do not have a version for
     this item's domain/platform, also try the `fallbackPlatform`.

     - parameter defaults: Default module availabilities for each platform mentioned in a documentation bundle's `Info.plist`
     - parameter fallbackPlatform: An optional fallback platform name if this item's domain isn't found in the `defaults`.
     */
    func fillingMissingIntroducedVersion(from defaults: [PlatformName: SymbolGraph.SemanticVersion],
                                         fallbackPlatform: String?) -> SymbolGraph.Symbol.Availability.AvailabilityItem {
        // If this availability item doesn't have a domain, do nothing.
        guard let domain = self.domain else {
            return self
        }
        
        var newValue = self
        // To ensure the uniformity of platform availability names derived from SGFs,
        // we replace the original domain value with a value from the platform's name
        // since the platform name maps aliases to the canonical name.
        let platformName = PlatformName(operatingSystemName: domain.rawValue)
        newValue.domain = SymbolGraph.Symbol.Availability.Domain(rawValue: platformName.rawValue)

        // If a symbol is unconditionally unavailable for a given domain,
        // don't add an introduced version here as it may cause it to
        // incorrectly display availability information
        guard !isUnconditionallyUnavailable else {
            return newValue
        }

        // If this had an explicit introduced version from source, don't replace it.
        guard introducedVersion == nil else {
            return newValue
        }

        let fallbackPlatformName = fallbackPlatform.map(PlatformName.init(operatingSystemName:))
        
        // Try to find a default version string for this availability
        // item's platform (a.k.a. domain)
        guard let platformVersion = defaults[platformName] ??
            fallbackPlatformName.flatMap({ defaults[$0] }) else {
            return newValue
        }

        newValue.introducedVersion = platformVersion
        return newValue
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
