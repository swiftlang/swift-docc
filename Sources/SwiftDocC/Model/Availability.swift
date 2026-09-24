/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

/// The source-of-truth for the combined availability information for a given page.
///
/// This type is responsible for constructing the combined availability information from all relevant sources.
/// Use this type as the source-of-truth for "availability" related questions so that different callers have a consistent understanding of when a symbol is deprecated and is in beta.
///
/// ## Topics
///
/// ### Creation
///
/// Callers are expected to call these methods in order to aggregate availability information from different sources.
/// Failure to do so can result in unexpected results when accessing the combined availability information.
///
/// - ``init(defaultAvailability:)``
/// - ``markAllEncounteredPlatforms(in:)``
/// - ``addInSourceAvailability(from:matchingLanguage:)``
/// - ``addDirectiveAvailability(_:preservingBugOfFirstResettingAvailabilityTo:)``
/// - ``finalizePlatformFallbacks()``
///
/// ### Accessing information
///
/// After aggregating all the availability information, callers can access the final combined information.
///
/// - ``makePlatforms(_:)``
/// - ``isBeta(_:)``
/// - ``isDeprecated``
struct Availability {
    /// The availability information for all known platforms.
    private var knownPlatforms: [Information]
    /// The availability information for all custom platforms.
    private var customPlatformsByName: [/* Platform name */ String: Information]
    
    // NOTE: In its current state, this implementation does some strange looking things to preserve a number of bugs from the implementation that it replaces.
    // Each of these are called out with a code comment in the implementation and are isolated to make them easy to remove in the future.
    // The purpose of this is to preserve these behaviors as much as possible in the initial implementation, and remove them one by one in targeted follow-up fixes.
    
    // For future consideration: This type currently isn't responsible for the deprecation _message_ (from either a in-source attributes or a `@DeprecationSumary directive`).
    // It might be worth investigating bringing that responsibility here (because its availability adjacent and the presence of a `@DeprecationSumary` makes a page considered deprecated).
    
    // MARK: Default availability
    
    /// Creates a new availability container from the decoded "default" availability from the documentation catalog's Info.plist file.
    ///
    /// This "default" availability information applies as a baseline for everything in the module.
    /// By basing the per-page availability information on copies of this availability container,
    /// DocC only needs to compute it once per module instead of once per page.
    ///
    /// - Parameter defaultAvailability: The decoded "default" availability, or `nil` if the inputs don't specify any "default" availability.
    init(defaultAvailability: [DefaultAvailability.ModuleAvailability]?) {
        knownPlatforms = [Information](repeating: Information(state: .unavailable, source: .initialValue), count: KnownPlatform.wildcard.rawValue + 1 /* once for all known platforms */)
        customPlatformsByName = [String: Information]()
        
        // Fill in any provided default availability for both known platforms and custom platforms.
        guard let defaultAvailability else {
            return
        }
        for defaultInformation in defaultAvailability {
            let info = switch defaultInformation.versionInformation {
            case .available(let version):
                Information(
                    state: .available(introduced: version.flatMap { .init($0) }, deprecated: nil, isUnconditionallyDeprecated: false),
                    source: .defaultFromPropertyList
                )
            case .unavailable:
                Information(state: .unavailable, source: .markedUnavailableInPropertyList)
            }
            
            if let knownPlatform = KnownPlatform(defaultInformation.platformName) {
                knownPlatforms[knownPlatform] = info
            } else {
                customPlatformsByName[defaultInformation.platformName.displayName] = info
            }
        }
    }
    
    func preservingBugThatArticlesDoNotDisplayDefaultAvailability() -> Self {
        // !!!: Preserve the bug that articles don't display default availability (rdar://173688303)
        var copy = self
        for offset in 0 ..< KnownPlatform.wildcard.rawValue {
            if case .available = copy.knownPlatforms[offset].state {
                copy.knownPlatforms[offset] = .init(state: .unavailable, source: .initialValue)
            }
        }
        return copy
    }
    
