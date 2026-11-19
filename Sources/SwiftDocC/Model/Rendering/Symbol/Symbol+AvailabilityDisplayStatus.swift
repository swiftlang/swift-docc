/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension Symbol {
    /// A Boolean value that indicates whether pages and references display this symbol as deprecated.
    ///
    /// A symbol displays as deprecated if it has a deprecation summary,
    /// or if any of its language representations is deprecated on all the platforms that it's available on.
    func isDisplayedAsDeprecated() -> Bool {
        consolidatedAvailability.allValues.contains { $1.isDeprecated } || deprecatedSummary != nil
    }
    
    /// A Boolean value that indicates whether pages and references display this symbol as beta.
    ///
    /// A symbol displays as beta if it any of its language representations is beta on all the platforms that it's available on.
    func isDisplayedAsBeta(_ currentBetaPlatforms: Availability.CurrentBetaPlatforms) -> Bool {
        consolidatedAvailability.allValues.contains { $1.isBeta(currentBetaPlatforms) }
    }
}
