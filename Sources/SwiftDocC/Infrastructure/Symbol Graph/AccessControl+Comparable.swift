/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension SymbolGraph.Symbol.AccessControl: Comparable {
    private var level: Int? {
        switch self {
        case .private:
            return 0
        case .filePrivate:
            return 1
        case .internal:
            return 2
        case .public:
            return 3
        case .open:
            return 4
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
