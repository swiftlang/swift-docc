/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

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
        
        // We find the minimal suggested type-signature disambiguation in two steps.
        //
        // First, we compute which type names occur in which overloads.
        // For example, these type names (left) occur in these overloads (right).
        //
        //   String   Int  Double                [0  ]   [012]   [01 ]
        //   String?  Int  Double                [ 12]   [012]   [01 ]
        //   String?  Int  Float                 [ 12]   [012]   [  2]
        
        let table: [[Set<Int>]] = listOfOverloadTypeNames.map { typeNames in
            typeNames.indexed().map { column, name in
                Set(listOfOverloadTypeNames.indices.filter {
                    listOfOverloadTypeNames[$0][column] == name
                })
            }
        }
        
        // Check if any columns are common for all overloads so that type name combinations with those columns can be skipped.
        let allOverloads = Set(0 ..< listOfOverloadTypeNames.count)
        let typeNameColumnsCommonForAll = Set((0 ..< numberOfTypes).filter {
            // It's sufficient to check the first row because this column has to be the same for all rows
            table[0][$0] == allOverloads
        })
        
        guard typeNameColumnsCommonForAll != allOverloads else {
            // Every type name is common across the overloads. This information can't be used to disambiguate the overloads.
            return .init(repeating: nil, count: numberOfTypes)
        }
        
        // Second, we iterate over each overload's type names to find the shortest disambiguation.
        return listOfOverloadTypeNames.indexed().map { row, overload in
            var shortestDisambiguationSoFar: (indicesToInclude: Set<Int>, length: Int)?
            
            // For each overload we iterate over the possible parameter combinations with increasing number of elements in each combination.
            for typeNamesToInclude in uniqueSortedCombinations(ofNumbersUpTo: numberOfTypes) {
                guard typeNameColumnsCommonForAll.isDisjoint(with: typeNamesToInclude) else {
                    // This combination of type names contains a value that is common for all overloads.
                    // Skip it. There is always a shorter disambiguation that doesn't include this value.
                    continue
                }
                
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
                    shortestDisambiguationSoFar = (Set(typeNamesToInclude), length)
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

/// Returns a sequence of unique combinations up a given upper bounds, with increasing number of elements in each combination.
///
/// For example, when `upperBounds` is `4`, the sequence will first contain all the 1-element combinations:
/// ```
/// [1], [2], [3], [4],
/// ```
/// Next, it will contains all the 2-element combinations (in _some_ inner order):
/// ```
/// [1, 2], [1, 3], [2, 3], [1, 4], [2, 4], [3, 4],
/// ```
/// Next, it will contains all the 3-element combinations (in _some_ inner order):
/// ```
/// [1, 2, 3], [1, 2, 4], [1, 3, 4], [2, 3, 4],
/// ```
/// Finally, it will contains all the only 4-element combinations:
/// ```
/// [1, 2, 3, 4],
/// ```
private func uniqueSortedCombinations(ofNumbersUpTo upperBounds: Int) -> some Sequence<[Int]> {
    
    /// An iterator that generates sequences of unique number combinations, as described above.
    ///
    /// The iterator works by generating all combinations of a given size and then returning each element from the list.
    /// Once the iterator reaches the end of one size, it generates the next size and returns each element from that list.
    struct SortedCombinationsIterator: IteratorProtocol {
        typealias Element = [Int]
        
        private var upperBounds: Int
        private var currentSize = 0
        private var current: [Element]
        private var currentSlice: ArraySlice<Element>
        
        init(upperBounds: Int) {
            self.upperBounds = upperBounds
            self.current = (0..<upperBounds).map { [$0] }
            self.currentSlice = current[...]
        }
        
        mutating func next() -> Element? {
            if !currentSlice.isEmpty {
                return currentSlice.removeFirst()
            }
            guard currentSize < upperBounds else {
                return nil
            }
            currentSize += 1
            current = combinations(upTo: upperBounds, previous: current)
            guard !current.isEmpty else {
                return nil
            }
            currentSlice = current[...]
            return currentSlice.removeFirst()
        }
        
        func combinations(upTo upperBounds: Int, previous: [Element]) -> [Element] {
            precondition(upperBounds > 0)
            
            var result: [Element] = []
            result.reserveCapacity(upperBounds * upperBounds-1)
            for number in 0 ..< upperBounds {
                for var existing in previous where !existing.contains(number) && (existing.last ?? .max) < number {
                    existing.append(number)
                    
                    result.append(existing)
                }
            }
            return result
        }
    }
    
    return IteratorSequence(SortedCombinationsIterator(upperBounds: upperBounds))
}
