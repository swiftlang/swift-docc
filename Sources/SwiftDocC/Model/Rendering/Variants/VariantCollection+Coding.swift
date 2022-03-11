/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension KeyedEncodingContainer {
    /// Encodes the given variant collection.
    mutating func encodeVariantCollection<Value>(
        _ variantCollection: VariantCollection<Value>,
        forKey key: Key,
        encoder: Encoder
    ) throws {
        try encode(variantCollection, forKey: key)
    }
    
    /// Encodes the given boolean variant collection if its value is true.
    mutating func encodeVariantCollectionIfTrue(
        _ variantCollection: VariantCollection<Bool>,
        forKey key: Key,
        encoder: Encoder
    ) throws {
        if variantCollection.defaultValue {
            try encode(variantCollection.defaultValue, forKey: key)
        }
        
        variantCollection.addVariantsToEncoder(
            encoder,
            
            // Add the key to the encoder's coding path, since the coding path refers to the value's parent.
            pointer: JSONPointer(from: encoder.codingPath + [key]),
            isDefaultValueEncoded: variantCollection.defaultValue
        )
    }
    
    /// Encodes the given variant collection for its non-empty values.
    mutating func encodeVariantCollectionIfNotEmpty<Value>(
        _ variantCollection: VariantCollection<Value>,
        forKey key: Key,
        encoder: Encoder
    ) throws where Value: Collection {
        try encodeIfNotEmpty(variantCollection.defaultValue, forKey: key)
        
        variantCollection.mapValues { value in
            // Encode `nil` if the value is empty, so that when the patch is applied, it effectively
            // removes the default value.
            value.isEmpty ? nil : value
        }.addVariantsToEncoder(
            encoder,
            
            // Add the key to the encoder's coding path, since the coding path refers to the value's parent.
            pointer: JSONPointer(from: encoder.codingPath + [key]),
            isDefaultValueEncoded: !variantCollection.defaultValue.isEmpty
        )
    }
    
    /// Encodes the given variant collection.
    mutating func encodeVariantCollectionIfNotEmpty<Value>(
        _ variantCollection: VariantCollection<Value?>,
        forKey key: Key,
        encoder: Encoder
    ) throws where Value: Collection {
        if let defaultValue = variantCollection.defaultValue {
            try encodeIfNotEmpty(defaultValue, forKey: key)
        }
        variantCollection.addVariantsToEncoder(
            encoder,
            
            // Add the key to the encoder's coding path, since the coding path refers to the value's parent.
            pointer: JSONPointer(from: encoder.codingPath + [key]),
            isDefaultValueEncoded: variantCollection.defaultValue.map { !$0.isEmpty } ?? false
        )
    }
    
    /// Encodes the given variant collection, writing the default value if it's non-nil.
    ///
    /// Use this API to encode a variant collection and accumulate variants into the given encoder.
    ///
    /// > Note: The default value is encoded only if it's non-nil.
    mutating func encodeVariantCollection<Value>(
        _ variantCollection: VariantCollection<Value?>,
        forKey key: Key,
        encoder: Encoder
    ) throws {
        try encodeIfPresent(variantCollection.defaultValue, forKey: key)
        
        variantCollection.addVariantsToEncoder(
            encoder,
            
            // Add the key to the encoder's coding path, since the coding path refers to the value's parent.
            pointer: JSONPointer(from: encoder.codingPath + [key]),
            isDefaultValueEncoded: variantCollection.defaultValue != nil
        )
    }
    
    /// Encodes the given variant collection array if it's non-empty.
    mutating func encodeVariantCollectionArrayIfNotEmpty<Value>(
        _ variantCollectionValues: [VariantCollection<Value?>],
        forKey key: Key,
        encoder: Encoder
    ) throws {
        try encodeIfNotEmpty(variantCollectionValues.compactMap(\.defaultValue), forKey: key)
        
        for (index, variantCollection) in variantCollectionValues.enumerated() {
            variantCollection.addVariantsToEncoder(
                encoder,
                
                // Add the index to the encoder's coding path, since the coding path refers to the array.
                pointer: JSONPointer(from: encoder.codingPath + [key, IntegerKey(index)])
            )
        }
    }
}

/// An integer coding key.
private struct IntegerKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(_ value: Int) {
        self.intValue = value
        self.stringValue = value.description
    }
    
    init?(stringValue: String) {
        guard let intValue = Int(stringValue) else {
            return nil
        }
        
        self.intValue = intValue
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.init(intValue)
    }
}

extension KeyedDecodingContainer {
    /// Decodes the given variant collection.
    func decodeVariantCollection<Value>(
        ofValueType: Value.Type,
        forKey key: Key
    ) throws -> VariantCollection<Value> {
        try decode(VariantCollection<Value>.self, forKey: key)
    }
    
    /// Decodes the given variant collection and returns nil if it's not present.
    func decodeVariantCollectionIfPresent<Value>(
        ofValueType: Value.Type,
        forKey key: Key
    ) throws -> VariantCollection<Value>? {
        try decodeIfPresent(VariantCollection<Value>.self, forKey: key)
    }
   
    /// Decodes the given variant collection of optional value and empty variant collection if it's no value is present.
    func decodeVariantCollectionIfPresent<Value>(
        ofValueType: Value?.Type,
        forKey key: Key
    ) throws -> VariantCollection<Value?> {
        try decodeIfPresent(VariantCollection<Value?>.self, forKey: key) ?? .init(defaultValue: nil)
    }
    
    /// Decodes the given array of variant collections.
    func decodeVariantCollectionArrayIfPresent<Value>(
        ofValueType: Value?.Type,
        forKey key: Key
    ) throws -> [VariantCollection<Value?>] {
        try decodeIfPresent([VariantCollection<Value?>].self, forKey: key) ?? []
    }
}
