/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension SymbolGraph.Symbol.Availability {
    /// Filters out all the availability items that don't apply to the given platform.
    ///
    /// - Parameter platformName: The platform name to filter availability items for.
    /// - Returns: A new `Availability` with only the items that apply to `platformName`.
    func filterItems(thatApplyTo platformName: PlatformName) -> SymbolGraph.Symbol.Availability {
        var copy = self
        copy.availability = availability.filter { $0.appliesTo(platformName) }
        return copy
    }
}
    
private extension SymbolGraph.Symbol.Availability.AvailabilityItem {
    /// Returns `true` if the `AvailabilityItem` applies to a given platform.
    ///
    /// - Parameter platformName: The platform name to check if the item applies to.
    /// - Returns: If the item applies to the platform or not.
    func appliesTo(_ platformName: PlatformName) -> Bool {
        if let domain = domain {
            return PlatformName(operatingSystemName: domain.rawValue) == platformName
        } else {
            // Items without a domain apply to all platforms
            return true
        }
    }
}
