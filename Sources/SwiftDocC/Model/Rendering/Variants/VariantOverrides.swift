/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Defines the overrides for variants of documentation content.
///
/// This class can be used to accumulate override information while encoding a tree of objects.
///
/// ## Topics
///
/// ### Applying Patches
///
/// - ``RenderNodeVariantOverridesApplier``
public class VariantOverrides: Codable {
    /// The values of the variants, organized by trait.
    public var values = [VariantOverride]()
    
    /// Whether the collection of overrides is empty.
    public var isEmpty: Bool { values.isEmpty }
    
    /// Initializes a value given overrides.
    public init(values: [VariantOverride] = []) {
        add(contentsOf: values)
    }
    
    /// Adds the given override.
    public func add(_ variantOverride: VariantOverride) {
        if let index = values.firstIndex(where: { variantOverride.traits == $0.traits }) {
            values[index].patch.append(contentsOf: variantOverride.patch)
        } else {
            values.append(variantOverride)
        }
    }
    
    /// Adds the given overrides.
    public func add<Overrides>(
        contentsOf variantOverrides: Overrides
    ) where Overrides: Collection, Overrides.Element == VariantOverride {
        for variantOverride in variantOverrides {
            add(variantOverride)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([VariantOverride].self)
    }
}
