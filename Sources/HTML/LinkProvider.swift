/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation
package import Markdown

/// A type that provides information about other pages, and on-page elements, that the rendered page references.
package protocol LinkProvider {
    /// Provide information about another page or on-page element, or `nil` if the other page can't be found.
    func element(for path: URL) -> LinkedElement?
    
    /// Provide the path for a symbol based on its unique identifier, or `nil` if the other symbol with that identifier can't be found.
    func pathForSymbolID(_ usr: String) -> URL?
    
    /// Provide information about an asset, or `nil` if the asset can't be found.
    func assetNamed(_ assetName: String) -> LinkedAsset?
}

package struct LinkedElement {
    /// The path within the output archive to the linked element.
    package var path: URL
    /// The names of the linked element, for display when the element is referenced in inline content.
    ///
    /// Articles, headings, tutorials, and similar pages have a ``Names/single/conceptual(_:)`` name.
    /// Symbols can either have a ``Names/single/symbol(_:)`` name or have different names for each language representation (``Names/languageSpecificSymbol``).
    package var names: Names
    /// The subheadings of the linked element, for display when the element is referenced in either a Topics section, See Also section, or in a `@Links` directive.
    ///
    /// Articles, headings, tutorials, and similar pages have a ``Names/single/conceptual(_:)`` name.
    /// Symbols can either have a ``Names/single/symbol(_:)`` name or have different names for each language representation (``Names/languageSpecificSymbol``).
    package var subheadings: Subheadings
    /// The abstract of the page—to be displayed in either a Topics section, See Also section, or in a `@Links` directive—or `nil` if the linked element doesn't have an abstract.
    package var abstract: Paragraph?

    package init(path: URL, names: Names, subheadings: Subheadings, abstract: Paragraph?) {
        self.path = path
        self.names = names
        self.subheadings = subheadings
        self.abstract = abstract
    }
    
    /// The single name or language-specific names to use when referring to a linked element in inline content.
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
    
    /// The single subheading or language-specific subheadings to use when referring to a linked element in either a Topics section, See Also section, or in a `@Links` directive.
    package enum Subheadings {
        /// This element has the same name in all language representations
        case single(Subheading)
        /// This element is a symbol with different names in different languages.
        ///
        /// Because `@DisplayName` applies to all language representations, these language specific names are always the symbol's subheading declaration and should display in a monospaced font.
        case languageSpecificSymbol([String /* Language ID */: [SymbolNameFragment]])
    }
    package enum Subheading {
        /// The name refers to an article, heading, or custom `@DisplayName` and should display as regular text.
        case conceptual(String)
        /// The name refers to a symbol's subheading declaration and should display in a monospaced font.
        case symbol([SymbolNameFragment])
    }
    
    /// A fragment in a symbol's name
    package struct SymbolNameFragment {
        /// The textual spelling of this fragment
        package var text: String
        /// The kind of fragment
        package var kind: Kind
        
        /// The display kind of a single  symbol name fragment
        package enum Kind: String {
            case identifier, decorator
        }
        
        package init(text: String, kind: Kind) {
            self.text = text
            self.kind = kind
        }
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
