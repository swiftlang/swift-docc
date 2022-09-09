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
 One of possibly many choices in a ``MultipleChoice`` question.
 */
public final class Choice: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// `true` if this choice is a correct one; there can be multiple correct choices.
    @DirectiveArgumentWrapped
    public private(set) var isCorrect: Bool
    
    /// The markup content of the choice, what the user examines to decide to select this choice.
    @ChildMarkup(numberOfParagraphs: .zeroOrMore)
    public private(set) var content: MarkupContainer
    
    /// Optional image illustrating the answer.
    @ChildDirective
    public private(set) var image: ImageMedia? = nil
    
    /// A justification as to whether this choice is correct.
    @ChildDirective
    public private(set) var justification: Justification
    
    static var keyPaths: [String : AnyKeyPath] = [
        "isCorrect"         : \Choice._isCorrect,
        "content"           : \Choice._content,
        "image"             : \Choice._image,
        "justification"     : \Choice._justification,
    ]
    
    override var children: [Semantic] {
        var elements: [Semantic] = [content]
        if let image = image {
            elements.append(image)
        }
        elements.append(justification)
        return elements
    }
    
    init(originalMarkup: BlockDirective, isCorrect: Bool, content: MarkupContainer, image: ImageMedia?, justification: Justification) {
        self.originalMarkup = originalMarkup
        super.init()
        
        self.content = content
        self.isCorrect = isCorrect
        self.image = image
        self.justification = justification
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    func validate(
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) -> Bool {
        if content.isEmpty && image == nil {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: originalMarkup.range, identifier: "org.swift.docc.\(Choice.self).Empty", summary: "\(Choice.directiveName.singleQuoted) answer content must consist of a paragraph, code block, or \(ImageMedia.directiveName.singleQuoted) directive")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        return true
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitChoice(self)
    }
}
