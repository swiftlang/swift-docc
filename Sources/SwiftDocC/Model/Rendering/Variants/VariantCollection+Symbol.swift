/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// Initializers for creating variant collections from symbol values.

public extension VariantCollection {
    
    /// Creates a variant collection from a non-empty symbol variants data using the given transformation closure.
    ///
    /// If there are no variants for the symbol data, this initializer returns `nil`.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init?<SymbolValue>(
        from documentationDataVariants: DocumentationDataVariants<SymbolValue>,
        transform: (DocumentationDataVariantsTrait, SymbolValue) -> Value
    ) {
        self.init(from: documentationDataVariants, anyTransform: { trait, value in transform(trait, value as! SymbolValue) })
    }
    
    /// Creates a variant collection from a non-empty symbol variants data of the same value type using the given transformation closure.
    ///
    /// Use this initializer when the `Value` of  the given ``DocumentationDataVariants`` is the same as the variant collection's `Value`. If there are no variants
    /// for the symbol data, this initializer returns `nil`.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init?(
        from documentationDataVariants: DocumentationDataVariants<Value>,
        transform: (DocumentationDataVariantsTrait, Value) -> Value = { $1 }
    ) {
        self.init(from: documentationDataVariants, anyTransform: { trait, value in transform(trait, value as! Value) })
    }
    
    /// Creates a variant collection of optional value from a symbol variants data of the same value type using the given transformation closure.
    ///
    /// Use this initializer when the `Value` of  the given ``DocumentationDataVariants`` is the variant collection's `Value` wrapped in an `Optional` .
    /// If there are no variants for the symbol data, the variant collection encodes a `nil` value.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init<Wrapped>(
        from documentationDataVariants: DocumentationDataVariants<Wrapped>,
        transform: (DocumentationDataVariantsTrait, Value) -> Value = { $1 }
    ) where Value == Wrapped? {
        var documentationDataVariants = documentationDataVariants

        let defaultValue = documentationDataVariants.removeDefaultValueForRendering().flatMap(transform)

        let variants = documentationDataVariants.allValues.compactMap { trait, value -> Variant<Value>? in
            Self.createVariant(trait: trait, value: transform(trait, value))
        }

        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection from a symbol variants data of the same value type using the given transformation closure.
    ///
    /// If there are no variants for the symbol data, the transform closure is called with a `nil` value.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init<SymbolValue>(
        from documentationDataVariants: DocumentationDataVariants<SymbolValue>,
        transform: ((DocumentationDataVariantsTrait, SymbolValue)?) -> Value
    ) {
        var documentationDataVariants = documentationDataVariants
        
        let defaultValue = transform(documentationDataVariants.removeDefaultValueForRendering())
        
        let variants = documentationDataVariants.allValues.compactMap { trait, value -> Variant<Value>? in
            Self.createVariant(trait: trait, value: transform((trait, value)))
        }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection from a given set of variant traits.
    ///
    /// If there are no variants for the given traits, this initializer returns `nil`.
    ///
    /// This initializer picks a variant (the Swift variant, if available)
    /// of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    ///
    /// - Parameters:
    ///   - traits: The traits to consider when creating a variant collection.
    ///   - fallbackDefaultValue: A fallback value to use if the given `transform` function
    ///     returns nil for the default trait.
    ///   - transform: The function that should be used to transform the a given variant trait
    ///     to a value for the variant collection
    init?(
        from traits: Set<DocumentationDataVariantsTrait>,
        fallbackDefaultValue: Value,
        transform: (DocumentationDataVariantsTrait) -> Value?
    ) {
        var traits = traits
        guard let defaultTrait = traits.removeFirstTraitForRendering() else {
            return nil
        }
        
        let defaultValue = transform(defaultTrait) ?? fallbackDefaultValue
        
        let variants = traits.compactMap { trait in
            guard let value = transform(trait) else {
                return nil
            }
            
            return (trait, value)
        }.compactMap { trait, value in
            Self.createVariant(trait: trait, value: value)
        }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection from two symbol variants data using the given transformation closure.
    ///
    /// If the first symbol data variants value is empty, this initializer returns `nil`. If the second data variants value is empty, the transform closure is passed
    /// `nil` for the second value.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init?<Value1, Value2>(
        from documentationDataVariants1: DocumentationDataVariants<Value1>,
        optionalValue documentationDataVariants2: DocumentationDataVariants<Value2>,
        transform: (DocumentationDataVariantsTrait, Value1, Value2?) -> Value
    ) {
        var documentationDataVariants1 = documentationDataVariants1
        var documentationDataVariants2 = documentationDataVariants2
        
        guard let (trait1, defaultValue1) = documentationDataVariants1.removeDefaultValueForRendering() else {
            return nil
        }
        
        let defaultValue2 = documentationDataVariants2.removeDefaultValueForRendering()
        
        let defaultValue = transform(trait1, defaultValue1, defaultValue2.map(\.variant))
        
        let variants = zipPairsByKey(documentationDataVariants1.allValues, optionalPairs2: documentationDataVariants2.allValues)
            .compactMap { (trait, values) -> Variant<Value>? in
                let (value1, value2) = values
                return Self.createVariant(trait: trait, value: transform(trait, value1, value2))
            }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection of optional value from two symbol variants data using the given transformation closure.
    ///
    /// If the first symbol data variants value is empty, this initializer returns `nil`. If the second data variants value is empty, the transform closure is passed
    /// `nil` for the second value.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init?<Value1, Value2, Wrapped>(
        from documentationDataVariants1: DocumentationDataVariants<Value1>,
        optionalValue documentationDataVariants2: DocumentationDataVariants<Value2>,
        transform: (DocumentationDataVariantsTrait, Value1, Value2?) -> Value
    ) where Value == Wrapped? {
        var documentationDataVariants1 = documentationDataVariants1
        var documentationDataVariants2 = documentationDataVariants2
        
        guard let (trait1, defaultValue1) = documentationDataVariants1.removeDefaultValueForRendering() else {
            return nil
        }
        
        let defaultValue2 = documentationDataVariants2.removeDefaultValueForRendering()
        
        let defaultValue = transform(trait1, defaultValue1, defaultValue2.map(\.variant))
        
        let variants = zipPairsByKey(documentationDataVariants1.allValues, optionalPairs2: documentationDataVariants2.allValues)
            .compactMap { (trait, values) -> Variant<Value>? in
                let (value1, value2) = values
                guard let patchValue = transform(trait, value1, value2) else { return nil }
                return Self.createVariant(trait: trait, value: patchValue)
            }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection from two non-empty symbol variants data using the given transformation closure.
    ///
    /// If either symbol data variants values are empty, this initializer returns `nil`.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init?<Value1, Value2>(
        from documentationDataVariants1: DocumentationDataVariants<Value1>,
        _ documentationDataVariants2: DocumentationDataVariants<Value2>,
        transform: (DocumentationDataVariantsTrait, Value1, Value2) -> Value
    ) {
        var documentationDataVariants1 = documentationDataVariants1
        var documentationDataVariants2 = documentationDataVariants2
        
        guard let (trait1, defaultValue1) = documentationDataVariants1.removeDefaultValueForRendering(),
              let (_, defaultValue2) = documentationDataVariants2.removeDefaultValueForRendering()
        else {
            return nil
        }
        
        let defaultValue = transform(trait1, defaultValue1, defaultValue2)
        
        let variants = zipPairsByKey(documentationDataVariants1.allValues, documentationDataVariants2.allValues)
            .compactMap { (trait, values) -> Variant<Value>? in
                let (value1, value2) = values
                return Self.createVariant(trait: trait, value: transform(trait, value1, value2))
            }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection from three non-empty symbol variants data using the given transformation closure.
    ///
    /// If any of symbol data variants values are empty, this initializer returns `nil`.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    init?<Value1, Value2, Value3>(
        from documentationDataVariants1: DocumentationDataVariants<Value1>,
        _ documentationDataVariants2: DocumentationDataVariants<Value2>,
        _ documentationDataVariants3: DocumentationDataVariants<Value3>,
        transform: (DocumentationDataVariantsTrait, Value1, Value2, Value3) -> Value
    ) {
        var documentationDataVariants1 = documentationDataVariants1
        var documentationDataVariants2 = documentationDataVariants2
        var documentationDataVariants3 = documentationDataVariants3
        
        guard let (trait1, defaultValue1) = documentationDataVariants1.removeDefaultValueForRendering(),
              let (_, defaultValue2) = documentationDataVariants2.removeDefaultValueForRendering(),
              let (_, defaultValue3) = documentationDataVariants3.removeDefaultValueForRendering()
        else {
            return nil
        }
        
        let defaultValue = transform(trait1, defaultValue1, defaultValue2, defaultValue3)
        
        let variants = zipTriplesByKey(
            documentationDataVariants1.allValues,
            documentationDataVariants2.allValues,
            documentationDataVariants3.allValues
        ).compactMap { (trait, values) -> Variant<Value>? in
            let (value1, value2, value3) = values
            return Self.createVariant(trait: trait, value: transform(trait, value1, value2, value3))
        }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant collection from a non-empty symbol variants data using the given transformation closure.
    ///
    /// If the symbol data variants value is empty, this initializer returns `nil`.
    ///
    /// This initializer picks a variant (the Swift variant, if available) of the given symbol data as the default value for the variant collection. Other variants
    /// are encoded in the variant collection's ``variants``.
    private init?<DocumentationDataVariantsValue>(
        from documentationDataVariants: DocumentationDataVariants<DocumentationDataVariantsValue>,
        anyTransform transform: (DocumentationDataVariantsTrait, Any) -> Value
    ) {
        var documentationDataVariants = documentationDataVariants
        
        guard let defaultValue = documentationDataVariants.removeDefaultValueForRendering().flatMap(transform) else {
           return nil
        }
        
        let variants = documentationDataVariants.allValues.compactMap { trait, value -> Variant<Value>? in
            Self.createVariant(trait: trait, value: transform(trait, value))
        }
        
        self.init(defaultValue: defaultValue, variants: variants)
    }
    
    /// Creates a variant with a replace operation given a trait and a value.
    ///
    /// This function returns `nil` if the given trait doesn't have an interface language.
    private static func createVariant(
        trait: DocumentationDataVariantsTrait,
        value: Value
    ) -> Variant<Value>? {
        guard let interfaceLanguage = trait.interfaceLanguage else { return nil }
        
        return Variant(traits: [.interfaceLanguage(interfaceLanguage)], patch: [
            .replace(value: value)
        ])
    }
}

private extension DocumentationDataVariants {
    /// Removes and returns the value that should be considered as the default value for rendering.
    ///
    /// The default value used for rendering is the Swift variant of the symbol data if available, otherwise it's the first one that's been registered.
    mutating func removeDefaultValueForRendering() -> (trait: DocumentationDataVariantsTrait, variant: Variant)? {
        let index = allValues.firstIndex(where: { $0.trait == .swift }) ?? allValues.indices.startIndex
        
        guard allValues.indices.contains(index) else {
            return nil
        }
        
        let (trait, variant) = allValues[index]
        self[trait] = nil
        return (trait, variant)
    }
}

private extension Set where Element == DocumentationDataVariantsTrait {
    /// Removes and returns the trait that should be considered as the default value
    /// for rendering.
    ///
    /// The default value used for rendering is the Swift variant of the symbol data if available,
    /// otherwise it's the first one that's been registered.
    mutating func removeFirstTraitForRendering() -> DocumentationDataVariantsTrait? {
        if isEmpty {
            return nil
        } else {
            return remove(.swift) ?? removeFirst()
        }
    }
}

/// Creates a dictionary out of two sequences of pairs of the same key type.
///
/// ```swift
/// let words = [("a", "one"), ("b", "two")]
/// let numbers = [("a", 1), ("b", 2)]
///
/// for (letter, value) in zipPairsByKey(words, numbers) {
///     let (word, number) = value
///     print("\(letter): (\(word), \(number))")
/// }
/// // Prints "a: (one, 1)"
/// // Prints "b: (two, 2)"
/// ```
///
/// - Note: Elements that don't have a corresponding element with the same key in the other sequence are dropped.
///
/// - Parameters:
///     - pairs1: The first sequence to zip.
///     - pairs2: The second sequence to zip.
///
/// - Precondition: Each sequence's pairs have distinct keys within that sequence.
private func zipPairsByKey<Key, Value1, Value2, Pairs1: Sequence, Pairs2: Sequence>(
    _ pairs1: Pairs1,
    _ pairs2: Pairs2
) -> Dictionary<Key, (Value1, Value2)>
where Pairs1.Element == (Key, Value1), Pairs2.Element == (Key, Value2) {
    let dictionary1 = Dictionary<Key, Value1>(uniqueKeysWithValues: pairs1)
    let dictionary2 = Dictionary<Key, Value2>(uniqueKeysWithValues: pairs2)
    
    return Dictionary(
        uniqueKeysWithValues: dictionary1.compactMap { key, value1 -> (Key, (Value1, Value2))? in
            guard let value2 = dictionary2[key] else { return nil }
            return (key, (value1, value2))
        }
    )
}

/// Creates a dictionary out of two sequences of pairs of the same key type, with nil for values that are missing from the second sequence.
///
/// ```swift
/// let words = [("a", "one"), ("b", "two")]
/// let numbers = [("a", 1)]
///
/// for (letter, value) in zipPairsByKey(words, numbers) {
///     let (word, number) = value
///     print("\(letter): (\(word), \(number ?? nil))")
/// }
/// // Prints "a: (one, 1)"
/// // Prints "b: (two, nil)"
/// ```
///
/// - Parameters:
///     - pairs1: The first sequence to zip.
///     - pairs2: The second sequence to zip.
///
/// - Precondition: Each sequence's pairs have distinct keys within that sequence.
private func zipPairsByKey<Key, Value1, Value2>(
    _ pairs1: [(Key, Value1)],
    optionalPairs2 pairs2: [(Key, Value2)]
) -> Dictionary<Key, (Value1, Value2?)> {
    let dictionary1 = Dictionary<Key, Value1>(uniqueKeysWithValues: pairs1)
    let dictionary2 = Dictionary<Key, Value2>(uniqueKeysWithValues: pairs2)
    
    return Dictionary(
        uniqueKeysWithValues: dictionary1.map { key, value1 -> (Key, (Value1, Value2?)) in
            (key, (value1, dictionary2[key]))
        }
    )
}

/// Creates a dictionary out of three sequences of pairs of the same key type.
///
/// ```swift
/// let words = [("a", "one"), ("b", "two")]
/// let numbers = [("a", 1), ("b", 2)]
/// let booleans = [("a", true), ("b", false)]
///
/// for (letter, value, boolean) in zipPairsByKey(words, numbers) {
///     let (word, number, boolean) = value
///     print("\(letter): (\(word), \(number), \(boolean))")
/// }
/// // Prints "a: (one, 1, true)"
/// // Prints "b: (two, nil, false)"
/// ```
///
/// - Parameters:
///     - pairs1: The first sequence to zip.
///     - pairs2: The second sequence to zip.
///     - pairs3: The third sequence to zip.
///
/// - Precondition: Each sequence's pairs have distinct keys within that sequence.
private func zipTriplesByKey<Key, Value1, Value2, Value3>(
    _ pairs1: [(Key, Value1)],
    _ pairs2: [(Key, Value2)],
    _ pairs3: [(Key, Value3)]
) -> Dictionary<Key, (Value1, Value2, Value3)> {
    let dictionary1 = Dictionary<Key, Value1>(uniqueKeysWithValues: pairs1)
    let dictionary2 = Dictionary<Key, Value2>(uniqueKeysWithValues: pairs2)
    let dictionary3 = Dictionary<Key, Value3>(uniqueKeysWithValues: pairs3)
    
    return Dictionary(
        uniqueKeysWithValues: dictionary1.compactMap { key, value1 -> (Key, (Value1, Value2, Value3))? in
            guard let value2 = dictionary2[key], let value3 = dictionary3[key]  else { return nil }
            return (key, (value1, value2, value3))
        }
    )
}
