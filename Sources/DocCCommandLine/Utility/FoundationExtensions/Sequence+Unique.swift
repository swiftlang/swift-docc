/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Sequence {
    /// Returns a list of only the unique elements in a sequence, in the order they first appeared.
    ///
    /// - Parameter keyForValue: A closure that returns a key for each element in the sequence.
    /// - Returns: A list of all the unique elements, in the order they first appeared.
    func uniqueElements<Key: Hashable>(by keyForValue: (Element) -> Key) -> [Element] {
        var seen: Set<Key> = []
        var result: [Element] = []
        for element in self {
            let property = keyForValue(element)
            if !seen.contains(property) {
                result.append(element)
                seen.insert(property)
            }
        }
        return result
    }
}
