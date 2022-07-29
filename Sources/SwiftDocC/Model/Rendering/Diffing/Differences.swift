/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

protocol Diffable {
    func difference(from other: Self, at path: Path) -> Differences
    func isSimilar(to other: Self) -> Bool
}

public typealias Differences = [JSONPatchOperation]
public typealias Path = [CodingKey]

extension Diffable {
    func propertyDifference<T>(_ current: T, from other: T, at path: Path) -> Differences where T: Equatable & Codable {
        var differences = Differences()
        if current != other {
            differences.append(.replace(pointer: JSONPointer(from: path), encodableValue: current))
        }
        return differences
    }
}

// If not otherwise defined, difference(from:at:) methods will assume Diffable objects are not similar,
// and should therefore be replaced.
extension Diffable where Self: Equatable {
    func isSimilar(to other: Self) -> Bool {
        return self == other
    }
}

extension Dictionary: Diffable where Key == String, Value: Encodable & Equatable {
    
    /// Returns the difference between two dictionaries with diffable values.
    func difference(from other: Dictionary<Key, Value>, at path: Path) -> Differences where Value: Diffable {
        var differences = Differences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        for key in uniqueKeysSet {
            differences.append(contentsOf: self[key].difference(from: other[key], at: path + [CustomKey(stringValue: key)]))
        }
        return differences
    }
    
    /// Returns the difference between two dictionaries with diffable values.
    func difference(from other: Dictionary<Key, Value>, at path: Path) -> Differences {
        var differences = Differences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        for key in uniqueKeysSet {
            if self[key] != other[key] {
                differences.append(.replace(
                    pointer: JSONPointer(from: path + [CustomKey(stringValue: key)]),
                    encodableValue: self[key]))
            }
        }
        return differences
    }
    
    /// Returns the difference between two dictionaries with diffable values.
    func arrayValueDifference<Element>(from other: Dictionary<Key, [Element]>, at path: Path) -> Differences where Element : Diffable & Equatable & Encodable {
        var differences = Differences()
        let uniqueKeysSet = Set(self.keys).union(Set(other.keys))
        for key in uniqueKeysSet {
            differences.append(contentsOf: (self[key] as! Array<Element>?).difference(from: other[key], at: path + [CustomKey(stringValue: key)]))
        }
        return differences
    }
    
    // For now, we are not replacing whole dictionaries
    func isSimilar(to other: Dictionary<String, Value>) -> Bool {
        return true
    }
}

extension Optional: Diffable where Wrapped: Diffable & Equatable & Encodable {
    /// Returns the differences between this optional and the given one.
    @_disfavoredOverload func difference(from other: Optional<Wrapped>, at path: Path) -> Differences {
        var difference = Differences()
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
    
    func difference<Element>(from other: Optional<Array<Element>>, at path: Path) -> Differences where Element : Diffable & Equatable & Encodable {
        var difference = Differences()
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

extension Array: Diffable where Element: Equatable & Encodable {
    
    /// Returns the differences between this array and the given one.
    func difference(from other: Array<Element>, at path: Path) -> Differences {
        let arrayDiffs = self.difference(from: other)
        var differences = arrayDiffs.removals
        differences.append(contentsOf: arrayDiffs.insertions)
        let patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .add(pointer: pointer, encodableValue: element)
            }
        }
        
        return patchOperations
    }
    
    func difference(from other: Array<Element>, at path: Path) -> Differences where Element: Diffable {
        let arrayDiffs = self.difference(from: other) { element1, element2 in
            return element1.isSimilar(to: element2)
        }
        var differences = arrayDiffs.removals.reversed() as [CollectionDifference<Element>.Change]
        differences.append(contentsOf: arrayDiffs.insertions)
        var patchOperations = differences.map { diff -> JSONPatchOperation in
            switch diff {
            case .remove(let offset, _, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .remove(pointer: pointer)
            case .insert(let offset, let element, _):
                let pointer = JSONPointer(from: path + [CustomKey(intValue: offset)])
                return .add(pointer: pointer, encodableValue: element)
            }
        }
        let similarOther = other.applying(arrayDiffs)! // Apply the changes so all elements are now similar.

        for (index, value) in enumerated() {
            if similarOther[index] != value {
                patchOperations.append(contentsOf: value.difference(from: similarOther[index], at: path + [CustomKey(intValue: index)]))
            }
        }
        return patchOperations
    }
    
    // For now, whole arrays should not be replaced.
    func isSimilar(to other: Array<Element>) -> Bool {
        return true
    }
}

/// Represents a change that can can be displayed between two versions of a RenderIndex Node.
public enum RenderIndexChange: String, Codable, Equatable {
    case added
    case modified
    case newlyDeprecated
}

/// A coding key with a custom name.
private struct CustomKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = intValue.description
    }
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}
