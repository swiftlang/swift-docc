/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// Use fully-qualified types to silence a warning about retroactively conforming a type from another module to a new protocol (SE-0364).
// The `@retroactive` attribute is new in the Swift 6 compiler. The backwards compatible syntax for a retroactive conformance is fully-qualified types.
//
// If SymbolKit adds Comparable conformance it's reasonable to expect that its behavior would be compatible.
//
// As long as a hypothetical future SymbolKit implementation considers "major", "minor", and "patch" before comparing the "prerelease" and "buildMetadata"
// components, the behavior will remain compatible with what SwiftDocC expects.
extension SymbolKit.SymbolGraph.SemanticVersion: Swift.Comparable {
    /// Compares two semantic versions.
    public static func < (lhs: SymbolGraph.SemanticVersion, rhs: SymbolGraph.SemanticVersion) -> Bool {
        return (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
