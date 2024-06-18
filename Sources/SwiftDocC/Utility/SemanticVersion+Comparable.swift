/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// If SymbolKit adds Comparable conformance it's reasonable to expect that its behavior would be compatible.
//
// If a future SymbolKit implementation considers the "prerelease" and "buildMetadata" components _after_ the
// "major", "minor", and "patch" components, that remains compatible with the behavior that SwiftDocC expects.
extension SymbolGraph.SemanticVersion: @retroactive Comparable {
    /// Compares two semantic versions.
    public static func < (lhs: SymbolGraph.SemanticVersion, rhs: SymbolGraph.SemanticVersion) -> Bool {
        return (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
