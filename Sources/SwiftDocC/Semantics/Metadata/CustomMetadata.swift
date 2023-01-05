/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that accepts an arbitary key/valye pair and emits it into the metadata of the page
///
/// It accepts following parameters:
///
/// key- a key to identify a piece of metadata
/// value- the value for the metadata
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```
/// @Metadata {
///    @CustomMetadata(key: "country", value: "Belgium")
/// }
/// ```
public final class CustomMetadata: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// A key to identify a piece of metadata
    @DirectiveArgumentWrapped
    public var key: String
    
    /// value of the metadata
    @DirectiveArgumentWrapped
    public var value: String
    
    static var hiddenFromDocumentation = true
    
    static var keyPaths: [String : AnyKeyPath] = [
        "key" : \CustomMetadata._key,
        "value"  : \CustomMetadata._value,
    ]
    

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

