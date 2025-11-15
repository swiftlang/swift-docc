/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A fixed size bit set, used for storing very small amounts of small integer values.
///
/// This type can only store values that are `0 ..< Storage.bitWidth` which makes it _unsuitable_ as a general purpose set-algebra type.
/// However, in specialized cases where the caller can guarantee that all values are in bounds, this type can offer a memory and performance improvement.
package struct _FixedSizeBitSet<Storage: FixedWidthInteger & Sendable>: Sendable {
    package typealias Element = Int
    
    package init() {}
    
    @usableFromInline
    private(set) var storage: Storage = 0
    
    @inlinable
    init(storage: Storage) {
        self.storage = storage
    }
}

// MARK: Set Algebra

extension _FixedSizeBitSet: SetAlgebra {
    private static func mask(_ number: Int) -> Storage {
        precondition(number < Storage.bitWidth, "Number \(number) is out of bounds (0..<\(Storage.bitWidth))")
        return 1 << number
    }
    
    @inlinable
    @discardableResult
    mutating package func insert(_ member: Int) -> (inserted: Bool, memberAfterInsert: Int) {
        let newStorage = storage | _FixedSizeBitSet.mask(member)
        defer {
            storage = newStorage
        }
        return (newStorage != storage, member)
    }
    
    @inlinable
    @discardableResult
    mutating package func remove(_ member: Int) -> Int? {
        let newStorage = storage & ~_FixedSizeBitSet.mask(member)
        defer {
            storage = newStorage
        }
        return newStorage != storage ? member : nil
    }
    
    @inlinable
    @discardableResult
    mutating package func update(with member: Int) -> Int? {
        let (inserted, _) = insert(member)
        return inserted ? nil : member
    }
    
    @inlinable
    package func contains(_ member: Int) -> Bool {
        storage & _FixedSizeBitSet.mask(member) != 0
    }
        
    @inlinable
    package func isSuperset(of other: Self) -> Bool {
        (storage & other.storage) == other.storage
    }
    
    @inlinable
    package func union(_ other: Self) -> Self {
        .init(storage: storage | other.storage)
    }
    
    @inlinable
    package func intersection(_ other: Self) -> Self {
        .init(storage: storage & other.storage)
    }
    
    @inlinable
    package func symmetricDifference(_ other: Self) -> Self {
        .init(storage: storage ^ other.storage)
    }
    
    @inlinable
    mutating package func formUnion(_ other: Self) {
        storage |= other.storage
    }
    
    @inlinable
    mutating package func formIntersection(_ other: Self) {
        storage &= other.storage
    }
    
    @inlinable
    mutating package func formSymmetricDifference(_ other: Self) {
        storage ^= other.storage
    }
    
    @inlinable
    package var isEmpty: Bool {
        storage == 0
    }
}

// MARK: Sequence

extension _FixedSizeBitSet: Sequence {
    @inlinable
    package func makeIterator() -> some IteratorProtocol<Int> {
        _Iterator(set: self)
    }
    
    private struct _Iterator: IteratorProtocol {
        typealias Element = Int
        
        private var storage: Storage
        private var current: Int = -1
        
        @inlinable
        init(set: _FixedSizeBitSet) {
            self.storage = set.storage
        }
        
        @inlinable
        mutating func next() -> Int? {
            guard storage != 0 else {
                return nil
            }
            // If the set is somewhat sparse, we can find the next element faster by shifting to the next value.
            // This saves needing to do `contains()` checks for all the numbers since the previous element.
            let amountToShift = storage.trailingZeroBitCount + 1
            storage >>= amountToShift
            
            current += amountToShift
            return current
        }
    }
}

extension _FixedSizeBitSet {
    /// Returns a list of all possible combinations of the elements in the set, in order of increasing number of elements.
    package func allCombinationsOfValues() -> [Self] {
        // Leverage the fact that bits of an Int represent the possible combinations.
        let smallest = storage.trailingZeroBitCount
        
        var combinations: [Self] = []
        combinations.reserveCapacity((1 << count /*known to be less than Storage.bitWidth */) - 1)
        
        for raw in 1 ... storage >> smallest {
            let combination = Self(storage: Storage(raw << smallest))
            
            // Filter out any combinations that include columns that are the same for all overloads
            guard self.isSuperset(of: combination) else { continue }
            
            combinations.append(combination)
        }
        // The bits of larger and larger Int values won't be in order of number of bits set, so we sort them.
        return combinations.sorted(by: { $0.count < $1.count })
    }
    
    @inlinable
    package var count: Int {
        storage.nonzeroBitCount
    }
}
