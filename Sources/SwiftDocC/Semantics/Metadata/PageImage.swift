/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public final class PageImage: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    @DirectiveArgumentWrapped
    public private(set) var purpose: Purpose
    
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argumentValue)
        }
    )
    public private(set) var source: ResourceReference
    
    @DirectiveArgumentWrapped
    public private(set) var alt: String? = nil
    
    static var keyPaths: [String : AnyKeyPath] = [
        "purpose"   : \PageImage._purpose,
        "source"    : \PageImage._source,
        "alt"       : \PageImage._alt,
    ]
    
    /// The style of the display name for this symbol.
    public enum Purpose: String, CaseIterable, DirectiveArgumentValueConvertible {
        case icon
        
        case card
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }

    /// Don't use this outside of ``OutOfProcessReferenceResolver/entity(with:)`` .
    ///
    /// Directives aren't meant to be created from non-markup but the out-of-process resolver needs to create a ``PageImage`` to associate topic
    /// images with external pages. This is because DocC renderers external content in the local context. (rdar://78718811)
    /// https://github.com/apple/swift-docc/issues/468
    ///
    /// This is intentionally defined as an underscore prefixed static function instead of an initializer to make it less likely that it's used in other places.
    static func _make(purpose: Purpose, source: ResourceReference, alt: String?) -> PageImage {
        // FIXME: https://github.com/apple/swift-docc/issues/468
        return PageImage(
            originalMarkup: BlockDirective(name: "PageImage", children: []),
            purpose: purpose,
            source: source,
            alt: alt
        )
    }
    
    // This initializer only exist to be called by `_make` above.
    private init(originalMarkup: BlockDirective, purpose: Purpose, source: ResourceReference, alt: String?) {
        self.originalMarkup = originalMarkup
        super.init()
        self.purpose = purpose
        self.source = source
        self.alt = alt
    }
}
