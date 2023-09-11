/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A list of JSON patches generated as differences between two documents.
public typealias JSONPatchDifferences = [JSONPatchOperation]

typealias CodablePath = [CodingKey]

/// A protocol that defines Diffable conformance for properties and structs in RenderNode JSON.
protocol RenderJSONDiffable {
    
    /// Returns the list of JSON patches (differences) to transform _other_ to _self_.
    func difference(from other: Self, at path: CodablePath) -> JSONPatchDifferences
    
    /// Returns if differences between _self_ and _other_ should be reported property-by-property or as a complete replacement.
    func isSimilar(to other: Self) -> Bool
}

// If not otherwise defined, difference(from:at:) methods will assume Diffable objects are not similar,
// and should therefore be replaced.
extension RenderJSONDiffable where Self: Equatable {
    func isSimilar(to other: Self) -> Bool {
        return self == other
    }
}

extension Array: RenderJSONDiffable where Element: Equatable & Encodable {
    /// Returns the differences between this array and the given one.
    func difference(from other: Array<Element>, at path: CodablePath) -> JSONPatchDifferences {
        let arrayDiffs = self.difference(from: other)
        var differences = arrayDiffs.removals
        
        differences.append(contentsOf: arrayDiffs.insertions)
        let patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [JSON.IntegerKey(offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [JSON.IntegerKey(offset)])
                return .add(pointer: pointer, encodableValue: element)
            }
        }
        
        return patchOperations
    }
    
    /// Returns the differences between two arrays with diffable values.
    func difference(
        from other: Array<Element>,
        at path: CodablePath
    ) -> JSONPatchDifferences where Element: RenderJSONDiffable {
        // This implementation computes both the insertions and deletions of significantly different elements
        // and the per-property differences between elements that are similar to one another.
        
        // First, compute the insertions and deletions based on elements that are _similar_.
        let differences = self.difference(from: other) { element1, element2 in
            return element1.isSimilar(to: element2)
        }
        var patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [JSON.IntegerKey(offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [JSON.IntegerKey(offset)])
                return .add(pointer: pointer, encodableValue: element)
            }
        }
        
        // Second, apply the insertions and deletions of significantly different elements so that the
        // elements that are _similar_ are aligned (have the same index in both arrays).
        let similarOther = other.applying(differences)!
        // Finally, iterate over the similar — but not equal — elements to compute their per-property differences.
        for (index, value) in enumerated() where similarOther[index] != value {
            patchOperations.append(contentsOf: value.difference(from: similarOther[index],
                                                                at: path + [JSON.IntegerKey(index)]))
        }
        
        return patchOperations
    }
    
    // For now, whole arrays should not be replaced.
    func isSimilar(to other: Array<Element>) -> Bool {
        return true
    }
}

extension Dictionary: RenderJSONDiffable where Key == String, Value: Encodable & Equatable {
    /// Returns the differences between this dictionary and the given one.
    func difference(from other: Dictionary<Key, Value>, at path: CodablePath) -> JSONPatchDifferences {
        var differences = JSONPatchDifferences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        
        for key in uniqueKeysSet {
            if self[key] == nil {
                differences.append(.remove(
                    pointer: JSONPointer(from: path + [JSON.IntegerKey(key)])))
            }
            else if self[key] != other[key] {
                differences.append(.replace(
                    pointer: JSONPointer(from: path + [JSON.IntegerKey(key)]),
                    encodableValue: self[key]))
            }
        }
        
        return differences
    }
    
    /// Returns the differences between two dictionaries with diffable values.
    func difference(
        from other: Dictionary<Key, Value>,
        at path: CodablePath
    ) -> JSONPatchDifferences where Value: RenderJSONDiffable {
        var differences = JSONPatchDifferences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        
        for key in uniqueKeysSet {
            differences.append(contentsOf: self[key].difference(from: other[key], at: path + [JSON.IntegerKey(key)]))
        }
        
        return differences
    }
    
    /// Returns the differences between two dictionaries of arrays with diffable values.
    func arrayValueDifference<Element>(
        from other: Dictionary<Key, [Element]>,
        at path: CodablePath
    ) -> JSONPatchDifferences where Element: RenderJSONDiffable & Equatable & Encodable {
        var differences = JSONPatchDifferences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        
        for key in uniqueKeysSet {
            differences.append(contentsOf: (self[key] as! Array<Element>?).difference(from: other[key],
                                                                                      at: path + [JSON.IntegerKey(key)]))
        }
        
        return differences
    }
    
    // For now, we are not replacing whole dictionaries.
    func isSimilar(to other: Dictionary<String, Value>) -> Bool {
        return true
    }
}

extension Optional: RenderJSONDiffable where Wrapped: RenderJSONDiffable & Equatable & Encodable {
    /// Returns the differences between this optional and the given one.
    @_disfavoredOverload func difference(from other: Optional<Wrapped>, at path: CodablePath) -> JSONPatchDifferences {
        var difference = JSONPatchDifferences()
        
        if let current = self, let other = other {
            difference.append(contentsOf: current.difference(from: other, at: path))
        } else if other != nil {
            difference.append(JSONPatchOperation.remove(
                pointer: JSONPointer(from: path)))
        } else if let current = self {
            difference.append(JSONPatchOperation.add(
                pointer: JSONPointer(from: path), encodableValue: current))
        }
        return difference
    }
    
    /// Returns the differences between this array of optional elements and the given one.
    func difference<Element>(
        from other: Optional<Array<Element>>,
        at path: CodablePath
    ) -> JSONPatchDifferences where Element : RenderJSONDiffable & Equatable & Encodable {
        var difference = JSONPatchDifferences()
        
        if let current = self, let other = other {
            difference.append(contentsOf: (current as! Array<Element>).difference(from: other, at: path))
        } else if other != nil {
            difference.append(JSONPatchOperation.remove(
                pointer: JSONPointer(from: path)))
        } else if let current = self {
            difference.append(JSONPatchOperation.add(
                pointer: JSONPointer(from: path), encodableValue: current))
        }
        return difference
    }
    
    // Optionals should deal with replacements on their own.
    func isSimilar(to other: Optional<Wrapped>) -> Bool {
        return true
    }
}
