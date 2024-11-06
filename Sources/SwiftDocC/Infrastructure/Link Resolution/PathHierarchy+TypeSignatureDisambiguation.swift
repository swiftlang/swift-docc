/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Algorithms

extension PathHierarchy.DisambiguationContainer {
    
    /// Returns the minimal suggested type-signature disambiguation for a list of overloads with lists of type names (either parameter types or return value types).
    ///
    /// For example, the following type names
    /// ```
    /// String   Int  Double
    /// String?  Int  Double
    /// String?  Int  Float
    /// ```
    /// can be disambiguated using:
    ///  - `String,_,_` because only the first overload has `String` as its first type
    ///  - `String?,_,Double` because the combination of `String?` as its first type and `Double` as the last type is unique to the second overload.
    ///  - `_,_,Float` because only the last overload has `Float` as its last type.
    ///
    ///  If an overload can't be disambiguated using the provided type names, the returned value for that index is `nil`.
    ///
    /// - Parameter overloadsAndTypeNames: The lists of overloads and their type-name lists to shrink to the minimal unique combinations of disambiguating type names.
    /// - Returns: A list of the minimal unique combinations of disambiguating type names for each overload, or `nil` for a specific index if that overload can't be uniquely disambiguated using the provided type names.
    static func minimalSuggestedDisambiguation(forOverloadsAndTypeNames overloadsAndTypeNames: [(element: Element, typeNames: [String])]) -> [[String]?] {
        // The number of types in each list
        guard let numberOfTypes = overloadsAndTypeNames.first?.typeNames.count, 0 < numberOfTypes else {
            return []
        }
        
        guard overloadsAndTypeNames.dropFirst().allSatisfy({ $0.typeNames.count == numberOfTypes }) else {
            assertionFailure("Overloads should always have the same number of parameter types / return types")
            return []
        }
        
        // Construct a table of the different overloads' type names for quick access.
        let typeNames = Table<String>(width: numberOfTypes, height: overloadsAndTypeNames.count) { buffer in
            for (row, pair) in overloadsAndTypeNames.indexed() {
                for (column, typeName) in pair.typeNames.indexed() {
                    buffer[row, column] = typeName
                }
            }
        }
        
        if numberOfTypes < 64, overloadsAndTypeNames.count < 64 {
            // If there are few enough types and few enough overloads, use a specialized SetAlgebra implementation to save some allocation and hashing overhead.
            return _minimalSuggestedDisambiguation(typeNames: typeNames, using: _TinySmallValueIntSet.self)
        } else {
            // Otherwise, fall back to `Set<Int>`.
            // This should happen very rarely as it's uncommon to have more than 64 overloads or to have overloads of functions with 64 parameters.
            return _minimalSuggestedDisambiguation(typeNames: typeNames, using: Set<Int>.self)
        }
    }
    
    // A private implementation that allows for different type of `_IntSet` to be used for different sizes of input.
    private static func _minimalSuggestedDisambiguation<IntSet: _IntSet>(
        typeNames: consuming Table<String>,
        using: IntSet.Type
    ) -> [[String]?] {
        // We find the minimal suggested type-signature disambiguation in two steps.
        //
        // First, we compute which type names occur in which overloads.
        // For example, these type names (left) occur in these overloads (right).
        //
        //   String   Int  Double                [0  ]   [012]   [01 ]
        //   String?  Int  Double                [ 12]   [012]   [01 ]
        //   String?  Int  Float                 [ 12]   [012]   [  2]
        
        let table = typeNames.map { row, column, typeName in
            var set = IntSet()
            for index in typeNames.rowIndices where index == row || typeNames[index, column] == typeName {
                set.insert(index)
            }
            return set
        }
        
        // Second, iterate over each overload and try different combinations of type names to find the shortest disambiguation.
        //
        // To reduce unnecessary work in the iteration, we precompute which type name combinations are meaningful to check.
        
        // Check if any columns are common for all overloads. Those type names won't meaningfully disambiguate any overload.
        let allOverloads = IntSet(typeNames.rowIndices)
        let typeNameIndicesToCheck = IntSet(typeNames.columnIndices.filter {
            // It's sufficient to check the first row because this column has to be the same for all rows
            table[0, $0] != allOverloads
        })
        
        guard !typeNameIndicesToCheck.isEmpty else {
            // Every type name is common across all overloads. These type names can't be used to disambiguate the overloads.
            return .init(repeating: nil, count: typeNames.size.width)
        }
        
        // Create a sequence of type name combinations with increasing number of type names in each combination.
        let typeNameCombinationsToCheck = typeNameIndicesToCheck.combinationsToCheck()
        
        return typeNames.rowIndices.map { row in
            var shortestDisambiguationSoFar: (indicesToInclude: IntSet, length: Int)?
            
            for typeNamesToInclude in typeNameCombinationsToCheck {
                // Stop if we've already found a disambiguating combination using fewer type names than this.
                guard typeNamesToInclude.count <= (shortestDisambiguationSoFar?.indicesToInclude.count ?? .max) else {
                    break
                }
                
                // Compute which other overloads this combinations of type names also could refer to.
                var iterator = typeNamesToInclude.makeIterator()
                let firstTypeNameToInclude = iterator.next()! // The generated `typeNamesToInclude` is never empty.
                let overlap = IteratorSequence(iterator).reduce(into: table[row, firstTypeNameToInclude]) { accumulatedOverlap, index in
                    accumulatedOverlap.formIntersection(table[row, index])
                }
                
                guard overlap.count == 1 else {
                    // This combination of parameters doesn't disambiguate the result
                    continue
                }
                
                // Track the combined length of this combination of type names in case another combination (with the same number of type names) is shorter.
                let length = typeNamesToInclude.reduce(0) { accumulatedLength, index in
                    // It's faster to check the number of UTF8 code units.
                    // This disfavors non-UTF8 type names, but those could be harder to read/write so neither length is right or wrong here.
                    accumulatedLength + typeNames[row, index].utf8.count
                }
                if length < (shortestDisambiguationSoFar?.length ?? .max) {
                    shortestDisambiguationSoFar = (IntSet(typeNamesToInclude), length)
                }
            }
            
            guard let (indicesToInclude, _) = shortestDisambiguationSoFar else {
                // This overload can't be uniquely disambiguated by these type names
                return nil
            }
            
            // Found the fewest (and shortest) type names that uniquely disambiguate this overload.
            // Return the list of disambiguating type names or "_" for an unused type name.
            return typeNames.columnIndices.map {
                indicesToInclude.contains($0) ? typeNames[row, $0] : "_"
            }
        }
    }
}