    // MARK: Symbol information
    
    /// Updates the combined availability information by marking which platforms were encountered in the unified symbol graph.
    ///
    /// This information is used to identify symbols that are excluded through conditional compilation
    /// (by comparing the _symbol's_ encountered platforms to the unified graph's encountered platforms).
    ///
    /// This is its own method because this computation only needs to be performed once per module.
    /// Alternatively, if `addInSourceAvailability(from:languageFilter:)` was responsible for this task,
    /// then the caller couldn't forget to perform this task but it would have to performed once per symbol instead once per module.
    ///
    /// - Parameter unifiedGraph: The unified symbol graph to
    mutating func markAllEncounteredPlatforms(in unifiedGraph: UnifiedSymbolGraph) {
        for module in unifiedGraph.moduleData.values {
            guard let knownPlatform = KnownPlatform(module.platform) else {
                // We only care about tracking known values for symbol graph's platforms.
                continue
            }
            
            // Important:
            // By leaving the `state` as it was, the call to `addInSourceAvailability(...)` can preserve "default" availability
            // if the symbol is found in the graph but has no explicit in-source annotations that specify when it was introduced.
            knownPlatforms[knownPlatform].source = .havePlatformForInSymbolGraph
        }
    }
    
    // !!!: Preserve the bug iPadOS availability only fill when there's an introduced version or an iOS symbol graph (rdar://172280267)
    // The previous implementation had a quirk that iPadOS would only inherit iOS "fallback" information if either:
    // - The iOS information specified what version introduced the API
    // - The API was found in an symbol graph file for iOS.
    private var _canFillFallbackPlatformsWithoutIntroducedVersion = false
    
    /// Updates the combined availability information by adding information from in-source annotations.
    ///
    /// The caller should have called ``markAllEncounteredPlatforms(in:)`` before calling this method.
    ///
    /// - Parameters:
    ///   - unifiedSymbol: The symbol to read the unified in-source availability annotations from.
    ///   - languageFilter: The string identifier of a source language, that that container used to restrict the container to only add information that matches the provides  which information the container reads from the symbol.
    mutating func addInSourceAvailability(from unifiedSymbol: UnifiedSymbolGraph.Symbol, matchingLanguage languageFilter: String) {
        // Mark the platforms that this specific symbol exist for in the unified symbol graph.
        // Any platform that's left as `havePlatformForInSymbolGraph` after this loop indicates a platform that the symbol was excluded from using conditionally compilation.
        for selector in unifiedSymbol.allSelectors where selector.interfaceLanguage == languageFilter {
            guard let selectorPlatform = KnownPlatform(selector) else {
                continue
            }
            if knownPlatforms[selectorPlatform].source < .foundInSymbolGraph {
                knownPlatforms[selectorPlatform].source = .foundInSymbolGraph
                // Check that symbol doesn't have any "default" availability from the Info.plist before setting an empty "available" state
                if case .unavailable = knownPlatforms[selectorPlatform].state {
                    knownPlatforms[selectorPlatform].state = .available(introduced: nil, deprecated: nil, isUnconditionallyDeprecated: false)
                }
            }
            
            // !!!: Track that we've encountered a symbol graph for iOS to preserve the bug that iPadOS availability only fills when there's an introduced version or an iOS symbol graph (rdar://172280267)
            if selectorPlatform == .iOS {
                _canFillFallbackPlatformsWithoutIntroducedVersion = true
            }
        }
        
        // Add the information from all applicable in-source attributes.
        for (selector, availabilities) in unifiedSymbol.availability where selector.interfaceLanguage == languageFilter {
            let selectorPlatform = KnownPlatform(selector) // Don't `guard` this. It doesn't have to correspond to a known platform.
            
            for availability in availabilities {
                if let platform = KnownPlatform(availability.domain) {
                    // If DocC was passed symbol graphs for multiple platforms, prefer the in-source attribute that matches the current platform.
                    guard knownPlatforms[platform].source < .inSourceAttribute || platform == selectorPlatform else {
                        continue
                    }
                    knownPlatforms[platform] = if availability.isUnconditionallyUnavailable || availability.obsoletedVersion != nil {
                        .init(state: .unavailable, source: .inSourceAttribute)
                    } else {
                        .init(
                            state: .available(
                                // If the in-source attribute doesn't specify an introduced version, fall back to a possible value from the Info.plist
                                introduced: availability.introducedVersion.map { .init($0) } ?? knownPlatforms[platform].state.introduced,
                                deprecated: availability.deprecatedVersion.map { .init($0) }, // "Default" availability doesn't specify deprecated versions
                                isUnconditionallyDeprecated: availability.isUnconditionallyDeprecated),
                            source: .inSourceAttribute
                        )
                    }
                } else if let domainName = availability.domain?.rawValue {
                    customPlatformsByName[domainName] = if availability.isUnconditionallyUnavailable || availability.obsoletedVersion != nil {
                        .init(state: .unavailable, source: .inSourceAttribute)
                    } else {
                        .init(
                            state: .available(
                                // If the in-source attribute doesn't specify an introduced version, fall back to a possible value from the Info.plist
                                introduced: availability.introducedVersion.map { .init($0) } ?? customPlatformsByName[domainName]?.state.introduced,
                                deprecated: availability.deprecatedVersion.map { .init($0) }, // "Default" availability doesn't specify deprecated versions
                                isUnconditionallyDeprecated: availability.isUnconditionallyDeprecated),
                            source: .inSourceAttribute
                        )
                    }
                }
            }
        }
        
        // If "*" is unconditionally deprecated, reset all the found-in-symbol-graph platforms unless they have an introduced version from the Info.plist.
        if case .available(_, _, true) = knownPlatforms[.wildcard].state {
            for offset in 0 ..< KnownPlatform.wildcard.rawValue {
                let info = knownPlatforms[offset]
                guard info.source == .foundInSymbolGraph, !info.state.hasVersions else {
                    continue
                }
                
                knownPlatforms[offset] = .init(state: .unavailable, source: .initialValue)
            }
        }
    }
    
