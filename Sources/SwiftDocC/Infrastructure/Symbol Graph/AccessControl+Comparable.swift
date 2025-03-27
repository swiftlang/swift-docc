/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import SymbolKit

// Use fully-qualified types to silence a warning about retroactively conforming a type from another module to a new protocol (SE-0364).
// The `@retroactive` attribute is new in the Swift 6 compiler. The backwards compatible syntax for a retroactive conformance is fully-qualified types.
//
// SymbolKit doesn't define any access control values ("open", "public", "internal", "filePrivate", and "private", are defined in SwiftDocC).
// Because AccessControl only has a string raw value, it's unlikely that SymbolKit would add a Comparable conformance and default implementation.
extension SymbolKit.SymbolGraph.Symbol.AccessControl: Swift.Comparable {
    private var level: Int? {
        switch self {
        case .private : return 1
        case .filePrivate: return 2
        case .internal: return 3
        case .public: return 4
        case .open: return 5
        default:
            assertionFailure("Unknown AccessControl case was used in comparison.")
            return nil
        }
    }
    
    public static func < (lhs: SymbolGraph.Symbol.AccessControl, rhs: SymbolGraph.Symbol.AccessControl) -> Bool {
        guard let lhs = lhs.level,
              let rhs = rhs.level else {
            return false
        }
        return lhs < rhs
    }
}
