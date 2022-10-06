/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that accepts an arbitary key/valye pair and emits it into the metadata of a created RenderJSON descibing the page.
///
/// It accepts following parameters:
///
/// key- a key to identify a piece of metadata
/// value- the value for the metadataa
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```
/// @Metadata {
///    @CustomMetadata(key: "supported-platforms", value: "iphone,ipados,macos")
/// }
/// ```
public final class CustomMetadata: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// A key to identify a piece of metadata
    @DirectiveArgumentWrapped(name: .unnamed)
    public var key: String
    
    /// value of the metadata
    @DirectiveArgumentWrapped
    public var value: String? = nil
    
    static var keyPaths: [String : AnyKeyPath] = [
        "key" : \CustomMetadata._key,
        "value"  : \CustomMetadata._value,
    ]
    

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