    // MARK: Directive availability
    
    /// Updates the combined availability information by adding information from `@Available` directives.
    ///
    /// If the availability relates to a symbol, the caller should have called ``addInSourceAvailability(for:)`` before calling this method.
    ///
    /// - Parameters:
    ///   - availableDirectives: A list of parsed `@Available` directives for this page.
    ///   - defaultAvailability: The container with only Info.plist "default" availability, to reset the container to to preserve the bug described in rdar://171807245.
    mutating func addDirectiveAvailability(
        _ availableDirectives: [Metadata.Availability],
        preservingBugOfFirstResettingAvailabilityTo defaultAvailability: Self
    ) {
        if !availableDirectives.isEmpty {
            // !!!: Preserve the bug that adding a single `@Available` directive causes a symbol to ignore all its in-source information but not its Info.plist "default" values (rdar://171807245)
            knownPlatforms = defaultAvailability.knownPlatforms
        }
        
        for directive in availableDirectives {
            let info = Information(
                state: .available(introduced: .init(directive.introduced), deprecated: directive.deprecated.map { .init($0) }, isUnconditionallyDeprecated: false),
                source: .directiveOverride
            )
            if let knownPlatform = KnownPlatform(directive.platform) {
                knownPlatforms[knownPlatform] = info
            } else {
                customPlatformsByName[directive.platform.rawValue] = info
            }
        }
    }
    
    // MARK: Finalize platforms fallbacks
    
