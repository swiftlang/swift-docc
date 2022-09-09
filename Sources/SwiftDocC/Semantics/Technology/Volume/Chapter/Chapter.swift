/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A chapter containing ``Tutorial``s to complete.
public final class Chapter: Semantic, AutomaticDirectiveConvertible, Abstracted, Redirected {
    public let originalMarkup: BlockDirective
    
    /// The name of the chapter.
    @DirectiveArgumentWrapped
    public private(set) var name: String
    
    /// Content describing the contents of the chapter.
    @ChildMarkup(numberOfParagraphs: .zeroOrMore)
    public private(set) var content: MarkupContainer
    
    /// A companion media element next to the chapter's contents.
    @ChildDirective(requirements: .one)
    public private(set) var image: ImageMedia? = nil
    
    /// The list of tutorials and articles categorized under this chapter.
    ///
    /// > Note: Topics may be referenced by multiple chapters.
    @ChildDirective(requirements: .oneOrMore)
    public private(set) var topicReferences: [TutorialReference]
    
    static var keyPaths: [String : AnyKeyPath] = [
        "name"              : \Chapter._name,
        "content"           : \Chapter._content,
        "image"             : \Chapter._image,
        "topicReferences"   : \Chapter._topicReferences,
        "redirects"         : \Chapter._redirects,
    ]
    
    override var children: [Semantic] {
        return topicReferences
    }
    
    public var abstract: Paragraph? {
        return content.first as? Paragraph
    }
    
    @ChildDirective
    public private(set) var redirects: [Redirect]? = nil
    
    init(originalMarkup: BlockDirective, name: String, content: MarkupContainer, image: ImageMedia?, tutorialReferences: [TutorialReference], redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        super.init()
        
        self.name = name
        self.content = content
        self.image = image
        self.topicReferences = tutorialReferences
        self.redirects = redirects
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitChapter(self)
    }
}
