/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A collection of questions about the concepts the documentation presents.
public final class Assessments: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// The multiple-choice questions that make up the assessment.
    @ChildDirective(requirements: .oneOrMore)
    public private(set) var questions: [MultipleChoice]
    
    override var children: [Semantic] {
        return questions
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "questions" : \Assessments._questions
    ]
    
    init(originalMarkup: BlockDirective, questions: [MultipleChoice]) {
        self.originalMarkup = originalMarkup
        super.init()
        self.questions = questions
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitAssessments(self)
    }
}
