/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension UnresolvedTopicReference {
    /// Creates an unresolved reference out of a symbol reference.
    /// - Parameters:
    ///   - symbolReference: A reference to a symbol.
    ///   - inputs: A collection of inputs files that the symbol is from.
    init?(symbolReference: SymbolReference, inputs: DocumentationContext.Inputs) {
        guard var components = URLComponents(string: symbolReference.path) else { return nil }
        components.scheme = ResolvedTopicReference.urlScheme
        components.host = inputs.id.rawValue
        if !components.path.hasPrefix("/") {
            components.path.insert("/", at: components.path.startIndex)
        }
        
        self.topicURL = ValidatedURL(components: components)
    }
}

