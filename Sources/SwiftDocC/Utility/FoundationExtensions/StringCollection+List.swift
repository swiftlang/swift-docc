/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A conjunction in a grammatical list.
enum Conjunction: String {
    /// "or"
    case or
    
    /// "and"
    case and
}

extension BidirectionalCollection where Element: CustomStringConvertible {
    /**
     Returns this collection of elements separated by commas, terminating with `finalConjunction`.
     
     For example, for the array `[1,2,3]`, will return "1, 2, or 3" or "1, 2, and 3".
     */
    func list(finalConjunction: Conjunction) -> String {
        switch count {
        case 0:
            return ""
        case 1:
            return "\(self.first!)"
        case 2:
            let firstIndex = startIndex
            let secondIndex = index(after: firstIndex)
            return "\(self[firstIndex]) \(finalConjunction) \(self[secondIndex])"
        default:
            let prefix = self.prefix(self.count - 1).map { $0.description }.joined(separator: ", ")
            return "\(prefix), \(finalConjunction.rawValue) \(self.last!.description)"
        }
    }
}
