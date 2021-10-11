/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A set of functions to order rendering availability items.
enum AvailabilityRenderOrder {
    
    /// Auto-generated order index based on ``PlatformName.sortedPlatforms``.
    static let platformsOrder: [String: Int] = PlatformName.sortedPlatforms
        .enumerated()
        .reduce(into: [String: Int]()) { result, element in
            result[element.element.displayName] = element.offset
        }
    
    /// Sort two availability render items based on their platform name.
    static func compare(lhs: AvailabilityRenderItem, rhs: AvailabilityRenderItem) -> Bool {
        guard let lhsName = lhs.name, let rhsName = rhs.name else { return false }
        return platformsOrder[lhsName, default: Int.max] < platformsOrder[rhsName, default: Int.max]
    }
}
