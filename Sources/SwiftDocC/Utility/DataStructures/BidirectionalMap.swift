/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A bi-directional dictionary to store 1:1 relationships that need to be looked up
/// in both directions.
///
/// This type is basically a wrapper around two dictionaries not allowing the relationships in
/// the two dictionaries to get out of sync.
/// - warning: Do not use optional types for `Value1` and `Value2`. Do not use the same type for `Value1` and `Value2`.
struct BidirectionalMap<Value1: Hashable, Value2: Hashable>: Sequence {
    private var forward = [Value1: Value2]()
    private var reverse = [Value2: Value1]()

    private static func set<Key: Hashable, Value: Hashable>(key: Key, newValue: Value, forward: inout [Key: Value], reverse: inout [Value: Key]) {
        // If updating, first remove the reverse relationship
        if let reverseKey = forward[key] {
            reverse.removeValue(forKey: reverseKey)
        }
        // Update both dictionaries with the new 1:1
        forward[key] = newValue
        reverse[newValue] = key
    }
    
    /// Returns a `Value2` for a given key `Value1`.
    subscript(key: Value1) -> Value2? {
      get {
        return forward[key]
      }

      set (newValue) {
        guard let newValue = newValue else {
            preconditionFailure("Nil values are not allowed")
        }
        BidirectionalMap.set(key: key, newValue: newValue, forward: &forward, reverse: &reverse)
      }
    }

    /// Returns a `Value1` for a given key `Value2`.
    subscript(key: Value2) -> Value1? {
      get {
        return reverse[key]
      }

      set (newValue) {
        guard let newValue = newValue else {
            preconditionFailure("Nil values are not allowed")
        }
        BidirectionalMap.set(key: key, newValue: newValue, forward: &reverse, reverse: &forward)
      }
    }
    
    /// Reserves enough space to store the specified number of nodes.
    mutating func reserveCapacity(_ count: Int) {
        forward.reserveCapacity(count)
        reverse.reserveCapacity(count)
    }
    
    func makeIterator() -> Dictionary<Value1, Value2>.Iterator {
        return forward.makeIterator()
    }
}