    /// Finished computing the combined availability information by applying "fallback" behaviors for iPadOS and Mac Catalyst.
    mutating func finalizePlatformFallbacks() {
        let valueToCopy = knownPlatforms[.iOS]
        
        guard case .available(let introduced, let deprecated, let isUnconditionallyDeprecated) = valueToCopy.state,
              // Only apply "fallback" behaviors if iOS has either an introduced version, a deprecated version, or is unconditionally deprecated
              introduced != nil || deprecated != nil || isUnconditionallyDeprecated
        else {
            return
        }
        
        // !!!: Preserve the bug that "iPadOS" availability only fills from in-source availability when it either comes from the iOS symbol graph or when it has an introduced version (rdar://172280267)
        if valueToCopy.source == .inSourceAttribute {
            guard introduced != nil || _canFillFallbackPlatformsWithoutIntroducedVersion else {
                return
            }
        }
        
        let iOSHasVersions = introduced != nil || deprecated != nil
        
        func fillFallbackIfNeeded(for platform: KnownPlatform) {
            let otherInfo = knownPlatforms[platform]
            
            switch otherInfo.source {
                // If we have no information about the other platform (iPadOS or Catalyst), prefer any "fallback" value from iOS.
                case .initialValue:
                    knownPlatforms[platform] = valueToCopy
                
                // If the other platform (iPadOS or Catalyst) is available but we have more information about iOS, prefer the "fallback" information from iOS.
                case .defaultFromPropertyList, .foundInSymbolGraph:
                    if otherInfo.source < valueToCopy.source,
                       (iOSHasVersions || !otherInfo.state.hasVersions)
                    {
                        knownPlatforms[platform] = valueToCopy
                    }
                
                // If the information about the other platform (iPadOS or Catalyst) comes from an in-source annotation without any specific versions,
                // prefer the "fallback" information from iOS that has version information.
                case .inSourceAttribute:
                    if iOSHasVersions && otherInfo.state.isAvailableWithoutVersions
                    {
                        knownPlatforms[platform] = valueToCopy
                    }
                default:
                    break
            }
        }
        
        fillFallbackIfNeeded(for: .macCatalyst)
        fillFallbackIfNeeded(for: .iPadOS)
    }
    
    // MARK: Access the complete information
    
    /// An opaque type that represents a precomputed information regarding which platforms, both known and custom, are considered in beta.
    ///
    /// Pass this to ``Availability/makePlatforms(_:)`` to compute the final list of platforms and their aggregate information. 
    struct CurrentBetaPlatforms {
        fileprivate typealias Version = Information.Version
        fileprivate let knownBetaPlatforms:  [Int:    Version]
        fileprivate let customBetaPlatforms: [String: Version]
        
        init(currentPlatformVersions: [/* Platform name */ String: PlatformVersion]?) {
            guard let currentPlatformVersions else {
                self.knownBetaPlatforms  = [:]
                self.customBetaPlatforms = [:]
                return
            }
            
            var knownBetaPlatforms  = [Int:    Version]()
            var customBetaPlatforms = [String: Version]()
            for (name, version) in currentPlatformVersions where version.beta {
                let knownPlatform: KnownPlatform? = switch name.lowercased() {
                    case "ios":          .iOS
                    case "macos":        .macOS
                    case "mac catalyst": .macCatalyst
                    case "watchos":      .watchOS
                    case "tvos":         .tvOS
                    case "visionos":     .visionOS
                    default:             nil
                }
                let version = Version(version.version)
                if let knownPlatform  {
                    knownBetaPlatforms[knownPlatform.rawValue] = version
                } else {
                    customBetaPlatforms[name] = version
                }
            }
            
            // Add "fallback" information if iOS is in beta and we don't have specific information about iPadOS and/or Catalyst.
            if let iOSBetaVersion = knownBetaPlatforms[KnownPlatform.iOS.rawValue] {
                func fillInFallback(_ platform: KnownPlatform) {
                    if knownBetaPlatforms[platform.rawValue] == nil {
                        knownBetaPlatforms[platform.rawValue] = iOSBetaVersion
                    }
                }
                fillInFallback(.iPadOS)
                fillInFallback(.macCatalyst)
            }
            
            self.knownBetaPlatforms  = knownBetaPlatforms
            self.customBetaPlatforms = customBetaPlatforms
        }
    }
    
