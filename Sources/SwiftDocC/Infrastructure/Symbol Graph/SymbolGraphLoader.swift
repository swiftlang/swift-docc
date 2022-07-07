/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
    private var dataProvider: DocumentationContextDataProvider
    private var bundle: DocumentationBundle
    
    /// Creates a new loader, initialized with the given bundle.
    /// - Parameters:
    ///   - bundle: The documentation bundle from which to load symbol graphs.
    ///   - dataProvider: A data provider in the bundle's context.
    init(bundle: DocumentationBundle, dataProvider: DocumentationContextDataProvider) {
        self.bundle = bundle
        self.dataProvider = dataProvider
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
    /// - Parameter decoder: A potentially customized `JSONDecoder` to be used for decoding. This decoder is only
    /// used if the `decodingStrategy` is set to `concurrentlyAllFiles`!
    /// - Throws: If loading and decoding any of the symbol graph files throws, this method re-throws one of the encountered errors.
    mutating func loadAll(using decoder: JSONDecoder = JSONDecoder()) throws {
        let loadingLock = Lock()

        var loadedGraphs = [URL: (usesExtensionSymbolFormat: Bool?, graph: SymbolKit.SymbolGraph)]()
        var loadError: Error?
        let bundle = self.bundle
        let dataProvider = self.dataProvider
        
        let loadGraphAtURL: (URL) -> Void = { symbolGraphURL in
            // Bail out in case a symbol graph has already errored
            guard loadError == nil else { return }
            
            do {
                // Load and decode a single symbol graph file
                let data = try dataProvider.contentsOfURL(symbolGraphURL, in: bundle)
                
                var symbolGraph: SymbolGraph
                
                switch decodingStrategy {
                case .concurrentlyAllFiles:
                    symbolGraph = try decoder.decode(SymbolGraph.self, from: data)
                case .concurrentlyEachFileInBatches:
                    symbolGraph = try SymbolGraphConcurrentDecoder.decode(data, using: decoder)
                }

                // `moduleNameFor(_:at:)` is static because it's pure function.
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
                
                // Store the decoded graph in `loadedGraphs`
                loadingLock.sync {
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
        if bundle.symbolGraphURLs.filter({ !$0.path.contains("@") }).count > 1 {
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
        let foundGraphNotUsingExtensionSymbolFormat = loadedGraphs.values.map(\.usesExtensionSymbolFormat).contains(false)
        
        guard !foundGraphUsingExtensionSymbolFormat || !foundGraphNotUsingExtensionSymbolFormat else {
            let usingExtensionSymbolFormat = loadedGraphs.filter { (_, value) in
                guard let usesExtensionSymbolFormat = value.usesExtensionSymbolFormat else {
                    return false
                }
                return usesExtensionSymbolFormat
            }.map(\.key)
            
            let notUsingExtensionSymbolFormat = loadedGraphs.filter { (_, value) in
                guard let usesExtensionSymbolFormat = value.usesExtensionSymbolFormat else {
                    return false
                }
                return !usesExtensionSymbolFormat
            }.map(\.key)
            
            throw LoadingError.mixedGraphFormats(usingExtensionSymbolFormat, notUsingExtensionSymbolFormat)
        }
        
        let usingExtensionSymbolFormat = foundGraphUsingExtensionSymbolFormat
                
        let graphLoader = GraphCollector(extensionGraphAssociationStrategy: usingExtensionSymbolFormat ? .extendingGraph : .extendedGraph)
        
        // feed the loaded graphs into the `graphLoader`
        for (url, (_, graph)) in loadedGraphs {
            graphLoader.mergeSymbolGraph(graph, at: url)
        }
        
        // In case any of the symbol graphs errors, re-throw the error.
        // We will not process unexpected file formats.
        if let loadError = loadError {
            throw loadError
        }
        
        self.symbolGraphs = loadedGraphs.mapValues(\.graph)
        (self.unifiedGraphs, self.graphLocations) = graphLoader.finishLoading()
    }
    
    private enum LoadingError: DescribedError {
        case mixedGraphFormats([URL], [URL])
        
        var errorDescription: String {
            switch self {
            case let .mixedGraphFormats(usingExtensionSymbolFormat, notUsingExtensionSymbolFormat):
                return """
                Mixing symbol graph files with and without extension declarations is not supported.
                
                Symbol graph files with extension declarations:
                \(usingExtensionSymbolFormat.map(\.absoluteString).joined(separator: "\n"))
                Symbol graph files without extension declarations:
                \(notUsingExtensionSymbolFormat.map(\.absoluteString).joined(separator: "\n"))
                """
            }
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
            // If this is an extending another module, change the module name to match the exteneded module.
            // This makes the symbols in this graph have a path that starts with the extended module's name.
            symbolGraph.module.name = moduleName
        }

        return (symbolGraph, isMainSymbolGraph)
    }

    /// If the bundle defines default availability for the symbols in the given symbol graph
    /// this method adds them to each of the symbols in the graph.
    private func addDefaultAvailability(to symbolGraph: inout SymbolGraph, moduleName: String) {
        // Check if there are defined default availabilities for the current module
        if let defaultAvailabilities = bundle.info.defaultAvailability?.modules[moduleName],
            let platformName = symbolGraph.module.platform.name.map(PlatformName.init) {
            
            // Prepare a default availability lookup for this module.
            let defaultAvailabilityIndex = defaultAvailabilities
                .reduce(into: [DefaultAvailability.ModuleAvailability: AvailabilityItem](), { result, defaultAvailability in
                    result[defaultAvailability] = AvailabilityItem(defaultAvailability)
                })
            
            // Prepare a default availability versions lookup for this module.
            let defaultAvailabilityVersionByPlatform = defaultAvailabilities
                .reduce(into: [PlatformName: SymbolGraph.SemanticVersion](), { result, defaultAvailability in
                    if let version = SymbolGraph.SemanticVersion(string: defaultAvailability.platformVersion) {
                        result[defaultAvailability.platformName] = version
                    }
                })
            
            // In the case of Mac Catalyst use default availability for the iOS platform if annotated
            let fallbackPlatform = (platformName == .catalyst) ? PlatformName.iOS.displayName : nil
            
            // `true` if this module has Mac Catalyst availability.
            let isDefaultCatalystAvailabilitySet = defaultAvailabilities.contains(where: { $0.platformName == .catalyst })

            // Map all symbols and add default availability for any missing platforms
            let symbolsWithFilledIntroducedVersions = symbolGraph.symbols.mapValues { symbol -> SymbolGraph.Symbol in
                var symbol = symbol
                
                // Check if the symbol has existing availabilities from source
                if var availability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability {

                    // Fill introduced versions when missing.
                    var newAvailabilityItems = availability.availability.map {
                        $0.fillingMissingIntroducedVersion(from: defaultAvailabilityVersionByPlatform, fallbackPlatform: fallbackPlatform)
                    }
                    
                    // When Catalyst is missing, fall back on iOS availability.

                    // First check if we're targeting the Mac Catalyst platform
                    if isDefaultCatalystAvailabilitySet,
                        // Then verify annotated availability from source for Mac Catalyst is missing
                       !newAvailabilityItems.contains(where: { $0.domain?.rawValue == SymbolGraph.Symbol.Availability.Domain.macCatalyst }),
                        // And finally fetch the symbol's iOS availability if there is one
                        let iOSAvailability = newAvailabilityItems.first(where: { $0.domain?.rawValue == SymbolGraph.Symbol.Availability.Domain.iOS }) {
                        
                        var macCatalystAvailability = iOSAvailability
                        macCatalystAvailability.domain = SymbolGraph.Symbol.Availability.Domain(rawValue: SymbolGraph.Symbol.Availability.Domain.macCatalyst)
                        newAvailabilityItems.append(macCatalystAvailability)
                    }

                    // If a symbol doesn't have any availability annotation at all
                    // for a given platform, create a new one just with the
                    // introduced version so that it shows up in the sidebar.
                    for defaultAvailability in defaultAvailabilities {
                        let hasAvailabilityForThisPlatform = newAvailabilityItems.contains {
                            guard let domain = $0.domain else { return false }
                            return PlatformName(operatingSystemName: domain.rawValue) == defaultAvailability.platformName
                        }
                        if !hasAvailabilityForThisPlatform {
                            // Safe to force unwrap below, the index contains all the avaialbility keys.
                            newAvailabilityItems.append(defaultAvailabilityIndex[defaultAvailability]!)
                        }
                    }

                    availability.availability = newAvailabilityItems
                    symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] = availability
                }
                return symbol
            }
            symbolGraph.symbols = symbolsWithFilledIntroducedVersions
        }
    }
    
    /// Returns the module name, if any, in the file name of a given symbol-graph URL.
    ///
    /// Returns "Combine", if it's a main symbol-graph file, such as "Combine.symbols.json".
    ///  Returns "Swift", if it's an extension file such as, "Combine@Swift.symbols.json".
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
    /// - Note: If the `defaultAvailability` argument doesn't have a valid
    /// platform version that can be parsed as a `SemanticVersion`, returns `nil`.
    init?(_ defaultAvailability: DefaultAvailability.ModuleAvailability) {
        guard let platformVersion = SymbolGraph.SemanticVersion(string: defaultAvailability.platformVersion) else {
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
     For example, `macCatalyst` should fall back to `iOS` because `macCatalyst` symbols are originally `iOS` symbols.
     */
    func fillingMissingIntroducedVersion(from defaults: [PlatformName: SymbolGraph.SemanticVersion],
                                         fallbackPlatform: String?) -> SymbolGraph.Symbol.Availability.AvailabilityItem {
        // If this availability item doesn't have a domain, do nothing.
        guard let domain = self.domain else {
            return self
        }

        // If a symbol is unconditionally unavailable for a given domain,
        // don't add an introduced version here as it may cause it to
        // incorrectly display availability information
        guard !isUnconditionallyUnavailable else {
            return self
        }

        // If this had an explicit introduced version from source, don't replace it.
        guard introducedVersion == nil else {
            return self
        }

        let platformName = PlatformName(operatingSystemName: domain.rawValue)
        let fallbackPlatformName = fallbackPlatform.map(PlatformName.init(operatingSystemName:))
        
        // Try to find a default version string for this availability
        // item's platform (a.k.a. domain)
        guard let platformVersion = defaults[platformName] ??
            fallbackPlatformName.flatMap({ defaults[$0] }) else {
            return self
        }

        var newValue = self
        newValue.introducedVersion = platformVersion
        return newValue
    }
}
