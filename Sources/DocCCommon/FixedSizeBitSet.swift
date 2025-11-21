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
        return 1 &<< number
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
            storage &>>= amountToShift
            
            current &+= amountToShift
            return current
        }
    }
}

// MARK: Collection

extension _FixedSizeBitSet: Collection {
    // Collection conformance requires an `Index` type, that the collection can advance, and `startIndex` and `endIndex` accessors that follow certain requirements.
    //
    // For this design, as a hidden implementation detail, the `Index` holds the bit offset to the element.
    
    @inlinable
    package subscript(position: Index) -> Int {
        precondition(position.bit < Storage.bitWidth, "Index \(position.bit) out of bounds")
        // Because the index stores the bit offset, which is also the value, we can simply return the value without accessing the storage.
        return Int(position.bit)
    }
    
    package struct Index: Comparable {
        // The bit offset into the storage to the value
        fileprivate var bit: UInt8
        
        package static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.bit < rhs.bit
        }
    }
    
    @inlinable
    package var startIndex: Index {
        // This is the index (bit offset) to the smallest value in the bit set.
        Index(bit: UInt8(storage.trailingZeroBitCount))
    }
    
    @inlinable
    package var endIndex: Index {
        // For a valid collection, the end index is required to be _exactly_ one past the last in-bounds index, meaning; `index(after: LAST_IN-BOUNDS_INDEX)`
        // If the collection implementation doesn't satisfy this requirement, it will have an infinitely long `indices` collection.
        // This either results in infinite implementations or hits internal preconditions in other Swift types that that collection has more elements than its `count`.
        
        // See `index(after:)` below for explanation of how the index after is calculated.
        let lastInBoundsBit = UInt8(Storage.bitWidth &- storage.leadingZeroBitCount)
        return Index(bit: lastInBoundsBit &+ UInt8((storage &>> lastInBoundsBit).trailingZeroBitCount))
    }
    
    @inlinable
    package func index(after currentIndex: Index) -> Index {
        // To advance the index we have to find the next 1 bit _after_ the current bit.
        // For example, consider the following 16 bits, where values are represented from right to left:
        //   0110 0010 0110 0010
        //
        // To go from the first index to the second index, we need to count the number of 0 bits between it and the next 1 bit.
        // We get this value by shifting the bits by one past the current index:
        //   0110 0010 0110 0010
        //                    ╰╴current index
        //   0001 1000 1001 1000
        //                   ~~~ 3 trailing zero bits
        //
        // The second index's absolute value is the one past the first index's value plus the number of trailing zero bits in the shifted value.
        //
        // For the third index we repeat the same process, starting by shifting the bits by one past second index:
        //   0110 0010 0110 0010
        //               ╰╴current index
        //   0000 0001 1000 1001
        //                      0 trailing zero bits
        //
        // This time there are no trailing zero bits in the shifted value, so the third index's absolute value is just one past the second index.
        let shift = currentIndex.bit &+ 1
        return Index(bit: shift &+ UInt8((storage &>> shift).trailingZeroBitCount))
    }
    
    @inlinable
    package func formIndex(after index: inout Index)  {
        // See `index(after:)` above for explanation.
        index.bit &+= 1
        index.bit &+= UInt8((storage &>> index.bit).trailingZeroBitCount)
    }
    
    @inlinable
    package func distance(from start: Index, to end: Index) -> Int {
        // To compute the distance between two indices we have to find the number 1 bit from the start index to (but excluding) the end index.
        // For example, consider the following 16 bits, where values are represented from right to left:
        //   0110 0010 0110 0010
        //      end╶╯    ╰╴start
        //
        // To find the distance between the second index and the fourth index, we need to count the number of 0 bits between it and the next 1 bit.
        // We limit the calculation to this range in two steps.
        //
        // First, we mask out all the bits above the end index:
        //      end╶╮    ╭╴start
        //   0110 0010 0110 0010
        //   0000 0011 1111 1111  mask
        //
        // Because collections can have end indices that extend out-of-bounds we need to clamp the mask from a larger integer type to avoid it wrapping around to 0.
        let mask = Storage(clamping: (1 &<< UInt(end.bit)) &- 1)
        var distance = storage & mask
        
        // Then, we shift away all the bits below the start index:
        //      end╶╮    ╭╴start
        //   0000 0010 0110 0010
        //   0000 0000 0000 1001
        distance &>>= start.bit
        
        // The distance from start to end is the number of 1 bits in this number.
        return distance.nonzeroBitCount
    }
    
    @inlinable
    package var first: Element? {
        isEmpty ? nil : storage.trailingZeroBitCount
    }
    
    @inlinable
    package func min() -> Element? {
        first // The elements are already sorted
    }
    
    @inlinable
    package func sorted() -> [Element] {
        Array(self) // The elements are already sorted
    }
    
    @inlinable
    package var count: Int {
        storage.nonzeroBitCount
    }
}

// MARK: Hashable

extension _FixedSizeBitSet: Hashable {}

// MARK: Combinations

extension _FixedSizeBitSet {
    /// Returns a list of all possible combinations of the elements in the set, in order of increasing number of elements.
    package func allCombinationsOfValues() -> [Self] {
        // Leverage the fact that bits of an Int represent the possible combinations.
        let smallest = storage.trailingZeroBitCount
        
        var combinations: [Self] = []
        combinations.reserveCapacity((1 &<< count /*known to be less than Storage.bitWidth */) - 1)
        
        for raw in 1 ... storage &>> smallest {
            let combination = Self(storage: Storage(raw &<< smallest))
            
            // Filter out any combinations that include columns that are the same for all overloads
            guard self.isSuperset(of: combination) else { continue }
            
            combinations.append(combination)
        }
        // The bits of larger and larger Int values won't be in order of number of bits set, so we sort them.
        return combinations.sorted(by: { $0.count < $1.count })
    }
}
