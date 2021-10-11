/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension RangeReplaceableCollection {
    /// Groups successive elements as long as check determines that they belong together.
    ///
    /// - Parameter belongsInGroupWithPrevious: A check whether the given element belongs in the same group as the previous element
    /// - Returns: An array of subsequences of elements that belong together.
    func group(asLongAs belongsInGroupWithPrevious: (_ previous: Element, _ current: Element) throws -> Bool) rethrows -> [SubSequence] {
        var result = [SubSequence]()
        
        let indexPairs = zip(indices, indices.dropFirst())
        var splitStart = startIndex
        for (previous, current) in indexPairs where try !belongsInGroupWithPrevious(self[previous], self[current]) {
            result.append(self[splitStart...previous])
            splitStart = current
        }
        result.append(self[splitStart...])
        return result
    }
    
}
