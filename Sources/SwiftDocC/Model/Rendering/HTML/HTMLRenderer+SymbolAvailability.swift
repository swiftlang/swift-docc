/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension Symbol {
    /// A Boolean value that indicates whether HTML pages display this symbol as deprecated.
    ///
    /// This is derived from the same platforms as the page's availability list, so that the page's status tag can't contradict the list.
    ///
    /// A symbol displays as deprecated if it has a deprecation summary,
    /// or if its first language representation is deprecated on all the platforms it's available on.
    func isDisplayedAsDeprecated(_ currentBetaPlatforms: Availability.CurrentBetaPlatforms) -> Bool {
        if deprecatedSummary != nil { return true }
        guard let availability = consolidatedAvailability.firstValue else {
            return false
        }
        if availability.isUnconditionallyDeprecatedOnAllPlatforms { return true }
        guard let platforms = availability.makePlatforms(currentBetaPlatforms), !platforms.isEmpty else {
            return false
        }
        return platforms.allSatisfy { $0.isUnconditionallyDeprecated || $0.deprecated != nil }
    }

    /// A Boolean value that indicates whether HTML pages display this symbol as beta.
    ///
    /// This is derived from the same platforms as the page's availability list, so that the page's status tag can't contradict the list.
    ///
    /// A symbol displays as beta if its first language representation is beta on all the platforms that it's available on.
    func isDisplayedAsBeta(_ currentBetaPlatforms: Availability.CurrentBetaPlatforms) -> Bool {
        guard let platforms = consolidatedAvailability.firstValue?.makePlatforms(currentBetaPlatforms), !platforms.isEmpty else {
            return false
        }
        return platforms.allSatisfy(\.isBeta)
    }
}