    /// The final combined availability information for a certain platform.
    struct Platform: Sendable {
        /// The name of the platform.
        var name: String
        /// The version when the API was first introduced for this platform, or `nil` if this API is available for all versions of the module.
        var introduced: SemanticVersion?
        /// The version when the API was first deprecated for this platform, or `nil` if this API isn't deprecated.
        var deprecated: SemanticVersion?
        /// Whether or not this API is unconditionally deprecated.
        var isUnconditionallyDeprecated: Bool
        /// Whether or not this API is considered to be in beta.
        var isBeta: Bool
    }
    
    
    ///
    ///
    /// - Parameter currentPlatform: The precomputed information regarding which platforms are considered in beta.
    /// - Returns: A list of the final combined availability information for a each platform, in an order that's suitable for display on the rendered page.
    func makePlatforms(_ currentPlatform: CurrentBetaPlatforms) -> [Platform] {
        // We don't want to display a list of _only_ platforms without version information.
        // If we have _some_ platforms with version information, or that come from "definite" sources of availability information,
        // then we want these versionless platforms to display but we don't want to display them if they're all there is.
        guard knownPlatforms.contains(where: { $0.state.hasVersions || $0.source != .foundInSymbolGraph && $0.source != .initialValue }) || !customPlatformsByName.isEmpty else {
            return []
        }
        
        var platforms = [Platform]()
        for (offset, info) in knownPlatforms.dropLast(/* don't display the wildcard */).enumerated() {
            switch info.source {
                case .initialValue, .markedUnavailableInPropertyList, .havePlatformForInSymbolGraph:
                    // Skip any information that's implicitly "unavailable" based on its source
                    continue
                
                case .defaultFromPropertyList, .foundInSymbolGraph, .inSourceAttribute, .directiveOverride:
                    if case .available(let introduced, let deprecated, let isUnconditionallyDeprecated) = info.state {
                        let isBeta: Bool = if let introduced, let betaVersion = currentPlatform.knownBetaPlatforms[offset] {
                            betaVersion <= introduced
                        } else {
                            false
                        }
                        
                        platforms.append(
                            Platform(
                                name: Self.knownPlatformNames[offset],
                                introduced: introduced?.semanticVersion,
                                deprecated: deprecated?.semanticVersion,
                                isUnconditionallyDeprecated: isUnconditionallyDeprecated,
                                isBeta: isBeta
                            )
                        )
                    }
            }
        }
        
        for (name, info) in customPlatformsByName.sorted(by: \.key) {
            if case .available(let introduced, let deprecated, let isUnconditionallyDeprecated) = info.state {
                let isBeta: Bool = if let introduced, let betaVersion = currentPlatform.customBetaPlatforms[name] {
                    betaVersion <= introduced
                } else {
                    false
                }
                
                platforms.append(
                    Platform(
                        name: name,
                        introduced: introduced?.semanticVersion,
                        deprecated: deprecated?.semanticVersion,
                        isUnconditionallyDeprecated: isUnconditionallyDeprecated,
                        isBeta: isBeta,
                    )
                )
            }
        }
        
        return platforms
    }
    
