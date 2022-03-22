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
    ///   - catalog: A documentation catalog.
    init?(symbolReference: SymbolReference, catalog: DocumentationCatalog) {
        guard var components = URLComponents(string: symbolReference.path) else { return nil }
        components.scheme = ResolvedTopicReference.urlScheme
        components.host = catalog.identifier
        if !components.path.hasPrefix("/") {
            components.path.insert("/", at: components.path.startIndex)
        }
        
        self.topicURL = ValidatedURL(components: components)
    }
}

