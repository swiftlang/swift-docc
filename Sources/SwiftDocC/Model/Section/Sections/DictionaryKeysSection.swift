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
        
        // Update existing keys with new data being passed in.
        dictionaryKeys = dictionaryKeys.insertAndUpdate(newDictionaryKeys) { existingKey, newKey in
            let contents = existingKey.contents.count > 0 ? existingKey.contents : newKey.contents
            let symbol = existingKey.symbol ?? newKey.symbol
            let required = existingKey.required || newKey.required
            return DictionaryKey(name: existingKey.name, contents: contents, symbol: symbol, required: required)
        }
    }
}

extension DictionaryKey: ListItemUpdatable {
    var listItemIdentifier: String { name }
}
