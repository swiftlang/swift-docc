/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that parses symbol-graph availability and provides convenient access to specific information.
struct AvailabilityParser {
    /// The availability to parse.
    let availability: SymbolGraph.Symbol.Availability
    /// Creates a new availability parser for a given symbol-graph availability.
    /// - Parameter availability: The availability to parse.
    init(_ availability: SymbolGraph.Symbol.Availability) {
        self.availability = availability
    }
    
    /// Determines whether the symbol is deprecated, either for a given platform or for all platforms.
    ///
    /// - Parameter platform: The platform to check. Pass `nil` to check if the symbol is deprecated on all platforms.
    /// - Returns: Whether or not the symbol is deprecated.
    func isDeprecated(platform: String? = nil) -> Bool {
        guard !availability.availability.isEmpty else { return false }
        
        // Check if a specific platform is deprecated
        if let platform = platform {
            return availability.availability.contains(where: { return $0.domain?.rawValue == platform && ( $0.isUnconditionallyDeprecated || $0.deprecatedVersion != nil ) })
        }
        
        // Check if there's a "universal deprecation" in the listing
        if availability.availability.contains(where: { $0.domain == nil && ($0.isUnconditionallyDeprecated || $0.isUnconditionallyUnavailable) }) {
            return true
        }
        
        // Check if the symbol is unconditionally deprecated
        return availability.availability
            .allSatisfy { $0.isUnconditionallyDeprecated || $0.isUnconditionallyUnavailable || $0.deprecatedVersion != nil }
    }
    
    /// Determines a symbol's deprecation message that either applies to a given platform or that applies to all platforms.
    ///
    /// - Parameter platform: The platform for which to determine the deprecation message, or `nil` for all platforms.
    /// - Returns: The deprecation message for this platform, or `nil` if the symbol is not deprecated or doesn't have a deprecation message.
    func deprecationMessage(platform: String? = nil) -> String? {
        guard !availability.availability.isEmpty else { return nil }
        
        if let platform = platform {
            return availability.availability.mapFirst {
                guard $0.domain?.rawValue == platform && ( $0.isUnconditionallyDeprecated || $0.deprecatedVersion != nil ) else {
                    return nil
                }
                return $0.message
            }
        }
        
        // Check if there's a "universal deprecation" in the listing
        if let message = availability.availability.mapFirst(where: { item -> String? in
            guard item.domain == nil && (item.isUnconditionallyDeprecated || item.isUnconditionallyUnavailable) else { return nil }
            return item.message
        }) {
            return message
        }
        
        if availability.availability.allSatisfy({ $0.isUnconditionallyDeprecated || $0.isUnconditionallyUnavailable || $0.deprecatedVersion != nil }) {
            return availability.availability.mapFirst { item -> String? in
                guard item.isUnconditionallyDeprecated || (item.deprecatedVersion != nil) else { return nil }
                return item.message
            }
        }
        
        return nil
    }
}
