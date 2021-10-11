/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension SymbolGraph.SemanticVersion {
    enum Precision: Int {
        case all = 0, patch, minor
        
        fileprivate var componentsToRemove: Int {
            switch self {
            case .minor:
                return 1
            case .all, .patch:
                return 0
            }
        }
    }
    
    /// Renders a lossless version string up to a given component precision.
    ///
    /// In case there are non-zero components after the `precisionUpToNonsignificant` index
    /// this method will still include them in the returned version string. For example:
    ///  - "1.2.0" rendered with .patch precision returns "1.2.0"
    ///  - "1.2.0" rendered with .minor precision returns "1.2"
    ///  - but "1.2.3" rendered with .minor precision returns "1.2.3";
    ///    the patch component is included to prevent data loss.
    /// - Parameter precision: A ``Precision`` index of the least-significant component to include.
    /// - Returns: A rendered version string.
    func stringRepresentation(precisionUpToNonsignificant precision: Precision = .all) -> String {
        let components = [major, minor, patch]
        let lastIndex = components.count - 1
        let lastNonZeroIndex = components.lastIndex(where: { $0>0 }) ?? 0
        let renderUpToIndex = max(lastIndex - precision.componentsToRemove, lastNonZeroIndex)
        return components[0...renderUpToIndex]
            .map { "\($0)" }
            .joined(separator: ".")
    }
    
    /// Compares a version triplet to a semantic version.
    /// - Parameter version: A version triplet to compare to this semantic version.
    /// - Returns: Returns whether the given triple represents the same version as the current version.
    func isEqualToVersionTriplet(_ version: VersionTriplet) -> Bool {
        return major == version.major &&
            minor == version.minor &&
            patch == version.patch
    }
}

/// Availability information of a symbol on a specific platform.
public struct AvailabilityRenderItem: Codable, Hashable, Equatable {
    /// The name of the platform on which the symbol is available.
    public var name: String?
    
    /// The version of the platform SDK introducing the symbol.
    public var introduced: String?
    
    /// The version of the platform SDK deprecating the symbol.
    public var deprecated: String?
    
    /// The version of the platform SDK marking the symbol as obsolete.
    public var obsoleted: String?
    
    /// A message associated with the availability of the symbol.
    ///
    /// Use this property to provide a deprecation reason or instructions how to
    /// update code that uses this symbol.
    public var message: String?
    
    /// The new name of the symbol, if it was renamed.
    public var renamed: String?
    
    /// If `true`, the symbol is deprecated on this or all platforms.
    public var unconditionallyDeprecated: Bool?
    
    /// If `true`, the symbol is unavailable on this or all platforms.
    public var unconditionallyUnavailable: Bool?
    
    /// If `true`, the symbol is introduced in a beta version of this platform.
    public var isBeta: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case name, introducedAt, deprecatedAt, obsoletedAt, message, renamed, deprecated, unavailable
        case beta
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        introduced = try container.decodeIfPresent(String.self, forKey: .introducedAt)
        deprecated = try container.decodeIfPresent(String.self, forKey: .deprecatedAt)
        obsoleted = try container.decodeIfPresent(String.self, forKey: .obsoletedAt)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        renamed = try container.decodeIfPresent(String.self, forKey: .renamed)
        unconditionallyDeprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
        unconditionallyUnavailable = try container.decodeIfPresent(Bool.self, forKey: .unavailable)
        isBeta = try container.decodeIfPresent(Bool.self, forKey: .beta)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(introduced, forKey: .introducedAt)
        try container.encodeIfPresent(deprecated, forKey: .deprecatedAt)
        try container.encodeIfPresent(obsoleted, forKey: .obsoletedAt)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(renamed, forKey: .renamed)
        try container.encodeIfPresent(unconditionallyDeprecated, forKey: .deprecated)
        try container.encodeIfPresent(unconditionallyUnavailable, forKey: .unavailable)
        try container.encodeIfPresent(isBeta, forKey: .beta)
    }
    
    /// Creates a new availability item with the given parameters.
    /// - Parameter availability: The symbol-graph availability item.
    /// - Parameter current: The target platform version, if available.
    init(_ availability: SymbolGraph.Symbol.Availability.AvailabilityItem, current: PlatformVersion?) {
        let platformName = availability.domain.map({ PlatformName(operatingSystemName: $0.rawValue) })
        name = platformName?.displayName
        introduced = availability.introducedVersion?.stringRepresentation(precisionUpToNonsignificant: .minor)
        deprecated = availability.deprecatedVersion?.stringRepresentation(precisionUpToNonsignificant: .minor)
        obsoleted = availability.obsoletedVersion?.stringRepresentation(precisionUpToNonsignificant: .minor)
        message = availability.message
        renamed = availability.renamed
        unconditionallyUnavailable = availability.isUnconditionallyUnavailable
        unconditionallyDeprecated = availability.isUnconditionallyDeprecated
        
        if let introducedVersion = availability.introducedVersion, let current = current, current.beta, introducedVersion.isEqualToVersionTriplet(current.version) {
            isBeta = true
        } else {
            isBeta = false
        }
    }
    
    /// Creates a new item with the given platform name and version string.
    /// - Parameters:
    ///   - name: A platform name.
    ///   - introduced: A version string.
    ///   - isBeta: If `true`, the symbol is introduced in a beta version of the platform.
    init(name: String, introduced: String, isBeta: Bool) {
        self.name = name
        self.introduced = introduced
        self.isBeta = isBeta
    }
}
