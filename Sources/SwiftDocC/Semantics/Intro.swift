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
 An introductory section for instructional pages.
 */
public final class Intro: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// The title of the containing ``Tutorial``.
    @DirectiveArgumentWrapped
    public private(set) var title: String
    
    /// An optional video, displayed as a modal.
    @ChildDirective
    public private(set) var video: VideoMedia? = nil
    
    /// An optional standout image.
    @ChildDirective
    public private(set) var image: ImageMedia? = nil
    
    /// The child markup content.
    @ChildMarkup(numberOfParagraphs: .zeroOrMore)
    public private(set) var content: MarkupContainer
    
    static var keyPaths: [String : AnyKeyPath] = [
        "title"     : \Intro._title,
        "video"     : \Intro._video,
        "image"     : \Intro._image,
        "content"   : \Intro._content
    ]
    
    override var children: [Semantic] {
        return [content, image, video].compactMap { $0 }
    }
    
    init(originalMarkup: BlockDirective, title: String, image: ImageMedia?, video: VideoMedia?, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        super.init()
        
        self.content = content
        self.title = title
        self.image = image
        self.video = video
    }

    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitIntro(self)
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
