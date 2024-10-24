/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 Visits ``Semantic`` nodes and returns a result.
 
 > Note: This interface only provides requirements for visiting each kind of node. It does not require each visit method to descend into child nodes.
 */
public protocol SemanticVisitor {
    /** The result type returned when visiting a node. */
    associatedtype Result
    
    /**
     Visit any kind of ``Semantic`` node and return the result.
     */
    mutating func visit(_ semantic: Semantic) -> Result
    
    /**
    Visit a ``Code`` and return the result.
    */
    mutating func visitCode(_ code: Code) -> Result
    
    /**
     Visit a ``Step`` and return the result.
     */
    mutating func visitStep(_ step: Step) -> Result
    
    /**
     Visit a ``Steps`` and return the result.
     */
    mutating func visitSteps(_ steps: Steps) -> Result
    
    /**
     Visit a ``TutorialSection`` and return the result.
     */
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> Result
    
    /**
     Visit a ``Tutorial`` and return the result.
     */
    mutating func visitTutorial(_ tutorial: Tutorial) -> Result
    
    /**
     Visit a ``Intro`` and return the result.
     */
    mutating func visitIntro(_ intro: Intro) -> Result
    
    /**
     Visit an ``XcodeRequirement`` and return the result.
     */
    mutating func visitXcodeRequirement(_ xcodeRequirement: XcodeRequirement) -> Result

    /**
     Visit an ``Assessments`` section and return the result.
     */
    mutating func visitAssessments(_ assessments: Assessments) -> Result
    
    /**
     Visit a ``MultipleChoice`` assessment and return the result.
     */
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) -> Result
    
    /**
     Visit a ``Justification`` and return the result.
     */
    mutating func visitJustification(_ justification: Justification) -> Result
    
    /**
     Visit a ``Choice`` and return the result.
     */
    mutating func visitChoice(_ choice: Choice) -> Result
    
    /**
     Visit a ``MarkupContainer`` and return the result.
     */
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> Result
        
    /**
     Visit a ``TutorialTableOfContents`` and return the result.
     */
    mutating func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> Result

    @available(*, deprecated, renamed: "visitTutorialTableOfContents(_:)", message: "Use 'visitTutorialTableOfContents(_:)' instead. This deprecated API will be removed after 6.2 is released")
    mutating func visitTechnology(_ technology: TutorialTableOfContents) -> Result
    
    /**
     Visit an ``ImageMedia`` and return the result.
     */
    mutating func visitImageMedia(_ imageMedia: ImageMedia) -> Result
    
    /**
     Visit an ``VideoMedia`` and return the result.
     */
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> Result
    
    /**
     Visit a ``ContentAndMedia`` and return the result.
     */
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> Result
    
    /**
     Visit a ``Volume`` and return the result.
     */
    mutating func visitVolume(_ volume: Volume) -> Result
    
    /**
     Visit a ``Chapter`` and return the result.
     */
    mutating func visitChapter(_ chapter: Chapter) -> Result
    
    /**
     Visit a ``TutorialReference`` and return the result.
     */
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> Result

    /**
     Visit a ``Resources`` page and return the result.
     */
    mutating func visitResources(_ resources: Resources) -> Result
    
    /**
     Visit a ``Tile`` and return the result.
     */
    mutating func visitTile(_ tile: Tile) -> Result
    
    /**
     Visit a ``Comment`` and return the result.
     */
    mutating func visitComment(_ comment: Comment) -> Result
    
    mutating func visitTutorialArticle(_ article: TutorialArticle) -> Result
    
    mutating func visitStack(_ stack: Stack) -> Result
    
    mutating func visitSymbol(_ symbol: Symbol) -> Result
    
    mutating func visitArticle(_ article: Article) -> Result
    
    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> Result
}

extension SemanticVisitor {
    public mutating func visit(_ semantic: Semantic) -> Result {
        return semantic.accept(&self)
    }
}

@available(*, deprecated) // Remove this default implementation after 6.2 is released.
extension SemanticVisitor {
    // We need to provide a default implementation to avoid the breaking change of a new protocol requirement.
    mutating func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> Result {
        self.visitTechnology(tutorialTableOfContents)
    }
}