    /// The display names of all the known platforms, in order.
    private static let knownPlatformNames = [
        "iOS",          "iOS App Extension",
        "iPadOS",
        "Mac Catalyst", "Mac Catalyst App Extension",
        "macOS",        "macOS App Extension",
        "tvOS",         "tvOS App Extension",
        "visionOS",     "visionOS App Extension",
        "watchOS",      "watchOS App Extension",
    ]
    
    
    /// Determines whether or not a page as a whole is considered to be in beta given the .
    ///
    /// A page as a whole is considered to be in beta if all the platforms that the API is available for are currently in beta.
    ///
    /// - Parameter currentPlatform: The precomputed information regarding which platforms are considered in beta.
    func isBeta(_ currentPlatforms: CurrentBetaPlatforms) -> Bool {
        // The previous implementation didn't consider custom platforms when determining if a page is in beta.
        // It may be good to add that as a future improvement.
        
        guard !currentPlatforms.knownBetaPlatforms.isEmpty else {
            return false // Exit early if no platforms are currently in beta.
        }
        
        // If a page is unavailable on some platforms it doesn't count against its beta status,
        // but if the symbol is unavailable on "all" platforms it shouldn't be considered to be in beta.
        var foundBetaPlatforms = false
        
        for (offset, info) in knownPlatforms.enumerated() {
            switch info.source {
                case .initialValue, .markedUnavailableInPropertyList, .havePlatformForInSymbolGraph:
                    // Skip any information that's implicitly "unavailable" based on its source
                    continue
                
                case .defaultFromPropertyList, .foundInSymbolGraph, .directiveOverride:
                    // !!!: Preserve the bug that symbol's render references are only considered in-beta when the introduced version is from in-source attributes (rdar://173773442)
                    return false
                
                case .inSourceAttribute:
                    if case .available(let introduced, _, _) = info.state {
                        guard let introduced else {
                            // A symbol is not in considered in beta if it doesn't have a specific introduced _version_.
                            // Instead, it is assumed to have existed since the version version of that module.
                            return false
                        }
                        if let betaVersion = currentPlatforms.knownBetaPlatforms[offset], betaVersion <= introduced {
                            foundBetaPlatforms = true
                            continue
                        } else {
                            return false
                        }
                    }
            }
        }
        
        return foundBetaPlatforms
    }
    
    /// Determines whether or not a page as a whole is considered to be deprecated.
    ///
    /// A page as a whole is considered to be deprecated if the API is deprecated on all the platforms that the API is available for.
    var isDeprecated: Bool {
        return knownPlatforms.allSatisfy {
            switch $0.state {
                case .available(_, .some, _):
                    // !!!: Preserve the bug that directives don't mark pages as deprecated (rdar://173761647)
                    $0.source < .directiveOverride
                case .available(_, _, true): true
                case .unavailable:           true // Unavailable platforms don't count against a page's deprecated status
                case .available(_, nil, _):  false
            }
        }
    }
}

// MARK: Known platform

private extension Availability {
    // The availability container uses these raw values as indices, rather than string-based dictionary lookup for the very common case.
    enum KnownPlatform: Int {
        // Match the order that platforms display.
        // This removes the need to sort the known platform's availability for every page.
        
        // For future consideration: App extension platforms are fairly uncommon in practice but we currently always allocate space for them.
        // It might be worth investigating treating the app extension platforms as "custom" and adding extra logic in `makePlatforms(...)` to intersperse them with the main known platforms.
        case iOS,         iOSExtension
        case iPadOS
        case macCatalyst, macCatalystExtension
        case macOS,       macOSExtension
        case tvOS,        tvOSExtension
        case visionOS,    visionOSExtension
        case watchOS,     watchOSExtension
         
        case wildcard // Not included in the `makePlatforms(...)` output but used in the preceding calculations.
        
        // Identify a known platform for a decoded symbol graph's module.
        init?(_ platform: SymbolGraph.Platform) {
            switch platform.operatingSystem?.name.lowercased() {
                case "ios" where platform.environment == "macabi":
                                        self = .macCatalyst
                case "ios":             self = .iOS
                case "macos", "macosx": self = .macOS
                case "watchos":         self = .watchOS
                case "tvos":            self = .tvOS
                case "visionos":        self = .visionOS
                default:                return nil
            }
        }
        
        /// Identify a known platform from the unified symbol information.
        init?(_ selector: UnifiedSymbolGraph.Selector) {
            switch selector.platform?.lowercased() {
                case "ios":             self = .iOS
                case "macos", "macosx": self = .macOS
                case "maccatalyst":     self = .macCatalyst
                case "watchos":         self = .watchOS
                case "tvos":            self = .tvOS
                case "visionos":        self = .visionOS
                default:                return nil
            }
        }
        