// MARK: Int Set

/// A combination of type names to attempt to use for disambiguation.
///
/// This isn't a `Collection` alias to avoid adding new unnecessary API to `_TinySmallValueIntSet`.
private protocol _Combination: Sequence<Int> {
    // In addition to the general SetAlgebra, the code in this file checks the number of elements in the set.
    var count: Int { get }
}
extension [Int]: _Combination {}
    
/// A private protocol that abstracts sets of integers.
private protocol _IntSet: SetAlgebra<Int>, Sequence<Int> {
    // In addition to the general SetAlgebra, the code in this file checks the number of elements in the set.
    var count: Int { get }
    
    // Let each type specialize the creation of possible combinations to check.
    associatedtype Combination: _Combination
    associatedtype CombinationSequence: Sequence<Combination>
    func combinationsToCheck() -> CombinationSequence
}

extension Set<Int>: _IntSet {
    func combinationsToCheck() -> some Sequence<[Int]> {
        // For `Set<Int>`, use the Swift Algorithms implementation to generate the possible combinations.
        self.combinations(ofCount: 1...)
    }
}
extension _TinySmallValueIntSet: _IntSet, _Combination {
    func combinationsToCheck() -> [Self] {
        // For `_TinySmallValueIntSet`, leverage the fact that bits of an Int represent the possible combinations.
        let smallest = storage.trailingZeroBitCount
        
        var combinations: [Self] = []
        combinations.reserveCapacity((1 << count /*known to be <64 */) - 1)
        
        for raw in 1 ... storage >> smallest {
            let combination = Self(storage: UInt64(raw << smallest))
            
            // Filter out any combinations that include columns that are the same for all overloads
            guard self.isSuperset(of: combination) else { continue }

            combinations.append(combination)
        }
        // The bits of larger and larger Int values won't be in order of number of bits set, so we sort them.
        return combinations.sorted(by: { $0.count < $1.count })
    }
}

/// A specialized set-algebra type that only stores the possible values `0 ..< 64`.
///
/// This specialized implementation is _not_ suitable as a general purpose set-algebra type.
/// However, because the code in this file only works with consecutive sequences of very small integers (most likely `0 ..< 16` and increasingly less likely the higher the number),
/// and because the the sets of those integers is frequently accessed in loops, a specialized implementation addresses bottlenecks in `_minimalSuggestedDisambiguation(...)`.
///
/// > Important:
/// > This type is thought of as file private but it made internal so that it can be tested.
struct _TinySmallValueIntSet: SetAlgebra {
    typealias Element = Int
    
    init() {}
    
    @usableFromInline
    private(set) var storage: UInt64 = 0
    
    @inlinable
    init(storage: UInt64) {
        self.storage = storage
    }
    
    private static func mask(_ number: Int) -> UInt64 {
        precondition(number < 64, "Number \(number) is out of bounds (0..<64)")
        return 1 << number
    }
    
