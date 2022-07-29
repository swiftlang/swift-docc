/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 A builder that collects ``Differences`` between two objects of the same type.
 
 The DifferenceBuilder is used when diffing two ``RenderNode`` objects against eachother.
 Initalize the DifferenceBuilder with the two
 */
struct DifferenceBuilder<T> {
    
    var differences: Differences
    let current: T
    let other: T
    let path: Path
    
    init(current: T, other: T, basePath: Path) {
        self.differences = []
        self.current = current
        self.other = other
        self.path = basePath
    }
    
    /// Determines the difference between the two diffable objects at the KeyPaths given.
    mutating func addDifferences<D>(atKeyPath keyPath: KeyPath<T, D>, forKey codingKey: CodingKey) where D: Diffable & Equatable & Encodable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            let diffs = currentProperty.difference(from: otherProperty, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Determines the difference between the two dictionaries mapping strings to diffable objects at the KeyPaths given.
    mutating func addDifferences<Element>(atKeyPath keyPath: KeyPath<T, Array<Element>>, forKey codingKey: CodingKey) where Element: Diffable & Equatable & Codable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            let diffs = currentProperty.difference(from: otherProperty, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Determines the difference between the two dictionaries mapping strings to arrays of diffable objects at the KeyPaths given.
    mutating func addDifferences<Value>(atKeyPath keyPath: KeyPath<T, Dictionary<String, [Value]>>, forKey codingKey: CodingKey) where Value: Diffable & Equatable & Encodable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            differences.append(contentsOf: currentProperty.arrayValueDifference(from: otherProperty, at: path + [codingKey]))
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Determines the difference between the two arrays of diffable objects at the KeyPaths given.
    mutating func addDifferences<Value>(atKeyPath keyPath: KeyPath<T, Dictionary<String, Value>>, forKey codingKey: CodingKey) where Value: Diffable & Equatable & Encodable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            let diffs = currentProperty.difference(from: otherProperty, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Determines the difference between the two dictionaries mapping strings to diffable objects at the KeyPaths given.
    mutating func addDifferences<Element>(atKeyPath keyPath: KeyPath<T, Array<Element>?>, forKey codingKey: CodingKey) where Element: Diffable & Equatable & Codable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty == otherProperty {
            return
        }
        
        if currentProperty.isSimilar(to: otherProperty) {
            let diffs = currentProperty.difference(from: otherProperty, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }

    /// Adds the difference between two properties to the DifferenceBuilder.
    mutating func addDifferences<E>(atKeyPath keyPath: KeyPath<T, E>, forKey codingKey: CodingKey) where E: Equatable & Encodable {
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if currentProperty != otherProperty {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: currentProperty))
        }
    }
    
    /// Unwraps and adds the difference between two optional RenderSections.
    mutating func addDifferences(atKeyPath keyPath: KeyPath<T, Optional<RenderSection>>, forKey key: CodingKey) {
        
        let currentProperty = current[keyPath: keyPath]
        let otherProperty = other[keyPath: keyPath]
        
        if let currentProperty = currentProperty, let otherProperty = otherProperty {
            let anyCurrent = AnyRenderSection(currentProperty)
            let anyOther = AnyRenderSection(otherProperty)
            if anyCurrent.isSimilar(to: anyOther) {
                differences.append(contentsOf: anyCurrent.difference(from: anyOther, at: path + [key]))
            } else {
                differences.append(.replace(pointer: JSONPointer(from: path + [key]), encodableValue: currentProperty))
            }
        } else if otherProperty != nil {
            differences.append(.remove(pointer: JSONPointer(from: path + [key])))
        } else if let currentProp = currentProperty {
            differences.append(.add(pointer: JSONPointer(from: path + [key]), encodableValue: currentProp))
        }
    }
    
    /// Determines the difference between the two diffable Arrays of RenderSections at the KeyPaths given.
    mutating func addDifferences(atKeyPath keyPath: KeyPath<T, Array<RenderSection>>, forKey codingKey: CodingKey) {
        let currentArray = current[keyPath: keyPath]
        let otherArray = other[keyPath: keyPath]
        
        let typeErasedCurrentArray = currentArray.map { section in
            return AnyRenderSection(section)
        }
        let typeErasedOtherArray = otherArray.map { section in
            return AnyRenderSection(section)
        }
        
        if typeErasedCurrentArray == typeErasedOtherArray {
            return
        }

        if typeErasedCurrentArray.isSimilar(to: typeErasedOtherArray) {
            let diffs = typeErasedCurrentArray.difference(from: typeErasedOtherArray, at: path + [codingKey])
            differences.append(contentsOf: diffs)
        } else {
            differences.append(.replace(pointer: JSONPointer(from: path + [codingKey]), encodableValue: typeErasedCurrentArray))
        }
    }
    
    /// Determines the difference between the two dictionaries of RenderReferences at the KeyPaths given.
    mutating func addDifferences(atKeyPath keyPath: KeyPath<T, Dictionary<String, RenderReference>>, forKey codingKey: CodingKey) {
        let currentDict = current[keyPath: keyPath].mapValues { section in
            return AnyRenderReference(section)
        }
        let otherDict = other[keyPath: keyPath].mapValues { section in
            return AnyRenderReference(section)
        }
        
        if currentDict == otherDict {
            return
        }

        differences.append(contentsOf: currentDict.difference(from: otherDict, at: path + [codingKey]))
    }
}
