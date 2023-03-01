/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains a dictionary's keys.
public struct DictionaryKeysSection {
    public static var title: String {
        return "Properties"
    }
    
    /// The list of dictionary keys.
    public var dictionaryKeys = [DictionaryKey]()
    
    /// Merge additional keys to section.
    /// 
    /// Preserves the order and merges in documentation and symbols to any existing keys.
    mutating public func mergeDictionaryKeys(_ newDictionaryKeys: [DictionaryKey]) {
        if dictionaryKeys.isEmpty {
            // There are no existing keys, so swap these in and return.
            dictionaryKeys = newDictionaryKeys
            return
        }
        
        // Build a lookup table of the new keys
        var newDictionaryKeyLookup : Dictionary<String, DictionaryKey> = [:]
        newDictionaryKeys.forEach { newDictionaryKeyLookup[$0.name] = $0 }
        dictionaryKeys = dictionaryKeys.map { existingKey in
            if let newKey = newDictionaryKeyLookup[existingKey.name] {
                let contents = existingKey.contents.count > 0 ? existingKey.contents : newKey.contents
                let symbol   = existingKey.symbol != nil      ? existingKey.symbol   : newKey.symbol
                let required = existingKey.required || newKey.required
                let updatedKey = DictionaryKey(name: existingKey.name, contents: contents, symbol: symbol, required: required)
                newDictionaryKeyLookup.removeValue(forKey: existingKey.name)
                return updatedKey
            }
            return existingKey
        }
        // Are there any extra keys that didn't match existing set?
        if newDictionaryKeyLookup.count > 0 {
            // If documented keys are in alphabetical order, merge new ones in rather than append them.
            let extraKeys = newDictionaryKeys.filter { newDictionaryKeyLookup[$0.name] != nil }
            if dictionaryKeys.isSortedByName && newDictionaryKeys.isSortedByName {
                dictionaryKeys = dictionaryKeys.mergeSortedKeys(extraKeys)
            } else {
                dictionaryKeys.append(contentsOf: extraKeys)
            }
        }
    }
}

extension Array where Element == DictionaryKey {
    /// Checks whether the array of DictionaryKey values are sorted alphabetically according to their `name`.
    var isSortedByName: Bool {
        if self.count < 2  { return true }
        if self.count == 2 { return (self[0].name < self[1].name) }
        return (1..<self.count).allSatisfy {
            self[$0 - 1].name < self[$0].name
        }
    }
    
    /// Merge a list of dictionary keys with the current array of sorted keys, returning a new array.
    func mergeSortedKeys(_ newKeys: [DictionaryKey]) -> [DictionaryKey] {
        var oldIndex = 0
        var newIndex = 0
        
        var mergedKeys = [DictionaryKey]()
        
        while oldIndex < self.count || newIndex < newKeys.count {
            if newIndex >= newKeys.count {
                mergedKeys.append(self[oldIndex])
                oldIndex += 1
            } else if oldIndex >= self.count {
                mergedKeys.append(newKeys[newIndex])
                newIndex += 1
            } else if self[oldIndex].name < newKeys[newIndex].name {
                mergedKeys.append(self[oldIndex])
                oldIndex += 1
            } else {
                mergedKeys.append(newKeys[newIndex])
                newIndex += 1
            }
        }
        
        return mergedKeys
    }
}
