/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Sequence {
    /// Maps the sequence using the given closure and returns the first non-nil value.
    ///
    /// This behaves as a combination of `first(where:)` and `map(:_)` where the predicate and the mapping closure perform the same transformation.
    ///
    /// This function is both lazy, stopping once it finds a non-nil value, and only applies the transformation to an element once. This is especially useful when
    /// the transformation is slow or expensive to perform:
    ///
    /// ```swift
    /// let html = identifiers.mapFirst(where: { id in
    ///   guard let result = lookupPageWithID(id).fetchMarkup() else {
    ///     return nil
    ///   }
    ///   return result.html
    /// })
    /// ```
    ///
    /// - Parameter predicate: A mapping closure that accepts an element of this sequence as its parameter and returns a transformed value or `nil`.
    /// - Throws: Any error that's raised by the mapping closure.
    /// - Returns: The first mapped, non-nil value, or `nil` if the mapping closure returned `nil` for every value in the sequence.
    func mapFirst<T>(where predicate: (Element) throws -> T?) rethrows -> T? {
        for element in self {
            if let result = try predicate(element) {
                return result
            }
        }
        return nil
    }
}
