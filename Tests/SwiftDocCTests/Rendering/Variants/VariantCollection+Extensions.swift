/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

@testable import SwiftDocC

extension VariantCollection {
    
    /// Creates a variant collection given a default value and a value for Objective-C contexts.
    ///
    /// Use this initializer to specify a default value for the collection and a value that clients should use when processing documentation for Objective-C contexts
    /// (e.g., rendering a page using Objective-C syntax).
    ///
    /// - Parameters:
    ///   - defaultValue: The default value of the variant.
    ///   - objectiveCValue: The Objective-C variant of the value.
    init(defaultValue: Value, objectiveCValue: Value) {
        self.init(
            defaultValue: defaultValue,
            variants: [
                Variant(
                    traits: [.interfaceLanguage("objc")],
                    patch: [
                        .replace(value: objectiveCValue),
                    ]
                ),
            ]
        )
    }
}