        /// Identify a known platform from a decoded "default availability" item from the catalog's Info.plist file.
        init?(_ platformName: PlatformName) {
            switch platformName {
                case .iOS:      self = .iOS
                case .iPadOS:   self = .iPadOS
                case .macOS:    self = .macOS
                case .catalyst: self = .macCatalyst
                case .tvOS:     self = .tvOS
                case .watchOS:  self = .watchOS
                case .visionOS: self = .visionOS
                case .iOSAppExtension:        self = .iOSExtension
                case .macOSAppExtension:      self = .macOSExtension
                case .catalystOSAppExtension: self = .macCatalystExtension
                case .tvOSAppExtension:       self = .tvOSExtension
                case .watchOSAppExtension:    self = .watchOSExtension
                case .visionOSAppExtension:   self = .visionOSExtension
                
                default: return nil
            }
        }
        
        /// Identify a known platform from an in-source availability attribute
        init?(_ domain: SymbolGraph.Symbol.Availability.Domain?) {
            switch domain?.rawValue.lowercased() {
                case "ios":         self = .iOS
                // No iPadOS name
                case "macos":       self = .macOS
                case "maccatalyst": self = .macCatalyst
                case "tvos":        self = .tvOS
                case "watchos":     self = .watchOS
                case "visionos":    self = .visionOS
                // "*" is represented as a `nil` domain in SymbolKit.
                case nil:           self = .wildcard
                
                case "iosappextension":         self = .iOSExtension
                case "macosappextension":       self = .macOSExtension
                case "maccatalystappextension": self = .macCatalystExtension
                case "tvosappextension":        self = .tvOSExtension
                case "watchosappextension":     self = .watchOSExtension
                case "visionosappextension":    self = .visionOSExtension
                
                default: return nil
            }
        }
        
        /// Identify a known platform from a parsed `@Available` directive.
        init?(_ platform: Metadata.Availability.Platform) {
            switch platform {
                case .iOS:      self = .iOS
                // No iPadOS name
                case .macOS:    self = .macOS
                case .tvOS:     self = .tvOS
                case .watchOS:  self = .watchOS
                case .other("visionOS"):
                    self = .visionOS
                case .other("macCatalyst"), .other("Mac Catalyst"):
                    self = .macCatalyst
                default:
                    return nil
            }
        }
    }
}

private extension [Availability.Information] {
    // A convenience to allow `Availability` to access the information for its known platforms.
    subscript(platform: Availability.KnownPlatform) -> Availability.Information {
        get { self[platform.rawValue] }
        set { self[platform.rawValue] = newValue }
        _modify { yield &self[platform.rawValue] }
    }
}

// MARK: Information

private extension Availability {
    /// The primary storage of availability information for a page.
    struct Information {
        // For future consideration: This currently stores the available/unavailable information (`state`) separate from the `source`.
        // However, sources like `initialValue` and `markedUnavailableInPropertyList` can only be "unavailable".
        // Similarly, sources like `defaultFromPropertyList` and `directiveOverride` can only be "available".
        // It might be worth investigating combining these two pieces of data into a single value.
        
        var state: State
        var source: Source
        
        enum Source: Comparable {
            case initialValue
            case defaultFromPropertyList
            case markedUnavailableInPropertyList
            case havePlatformForInSymbolGraph
            case foundInSymbolGraph
            case inSourceAttribute
            case directiveOverride
        }
        
        enum State {
            case available(introduced: Version?, deprecated: Version?, isUnconditionallyDeprecated: Bool)
            case unavailable
            
            var hasVersions: Bool {
                switch self {
                    case .available(let introduced, let deprecated, _):
                        introduced != nil || deprecated != nil
                    case .unavailable:
                        false
                }
            }
            
            var isAvailableWithoutVersions: Bool {
                switch self {
                    case .available(let introduced, let deprecated, _):
                        introduced == nil && deprecated == nil
                    case .unavailable:
                        false
                }
            }
            