    @inlinable
    @discardableResult
    mutating func insert(_ member: Int) -> (inserted: Bool, memberAfterInsert: Int) {
        let newStorage = storage | Self.mask(member)
        defer {
            storage = newStorage
        }
        return (newStorage != storage, member)
    }
    
    @inlinable
    @discardableResult
    mutating func remove(_ member: Int) -> Int? {
        let newStorage = storage & ~Self.mask(member)
        defer {
            storage = newStorage
        }
        return newStorage != storage ? member : nil
    }
    
    @inlinable
    @discardableResult
    mutating func update(with member: Int) -> Int? {
        let (inserted, _) = insert(member)
        return inserted ? nil : member
    }
    
    @inlinable
    func contains(_ member: Int) -> Bool {
        storage & Self.mask(member) != 0
    }
    
    @inlinable
    var count: Int {
        storage.nonzeroBitCount
    }
    
    @inlinable
    func isSuperset(of other: Self) -> Bool {
        // Provide a custom implementation since this is called frequently in `combinationsToCheck()`
        (storage & other.storage) == other.storage
    }
    
    @inlinable
    func union(_ other: Self) -> Self {
        .init(storage: storage | other.storage)
    }
    
    @inlinable
    func intersection(_ other: Self) -> Self {
        .init(storage: storage & other.storage)
    }
    
    @inlinable
    func symmetricDifference(_ other: Self) -> Self {
        .init(storage: storage ^ other.storage)
    }
    
    @inlinable
    mutating func formUnion(_ other: Self) {
        storage |= other.storage
    }
    
    @inlinable
    mutating func formIntersection(_ other: Self) {
        storage &= other.storage
    }
    
    @inlinable
    mutating func formSymmetricDifference(_ other: Self) {
        storage ^= other.storage
    }
}

extension _TinySmallValueIntSet: Sequence {
    func makeIterator() -> Iterator {
        Iterator(set: self)
    }
    
    struct Iterator: IteratorProtocol {
        typealias Element = Int
        
        private var storage: UInt64
        private var current: Int = -1
        
        @inlinable
        init(set: _TinySmallValueIntSet) {
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

// MARK: Table

/// A fixed-size grid of elements.
private struct Table<Element> {
    typealias Size = (width: Int, height: Int)
    @usableFromInline
    let size: Size
    private let storage: ContiguousArray<Element>

    @inlinable
    init(width: Int, height: Int, initializingWith initializer: (_ buffer: inout UnsafeMutableTableBufferPointer) throws -> Void) rethrows {
        size = (width, height)
        let capacity = width * height
        storage = try .init(unsafeUninitializedCapacity: capacity) { buffer, initializedCount in
            var wrappedBuffer = UnsafeMutableTableBufferPointer(width: width, wrapping: buffer)
            try initializer(&wrappedBuffer)
            initializedCount = capacity
        }
    }

    struct UnsafeMutableTableBufferPointer {
        private let width: Int
        private var wrapping: UnsafeMutableBufferPointer<Element>

        init(width: Int, wrapping: UnsafeMutableBufferPointer<Element>) {
            self.width = width
            self.wrapping = wrapping
        }

        @inlinable
        subscript(row: Int, column: Int) -> Element {
            _read   { yield  wrapping[index(row: row, column: column)] }
            _modify { yield &wrapping[index(row: row, column: column)] }
        }

        private func index(row: Int, column: Int) -> Int {
            // Let the wrapped buffer validate the index
            row * width + column
        }
    }

    @inlinable
    subscript(row: Int, column: Int) -> Element {
        _read { yield storage[index(row: row, column: column)] }
    }

    private func index(row: Int, column: Int) -> Int {
        // Give nice assertion messages in debug builds and let the wrapped array validate the index in release builds.
        assert(0 <= row    && row    < size.height, "Row \(row) is out of range of 0..<\(size.height)")
        assert(0 <= column && column < size.width,  "Column \(column) is out of range of 0..<\(size.width)")

        return row * size.width + column
    }
    
    @inlinable
    var rowIndices: Range<Int> {
        0 ..< size.height
    }
    
    @inlinable
    var columnIndices: Range<Int> {
        0 ..< size.width
    }
}

extension Table {
    /// Returns a same-size table containing the results of mapping the given closure over the table's elements.
    ///
    /// - Parameter transform: A mapping closure that transforms an element of this table (and its location) a new value for the mapped table.
    /// - Returns: An new table with the same width and height containing the transformed elements of this table.
    @inlinable
    func map<Result>(_ transform: (_ row: Int, _ column: Int, Element) -> Result) -> Table<Result> {
        Table<Result>(width: size.width, height: size.height) { buffer in
            for row in rowIndices {
                for column in columnIndices {
                    buffer[row, column] = transform(row, column, self[row, column])
                }
            }
        }
    }
}
