/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A model type that encapsulates variants of documentation node data.
///
/// Use this type to represent a piece of information about a documentation node that can have different values depending on some trait,
/// e.g., the programming language the symbol was defined in.
public struct DocumentationDataVariants<Variant> {
    /// The variant values for this collection of variants.
    private var values: [DocumentationDataVariantsTrait: Variant]
    
    /// The default value of the variant.
    private var defaultVariantValue: Variant?
    
    /// All the variants registered in this variant collection, including any default variant.
    ///
    /// The default variant value, if one exists, is the last element of the returned array.
    public var allValues: [(trait: DocumentationDataVariantsTrait, variant: Variant)] {
        values.map { (trait: $0.key, variant: $0.value) }
            // Append the default variant value if there is one.
            + (defaultVariantValue.map { [(.fallback, $0)] } ?? [])
    }
    
    /// Whether there are any variants for this piece of information about the documentation node
    public var isEmpty: Bool {
        values.isEmpty
    }
    
    /// Creates a variants value.
    ///
    /// - Parameters:
    ///   - values: The variants for a piece of information about a documentation node, grouped by trait, e.g., programming language.
    ///   - defaultVariantValue: The default value for this piece of information about the documentation node, if no variants have been registered.
    public init(values: [DocumentationDataVariantsTrait: Variant] = [:], defaultVariantValue: Variant? = nil) {
        self.values = values
        self.defaultVariantValue = defaultVariantValue
    }
    
    /// Accesses the variant for the given trait.
    public subscript(trait: DocumentationDataVariantsTrait) -> Variant? {
        get { values[trait] ?? defaultVariantValue }
        set {
            if trait == .fallback {
                defaultVariantValue = newValue
            } else {
                values[trait] = newValue
            }
        }
    }
    
    /// Accesses the variant for the given trait,
    /// falling back to the given default variant if the key isn’t found.
    public subscript(trait: DocumentationDataVariantsTrait, default defaultValue: Variant) -> Variant {
        get { values[trait] ?? defaultValue }
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
    public func hasVariant(for trait: DocumentationDataVariantsTrait) -> Bool {
        values.keys.contains(trait)
    }
    
    func map<NewVariant>(transform: (Variant) -> NewVariant) -> DocumentationDataVariants<NewVariant> {
        return DocumentationDataVariants<NewVariant>(
            values: Dictionary(
                uniqueKeysWithValues: values.map { (trait, variant) in
                    return (trait, transform(variant))
                }
            ),
            defaultVariantValue: defaultVariantValue.map(transform)
        )
    }
}

extension DocumentationDataVariants {
    /// Convenience initializer to initialize a variants value with a Swift variant only.
    init(swiftVariant: Variant?) {
        if let swiftVariant = swiftVariant {
            self.init(values: [.swift: swiftVariant])
        } else {
            self.init()
        }
    }
    
    static var empty: DocumentationDataVariants<Variant> {
        return DocumentationDataVariants<Variant>(values: [:], defaultVariantValue: nil)
    }
    
    /// Convenience API to access the first variant, or the default value if there are no registered variants.
    ///
    /// > Important:
    /// > Do not use this property in new code.
    /// > It exists to transition existing code from only working with Swift symbols to working with multi-language symbols.
    /// > This property should be considered deprecated but isn't formally deprecated to avoid the ~50 warnings that would make it
    /// > harder to spot new warnings. (rdar://86580516)
    var firstValue: Variant? {
        // A Dictionary's order isn't stable across program executions so accessing the `first` value would
        // result in non-deterministic behavior and also flaky tests.
        //
        // Since this convenience accessor exist to transition existing code from only working with Swift symbols,
        // it accesses the Swift value first, if it exist, and otherwise accesses the real non-deterministic first value.
        // This assumes that variant only represents one non-Swift language.
        get { self[.swift] ?? self.values.first?.value }
        set { self[.swift] = newValue }
    }
}

extension DocumentationDataVariants: Equatable where Variant: Equatable {}

/// The trait associated with a variant of some piece of information about a documentation node.
public struct DocumentationDataVariantsTrait: Hashable {
    /// The Swift programming language.
    public static var swift = DocumentationDataVariantsTrait(interfaceLanguage: "swift")
    
    /// The language in which the documentation node is relevant.
    public var interfaceLanguage: String?
    
    /// A special trait that represents the fallback trait, which internal clients can use to access the default value of a collection of variants.
    static var fallback = DocumentationDataVariantsTrait()
    
    /// Creates a new trait given an interface language.
    ///
    /// - Parameter interfaceLanguage: The language in which a documentation node is relevant.
    public init(interfaceLanguage: String? = nil) {
        self.interfaceLanguage = interfaceLanguage
    }

    /// Creates a new trait given a symbol graph selector.
    ///
    /// - Parameter selector: The symbol graph selector to use when creating the trait.
    public init(for selector: UnifiedSymbolGraph.Selector) {
        self.init(
            interfaceLanguage: SourceLanguage(knownLanguageIdentifier: selector.interfaceLanguage)?.id
                ?? selector.interfaceLanguage
        )
    }
}
