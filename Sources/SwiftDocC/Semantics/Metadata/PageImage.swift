/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
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
}
