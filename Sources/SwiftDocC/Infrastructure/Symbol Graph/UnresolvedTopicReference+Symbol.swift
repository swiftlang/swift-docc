/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension UnresolvedTopicReference {
    /// Creates an unresolved reference out of a symbol reference.
    /// - Parameters:
    ///   - symbolReference: A reference to a symbol.
    ///   - bundle: A documentation bundle.
    init?(symbolReference: SymbolReference, bundle: DocumentationBundle) {
        guard var components = URLComponents(string: symbolReference.path) else { return nil }
        components.scheme = ResolvedTopicReference.urlScheme
        components.host = bundle.identifier
        if !components.path.hasPrefix("/") {
            components.path.insert("/", at: components.path.startIndex)
        }
        
        self.topicURL = ValidatedURL(components: components)
    }
}

