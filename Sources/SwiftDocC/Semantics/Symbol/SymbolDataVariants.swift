/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A model type that encapsulates variants of symbol data.
///
/// Use this type to represent a piece of information about a symbol that can have different values depending on some trait, e.g., the programming language the
/// symbol was defined in.
public struct SymbolDataVariants<Variant> {
    /// The variant values for this collection of variants.
    private var values: [SymbolDataVariantsTrait: Variant]
    
    /// The default value of the variant.
    private var defaultVariantValue: Variant?
    
    /// All the variants registered in this variant collection, including any default variant.
    ///
    /// The default variant value, if one exists, is the last element of the returned array.
    public var allValues: [(trait: SymbolDataVariantsTrait, variant: Variant)] {
        values.map { $0 }
            // Append the default variant value if there is one.
            + (defaultVariantValue.map { [(.fallback, $0)] } ?? [])
    }
    
    /// Whether there are any variants for this piece of information about the symbol
    public var isEmpty: Bool {
        values.isEmpty
    }
    
    /// Creates a variants value.
    ///
    /// - Parameters:
    ///   - values: The variants for a piece of information about a symbol, grouped by trait, e.g., programming language.
    ///   - defaultVariantValue: The default value for this piece of information about the symbol, if no variants have been registered.
    public init(values: [SymbolDataVariantsTrait: Variant] = [:], defaultVariantValue: Variant? = nil) {
        self.values = values
        self.defaultVariantValue = defaultVariantValue
    }
    
    /// Accesses the variant for the given trait.
    public subscript(trait: SymbolDataVariantsTrait) -> Variant? {
        get { values[trait] ?? defaultVariantValue }
        set {
            if trait == .fallback {
                defaultVariantValue = newValue
            } else {
                values[trait] = newValue
            }
        }
    }
    
    /// Whether a variant for the given trait has been registered.
    ///
    /// - Parameter trait: The trait to look up a variant for.
    public func hasVariant(for trait: SymbolDataVariantsTrait) -> Bool {
        values.keys.contains(trait)
    }
}

extension SymbolDataVariants {
    /// Convenience initializer to initialize a variants value with a Swift variant only.
    init(swiftVariant: Variant?) {
        if let swiftVariant = swiftVariant {
            self.init(values: [.swift: swiftVariant])
        } else {
            self.init()
        }
    }
    
    /// Convenience API to access the first variant, or the default value if there are no registered variants.
    var firstValue: Variant? {
        get { allValues.first?.variant }
        set { self[allValues.first?.trait ?? .fallback] = newValue }
    }
}

/// The trait associated with a variant of some piece of information about a symbol.
public struct SymbolDataVariantsTrait: Hashable {
    /// The Swift programming language.
    public static var swift = SymbolDataVariantsTrait(interfaceLanguage: "swift")
    
    /// The language in which the symbol was defined.
    public var interfaceLanguage: String?
    
    /// A special trait that represents the fallback trait, which internal clients can use to access the default value of a collection of variants.
    static var fallback = SymbolDataVariantsTrait()
    
    /// Creates a new trait given an interface language.
    ///
    /// - Parameter interfaceLanguage: The language in which a symbol was defined.
    public init(interfaceLanguage: String? = nil) {
        self.interfaceLanguage = interfaceLanguage
    }
}
