/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A block filled with a video.
public final class VideoMedia: Semantic, Media, AutomaticDirectiveConvertible {
    public static let directiveName = "Video"
    
    public let originalMarkup: BlockDirective
    
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argumentValue)
        }
    )
    public private(set) var source: ResourceReference
    
    /// An image to be shown when the video isn't playing.
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argumentValue)
        }
    )
    public private(set) var poster: ResourceReference? = nil
    
    static var keyPaths: [String : AnyKeyPath] = [
        "source" : \VideoMedia._source,
        "poster" : \VideoMedia._poster,
    ]
    
    init(originalMarkup: BlockDirective, source: ResourceReference, poster: ResourceReference?) {
        self.originalMarkup = originalMarkup
        super.init()
        self.poster = poster
        self.source = source
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitVideoMedia(self)
    }
}

