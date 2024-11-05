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
    /// - Parameter listOfTypeNames: The lists of type-name lists to shrink to the minimal unique combinations of type names
    static func minimalSuggestedDisambiguation(listOfOverloadTypeNames: [[String]]) -> [[String]?] {
        // The number of types in each list
        guard let numberOfTypes = listOfOverloadTypeNames.first?.count, 0 < numberOfTypes else {
            return []
        }
        
        guard listOfOverloadTypeNames.dropFirst().allSatisfy({ $0.count == numberOfTypes }) else {
            assertionFailure("Overloads should always have the same number of parameters")
            return []
        }
        
        if numberOfTypes < 64, listOfOverloadTypeNames.count < 64 {
            // If there are few enough types and few enough overloads, use a specialized SetAlgebra implementation to save some allocation and hashing overhead.
            return _minimalSuggestedDisambiguation(listOfOverloadTypeNames: listOfOverloadTypeNames, numberOfTypes: numberOfTypes, using: _TinySmallValueIntSet.self)
        } else {
            // Otherwise, fall back to `Set<Int>`.
            // This should happen very rarely as it's uncommon to have more than 64 overloads or to have overloads of functions with 64 parameters.
            return _minimalSuggestedDisambiguation(listOfOverloadTypeNames: listOfOverloadTypeNames, numberOfTypes: numberOfTypes, using: Set<Int>.self)
        }
    }
    
    // A private implementation that allows for different type of `_IntSet` to be used for different sizes of input.
    private static func _minimalSuggestedDisambiguation<IntSet: _IntSet>(
        listOfOverloadTypeNames: [[String]],
        numberOfTypes: Int,
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
        
        let table: [[IntSet]] = listOfOverloadTypeNames.map { typeNames in
            typeNames.indexed().map { column, name in
                IntSet(listOfOverloadTypeNames.indices.filter {
                    listOfOverloadTypeNames[$0][column] == name
                })
            }
        }
        
        // Check if any columns are common for all overloads so that type name combinations with those columns can be skipped.
        let allOverloads = IntSet(0 ..< listOfOverloadTypeNames.count)
        let typeNameIndicesToCheck = (0 ..< numberOfTypes).filter {
            // It's sufficient to check the first row because this column has to be the same for all rows
            table[0][$0] != allOverloads
        }
        
        guard !typeNameIndicesToCheck.isEmpty else {
            // Every type name is common across the overloads. This information can't be used to disambiguate the overloads.
            return .init(repeating: nil, count: numberOfTypes)
        }
        
        // Second, we iterate over each overload's type names to find the shortest disambiguation.
        return listOfOverloadTypeNames.indexed().map { row, overload in
            var shortestDisambiguationSoFar: (indicesToInclude: IntSet, length: Int)?
            
            // For each overload we iterate over the possible parameter combinations with increasing number of elements in each combination.
            for typeNamesToInclude in typeNameIndicesToCheck.combinations(ofCount: 1...) {
                // Stop if we've already found a match with fewer parameters than this
                guard typeNamesToInclude.count <= (shortestDisambiguationSoFar?.indicesToInclude.count ?? .max) else {
                    break
                }
                
                let firstTypeNameToInclude = typeNamesToInclude.first! // The generated `typeNamesToInclude` is never empty.
                // Compute which other overloads this combinations of type names also could refer to.
                let overlap = typeNamesToInclude.dropFirst().reduce(into: table[row][firstTypeNameToInclude]) { partialResult, index in
                    partialResult.formIntersection(table[row][index])
                }
                
                guard overlap.count == 1 else {
                    // This combination of parameters doesn't disambiguate the result
                    continue
                }
                
                // Track the combined length of these type names in case another overload with the same number of type names is shorter.
                let length = typeNamesToInclude.reduce(0) { partialResult, index in
                    partialResult + overload[index].count
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
            // To compute the overload, start with all the type names and replace the unused ones with "_"
            var disambiguation = overload
            for col in overload.indices where !indicesToInclude.contains(col) {
                disambiguation[col] = "_"
            }
            return disambiguation
        }
    }
}

// MARK: Int Set

/// A private protocol that abstracts sets of integers.
private protocol _IntSet: SetAlgebra<Int> {
    // In addition to the general SetAlgebra, the code in this file checks the number of elements in the set.
    var count: Int { get }
}
extension Set<Int>: _IntSet {}
extension _TinySmallValueIntSet: _IntSet {}

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
