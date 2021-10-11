/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that checks the user's understanding of the concepts presented in a tutorial.
public struct TutorialAssessmentsRenderSection: RenderSection {
    public var kind: RenderSectionKind = .assessments
    
    /// The questions for this assessment section. 
    public var assessments: [Assessment]
    
    /// An identifier for this section of the page.
    ///
    /// The identifier can be used to construct an anchor link to this section of the page.
    public var anchor: String
    
    /// The display title for an assessments section.
    public static let title = "Check Your Understanding"
    
    /// A render-friendly representation of an assessment question.
    public struct Assessment: Codable, TextIndexing {
        /// The type of assessment question.
        ///
        /// The default value is `multiple-choice`.
        public var type = "multiple-choice"
        
        /// The title of the assessment.
        public var title: [RenderBlockContent]
        
        /// The content of this question.
        ///
        /// This content includes the phrasing of the question.
        public var content: [RenderBlockContent]?
        
        /// The possible answers to this multiple-choice question.
        public var choices: [Choice]
        
        /// A render-friendly representation of an answer to a
        /// multiple-choice assessment question.
        public struct Choice: Codable {
            /// The content of the choice.
            public var content: [RenderBlockContent]
            
            /// A Boolean value that determines whether this choice is correct.
            public var isCorrect: Bool
            
            /// An explanation of why this choice is correct or incorrect.
            public var justification: [RenderBlockContent]?
            
            /// Additional text that can be displayed if this choice is selected.
            public var reaction: String?
            
            /// Creates a new choice from the given parameters.
            ///
            /// - Parameters:
            ///   - content: The content of the choice.
            ///   - isCorrect: A Boolean value that determines whether this choice is correct.
            ///   - justification: An explanation of why this choice is correct or incorrect.
            ///   - reaction: Additional text that can be displayed if this choice is selected.
            public init(content: [RenderBlockContent], isCorrect: Bool, justification: [RenderBlockContent]?, reaction: String?) {
                self.content = content
                self.isCorrect = isCorrect
                self.justification = justification
            }
        }
        
        /// Creates a new multiple-choice assessment question from the given parameters.
        ///
        /// - Parameters:
        ///   - title: The title of the assessment.
        ///   - content: The content of the question.
        ///   - choices: The possible answers to this question.
        public init(title: [RenderBlockContent], content: [RenderBlockContent]?, choices: [Choice]) {
            self.title = title
            self.content = content
            self.choices = choices
        }
    }

    /// Creates a new assessment section from the given list of questions.
    ///
    /// - Parameters:
    ///   - assessments: The questions for this assessment section.
    ///   - anchor: An identifier for this assessment section.
    public init(assessments: [Assessment], anchor: String) {
        self.assessments = assessments
        self.anchor = anchor
    }
}


