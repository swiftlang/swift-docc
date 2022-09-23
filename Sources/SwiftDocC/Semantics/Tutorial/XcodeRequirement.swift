/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 An informal Xcode requirement for completing an instructional ``Tutorial``.
 */
public final class XcodeRequirement: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// Human readable title.
    @DirectiveArgumentWrapped
    public private(set) var title: String
    
    /// Domain where requirement applies.
    @DirectiveArgumentWrapped
    public private(set) var destination: URL
    
    static var keyPaths: [String : AnyKeyPath] = [
        "title"         : \XcodeRequirement._title,
        "destination"   : \XcodeRequirement._destination,
    ]
        
    init(originalMarkup: BlockDirective, title: String, destination: URL) {
        self.originalMarkup = originalMarkup
        super.init()
        self.title = title
        self.destination = destination
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitXcodeRequirement(self)
    }
}
