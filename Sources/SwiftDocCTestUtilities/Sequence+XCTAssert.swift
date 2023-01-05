/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import XCTest

/// Performs assertions on the elements contained in the given `sequence`.
///
/// - Parameters:
///     - sequence: The elements the `assertions` are performed on
///     - key: The identifier used to determine which assertion is to be run on an element
///     - assertions: A number of assertion functions, which take an element from the sequence as their input and are keyed by an element's `key`
///     - allowUnusedAssertions: If enabled, this function does not fail if an assertion remained unused after processing the whole `sequence`
///     - allowOtherContent: If disabled, this function fails if an element's key could not be matched to an assertion
public func XCTAssertElements<K, S>(in sequence: S,
                                    keyedBy key: KeyPath<S.Element, K>,
                                    using assertions: [K: (S.Element) throws -> Void],
                                    allowUnusedAssertions: Bool = false,
                                    allowOtherContent: Bool = true) throws where K: Hashable, S: Sequence {
    var assertionWasUsed: [K: Bool] = [:]
    for element in sequence {
        if let assertion = assertions[element[keyPath: key]] {
            try assertion(element)
            assertionWasUsed[element[keyPath: key]] = true
        } else if !allowOtherContent {
            XCTFail("The given sequence contained an element keyed '\(element[keyPath: key])', but no assertion was given for that key.")
        }
    }
    
    if !allowUnusedAssertions {
        for key in assertions.keys {
            XCTAssertEqual(assertionWasUsed[key], true, "No element in the given 'sequence' used the key '\(key)'")
        }
    }
}
