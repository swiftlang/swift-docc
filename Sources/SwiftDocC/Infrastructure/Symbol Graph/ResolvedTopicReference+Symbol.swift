/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension ResolvedTopicReference {
    /// Creates a resolved topic reference out of a symbol reference.
    /// - Parameters:
    ///   - symbolReference: A reference to a symbol.
    ///   - moduleName: The module, to which the symbol belongs.
    ///   - bundle: A documentation bundle, to which the symbol belongs.
    init(symbolReference: SymbolReference, moduleName: String, bundle: DocumentationBundle) {
        let path = symbolReference.path.isEmpty ? "" : "/" + symbolReference.path
        
        self.init(
            bundleIdentifier: bundle.documentationRootReference.bundleIdentifier,
            path: bundle.documentationRootReference.appendingPath(moduleName + path).path,
            fragment: nil,
            sourceLanguages: symbolReference.interfaceLanguages
        )
    }
}
