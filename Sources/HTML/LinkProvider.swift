/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation

/// A type that provides information about other pages, and on-page elements, that the rendered page references.
package protocol LinkProvider {
    /// Provide information about another page or on-page element, or `nil` if the other page can't be found.
    func element(for path: URL) -> LinkedElement?
    
    /// Provide information about an asset, or `nil` if the asset can't be found.
    func assetNamed(_ assetName: String) -> LinkedAsset?
}

package struct LinkedElement {
    /// The path within the output archive to the linked element.
    package var path: URL
    /// The names of the linked element.
    ///
    /// Articles, headings, tutorials, and similar pages have a ``Names/single/conceptual(_:)`` name.
    /// Symbols can either have a ``Names/single/symbol(_:)`` name or have different names for each language representation (``Names/languageSpecificSymbol``).
    package var names: Names
    
    package init(path: URL, names: Names) {
        self.path = path
        self.names = names
    }
    
    package enum Names {
        /// This element has the same name in all language representations
        case single(Name)
        /// This element is a symbol with different names in different languages.
        ///
        /// Because `@DisplayName` applies to all language representations, these language specific names are always the symbol's subheading declaration and should display in a monospaced font.
        case languageSpecificSymbol([String /* Language ID */: String])
    }
    package enum Name {
        /// The name refers to an article, heading, or custom `@DisplayName` and should display as regular text.
        case conceptual(String)
        /// The name refers to a symbol's subheading declaration and should display in a monospaced font.
        case symbol(String)
    }
}

package struct LinkedAsset {
    /// The path within the output archive to each image variant, by their light/dark style.
    package var images: [ColorStyle: [Int /* display scale*/: URL]]
    
    package init(images: [ColorStyle : [Int : URL]]) {
        self.images = images
    }
    
    package enum ColorStyle: String {
        case light, dark
    }
}
