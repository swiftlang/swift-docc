/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An interface for walking a ``Semantic`` tree without altering it.
public protocol SemanticWalker: SemanticVisitor where Result == Void {
    mutating func descendIntoChildren(of semantic: Semantic)
}

extension SemanticWalker {
    /// Walks the children of the given semantic node.
    public mutating func descendIntoChildren(of semantic: Semantic) {
        for child in semantic.children {
            visit(child)
        }
    }
    /// Visits a code block.
    mutating func visitCode(_ code: Code) { descendIntoChildren(of: code) }
    /// Visits a list of tutorial steps.
    mutating func visitSteps(_ steps: Steps) { descendIntoChildren(of: steps) }
    /// Visits a single step in a tutorial.
    mutating func visitStep(_ step: Step) { descendIntoChildren(of: step) }
    /// Visits a section of a tutorial.
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) { descendIntoChildren(of: tutorialSection) }
    /// Visits a tutorial.
    mutating func visitTutorial(_ tutorial: Tutorial) { descendIntoChildren(of: tutorial) }
    /// Visits an intro section in a tutorial.
    mutating func visitIntro(_ intro: Intro) { descendIntoChildren(of: intro) }
    /// Visits an Xcode requirement for a tutorial.
    mutating func visitXcodeRequirement(_ requirement: XcodeRequirement) { descendIntoChildren(of: requirement) }
    /// Visits a list of assessments.
    mutating func visitAssessments(_ assessments: Assessments) { descendIntoChildren(of: assessments) }
    /// Visits a multiple-choice question.
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) { descendIntoChildren(of: multipleChoice) }
    /// Visits an assesment justification.
    mutating func visitJustification(_ justification: Justification) { descendIntoChildren(of: justification) }
    /// Visits a single choice in a multiple-choice question.
    mutating func visitChoice(_ choice: Choice) { descendIntoChildren(of: choice) }
    /// Visits a node that contains markup.
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) { descendIntoChildren(of: markupContainer) }
    /// Vists a section that contains a list of resources.
    mutating func visitResources(_ resources: Resources) { descendIntoChildren(of: resources) }
    /// Visits a resources section tile.
    mutating func visitTile(_ tile: Tile) { descendIntoChildren(of: tile) }
    /// Visits a comment node.
    mutating func visitComment(_ comment: Comment) { descendIntoChildren(of: comment) }
    /// Visits a tutorials technology.
    mutating func visitTechnology(_ technology: Technology) { descendIntoChildren(of: technology) }
    /// Visits an image node.
    mutating func visitImageMedia(_ imageMedia: ImageMedia) { descendIntoChildren(of: imageMedia) }
    /// Visits a video node.
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) { descendIntoChildren(of: videoMedia) }
    /// Visits a media and content tuple.
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) { descendIntoChildren(of: contentAndMedia) }
    /// Visits a tutorials volume.
    mutating func visitVolume(_ volume: Volume) { descendIntoChildren(of: volume) }
    /// Visits a tutorials chapter.
    mutating func visitChapter(_ chapter: Chapter) { descendIntoChildren(of: chapter) }
    /// Visits a tutorial reference.
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) { descendIntoChildren(of: tutorialReference) }
    /// Visits a tutorial in article form.
    mutating func visitTutorialArticle(_ tutorialArticle: TutorialArticle) { descendIntoChildren(of: tutorialArticle) }
    /// Visits a content stack.
    mutating func visitStack(_ stack: Stack) { descendIntoChildren(of: stack) }
}