            var introduced: Version? {
                switch self {
                    case .available(let introduced, _, _): introduced
                    case .unavailable: nil
                }
            }
            
            var deprecated: Version? {
                switch self {
                    case .available(_, let deprecated, _,): deprecated
                    case .unavailable: nil
                }
            }
        }
    }
}

// MARK: Version

private extension Availability.Information {
    /// A compact version triplet that's used internally to the availability container.
    struct Version {
        // A full `SemanticVersion` is unnecessarily large (5 * 64 bits) for the little information that we need to compute availability.
        
        // This implementation currently uses 3 * 16 bits, allowing for 65 536 values per component ("major", "minor", and "patch").
        // It's very unlikely that a platform version number would exceed this for any of the components.
        // The one exception would be the various `API_TO_BE_DEPRECATED_*` constants are defined as 100 000.
        // DocC currently doesn't handle to-be-deprecated / "soft deprecation" information but this implementation clamps each component.
        // If we added support for displaying "soft deprecation" information, this implementation could likely identify it as `== UInt16.max`.
        //
        // Alternatively, we could switch to a UInt32 for the "major" component or we could pack the data so that "major" uses more bytes than the other components.

        private var major, minor, patch: UInt16
        
        /// Create a compact version triplet from a decoded "default availability" item's version string.
        init?(_ versionString: String) {
            var remaining = versionString.utf8[...]
            guard remaining.first?.isASCIINumber == true else {
                // Cannot parse a version triplet unless the first byte is an ASCII number (0-9).
                return nil
            }
            
            func scanNumber() -> UInt16 {
                var number: UInt = 0
                while remaining.first?.isASCIINumber == true {
                    number &*= 10
                    number &+= UInt(remaining.removeFirst() - UInt8(ascii: "0"))
                }
                return UInt16(clamping: number)
            }
            
            major = scanNumber()
            
            guard remaining.popFirst()?.isVersionComponentSeparator == true else {
                minor = 0
                patch = 0
                return
            }
            minor = scanNumber()
            
            guard remaining.popFirst()?.isVersionComponentSeparator == true else {
                patch = 0
                return
            }
            patch = scanNumber()
        }
        
        /// Create a compact version triplet from a `@Available` directive's version information.
        init(_ semanticVersion: SemanticVersion) {
            major = .init(clamping: semanticVersion.major)
            minor = .init(clamping: semanticVersion.minor)
            patch = .init(clamping: semanticVersion.patch)
        }
        
        /// Create a compact version triplet from an in-source availability attribute's version information.
        init(_ semanticVersion: SymbolGraph.SemanticVersion) {
            major = .init(clamping: semanticVersion.major)
            minor = .init(clamping: semanticVersion.minor)
            patch = .init(clamping: semanticVersion.patch)
        }
        
        /// Create a compact version triplet from an in-beta "current" platform that's provided via the command line.
        init(_ version: VersionTriplet) {
            major = .init(clamping: version.major)
            minor = .init(clamping: version.minor)
            patch = .init(clamping: version.patch)
        }
        
        ///
        var semanticVersion: SemanticVersion {
            .init(
                major: Int(major),
                minor: Int(minor),
                patch: Int(patch)
            )
        }
        
        // To determine if a platform is considered "in beta" we only need a less-than-or-equal comparison.
        // So far, the implementation doesn't need `Equatable` or `Comparable` conformance.
        static func <= (lhs: Self, rhs: Self) -> Bool {
            guard  lhs.major == rhs.major else { return lhs.major < rhs.major }
            guard  lhs.minor == rhs.minor else { return lhs.minor < rhs.minor }
            return lhs.patch <= rhs.patch
        }
    }
}

private extension UTF8.CodeUnit {
    var isASCIINumber: Bool {
        UInt8(ascii: "0") <= self && self <= UInt8(ascii: "9")
    }
    
    var isVersionComponentSeparator: Bool {
        self == UInt8(ascii: ".")
    }
}
