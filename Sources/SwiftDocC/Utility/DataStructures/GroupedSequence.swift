/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A sequence that groups its elements to optimize accesses.
///
/// You use a grouped sequence when you need efficient access to its elements via a grouping mechanism of your
/// choosing and you aren't concerned with the order of the elements in the sequence.
///
/// ```swift
/// var groupedSequence = GroupedSequence<Int, String> { $0.count }
/// groupedSequence.append("a")
/// groupedSequence.append(contentsOf: ["aa", "aaa"])
///
/// print(groupedSequence[1])
/// // Prints ["a"]
///
/// print(groupedSequence[2])
/// // Prints ["aa"]
/// ```
///
/// You can iterate through a grouped sequence's unordered elements.
///
/// ```swift
/// for item in groupedSequence {
///     print(item)
/// }
///
/// // Prints "aa"
/// // Prints "a"
/// // Prints "aaa"
/// ```
struct GroupedSequence<Key: Hashable, Element>: Sequence, CustomStringConvertible {
    fileprivate var storage = [Key: Element]()
    
    /// A closure that transforms an element into its key.
    private var deriveKey: (Element) -> Key
    
    var description: String {
        storage.values.description
    }
    
    /// Creates an empty grouped sequence.
    init(deriveKey: @escaping (Element) -> Key) {
        self.deriveKey = deriveKey
    }
   
    /// Adds an element to the group sequence.
    ///
    /// If an element with the same derived key was appended before, it will be replaced with the new element.
    mutating func append(_ element: Element) {
        storage[deriveKey(element)] = element
    }
    
    /// Adds the contents of a sequence to the group sequence.
    ///
    /// Existing elements with the same derived key will be replaced with the new element.
    mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == Element {
        for element in newElements {
            append(element)
        }
    }
    
    /// Accesses the member using the given key.
    subscript(key: Key) -> Element? {
        get {
            storage[key]
        }
    }
    
    /// Returns an iterator over the members of the sequence.
    func makeIterator() -> Dictionary<Key, Element>.Values.Iterator {
        storage.values.makeIterator()
    }
}

extension Array {
    /// Creates an array given a grouped sequence.
    init<Key>(_ groupedSequence: GroupedSequence<Key, Element>) {
        self = Array(groupedSequence.storage.values)
    }
}
