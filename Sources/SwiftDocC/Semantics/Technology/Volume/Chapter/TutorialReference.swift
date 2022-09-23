/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A reference to a ``Tutorial`` or ``TutorialArticle`` by `URL`.
public final class TutorialReference: Semantic, AutomaticDirectiveConvertible {
    public var originalMarkup: BlockDirective
    
    /// The tutorial page or tutorial article to which this refers.
    @DirectiveArgumentWrapped(
        name: .custom("tutorial"),
        parseArgument: { _, argumentValue in
            guard let url = ValidatedURL(parsingAuthoredLink: argumentValue), !url.components.path.isEmpty else {
                return nil
            }
            return .unresolved(UnresolvedTopicReference(topicURL: url))
        }
    )
    public private(set) var topic: TopicReference
    
    static var keyPaths: [String : AnyKeyPath] = [
        "topic" : \TutorialReference._topic
    ]
    
    init(originalMarkup: BlockDirective, tutorial: TopicReference) {
        self.originalMarkup = originalMarkup
        super.init()
        
        self.topic = tutorial
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTutorialReference(self)
    }
}

