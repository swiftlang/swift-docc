/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension Sequence {
    /// Splits a sequence into a list of matching elements and a list of non-matching elements.
    ///
    /// - Parameter matches: A closure that takes an element of the sequence as its argument and returns a `Result` value indicating whether the element should be included in the matching list.
    /// - Returns: A pair of the matching elements and the remaining elements, that didn't match.
    func categorize<Result>(where matches: (Element) -> Result?) -> (matching: [Result], remainder: [Element]) {
        var matching = [Result]()
        var remainder = [Element]()
        for element in self {
            if let matchingResult = matches(element) {
                matching.append(matchingResult)
            } else {
                remainder.append(element)
            }
        }
        return (matching, remainder)
    }

    /// Splits a sequence into a list of elements that satisfy a given predicate and a list of those that don't.
    ///
    /// - Parameter isIncluded: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included in the matching list.
    /// - Returns: A path of the the elements that satisfied the predicate and those that didn't.
    func categorize(where isIncluded: (Element) -> Bool) -> (matching: [Element], remainder: [Element]) {
        return (filter(isIncluded), filter { !isIncluded($0) })
    }
}
