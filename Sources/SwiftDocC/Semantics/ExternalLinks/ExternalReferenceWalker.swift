/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 Walks a `Semantic` tree and collects any and all links external to the given bundle.
 
 Visits semantic nodes and descends into all their children that do have (indirectly or directly) content.
 When visiting a node that directly contains markup content visits the markup with an instance of ``ExternalMarkupReferenceWalker``
 which in turn walks the markup tree and collects external links.
 
 Once the visitor has finished visiting the semantic node and the relevant children all
 encountered external links are collected in ``collectedExternalReferences``.
 
 > Warning: This type needs to keep up to date with the semantic objects it walks. When changing the API design
   for types like ``Symbol`` or ``Article``, if the changes include new pieces of content that might contain external links,
   this type needs to be updated to walk those new pieces of content as well.
 */
struct ExternalReferenceWalker: SemanticVisitor {
    typealias Result = Void

    /// A markup walker to use for collecting links from markup elements.
    private var markupResolver: ExternalMarkupReferenceWalker
    
    /// Collected unresolved external references, grouped by the bundle ID.
    var collectedExternalReferences: [DocumentationBundle.Identifier: [UnresolvedTopicReference]] {
        return markupResolver.collectedExternalLinks.mapValues { links in
            links.map(UnresolvedTopicReference.init(topicURL:))
        }
    }
    
    /// Creates a new semantic walker that collects links to other documentation sources.
    /// - Parameter localBundleID: The local bundle ID, used to identify and skip absolute fully qualified local links.
    init(localBundleID: DocumentationBundle.Identifier) {
        self.markupResolver = ExternalMarkupReferenceWalker(localBundleID: localBundleID)
    }
    
    mutating func visitCode(_ code: Code) { }
    
    mutating func visitSteps(_ steps: Steps) {
        for content in steps.content {
            visit(content)
        }
    }
    
    mutating func visitStep(_ step: Step) {
        visit(step.content)
        visit(step.caption)
    }
        
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) {
        visitMarkupLayouts(tutorialSection.introduction)
        if let stepsContent = tutorialSection.stepsContent {
            visitSteps(stepsContent)
        }
    }
    
    mutating func visitTutorial(_ tutorial: Tutorial) {
        visit(tutorial.intro)
        for section in tutorial.sections {
            visit(section)
        }
        if let assessments = tutorial.assessments {
            visit(assessments)
        }
    }
    
    mutating func visitIntro(_ intro: Intro) {
        visit(intro.content)
    }
    
    mutating func visitXcodeRequirement(_ xcodeRequirement: XcodeRequirement) { }
    
    mutating func visitAssessments(_ assessments: Assessments) {
        for question in assessments.questions {
            visit(question)
        }
    }
    
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) {
        visit(multipleChoice.questionPhrasing)
        visit(multipleChoice.content)
        for choice in multipleChoice.choices {
            visit(choice)
        }
    }
    
    mutating func visitJustification(_ justification: Justification) {
        visit(justification.content)
    }
    
    mutating func visitChoice(_ choice: Choice) {
        visit(choice.content)
        visit(choice.justification)
    }
    
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) {
        for element in markupContainer.elements {
            markupResolver.visit(element)
        }
    }
    
    mutating func visitMarkup(_ markup: any Markup) {
        visitMarkupContainer(MarkupContainer(markup))
    }

    mutating func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> Void {
        visit(tutorialTableOfContents.intro)
        for volume in tutorialTableOfContents.volumes {
            visit(volume)
        }
        if let resources = tutorialTableOfContents.resources {
            visit(resources)
        }
    }
    
    mutating func visitImageMedia(_ imageMedia: ImageMedia) { }
    
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) { }
    
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) {
        visit(contentAndMedia.content)
    }
    
    mutating func visitVolume(_ volume: Volume) {
        if let content = volume.content {
            visit(content)
        }
        for chapter in volume.chapters {
            visit(chapter)
        }
    }
    
    mutating func visitChapter(_ chapter: Chapter) {
        visit(chapter.content)
        for topicReference in chapter.topicReferences {
            visit(topicReference)
        }
    }
    
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) { }

    mutating func visitResources(_ resources: Resources) {
        visitMarkupContainer(resources.content)
        for tile in resources.tiles {
            visitTile(tile)
        }
    }
    
    mutating func visitTile(_ tile: Tile) {
        visitMarkupContainer(tile.content)
    }
    
    mutating func visitTutorialArticle(_ article: TutorialArticle) {
        if let intro = article.intro {
            visitIntro(intro)
        }
        visitMarkupLayouts(article.content)
        if let assessments = article.assessments {
            visit(assessments)
        }
    }
    
    mutating func visitArticle(_ article: Article) {
        if let abstractSection = article.abstractSection {
            visitMarkup(abstractSection.paragraph)
        }
        if let discussion = article.discussion {
            for markup in discussion.content {
                visitMarkup(markup)
            }
        }
        if let topics = article.topics {
            for markup in topics.content {
                visitMarkup(markup)
            }
        }
        if let seeAlso = article.seeAlso {
            for markup in seeAlso.content {
                visitMarkup(markup)
            }
        }
        if let deprecationSummary = article.deprecationSummary {
            visitMarkupContainer(deprecationSummary)
        }
    }

    private mutating func visitMarkupLayouts(_ markupLayouts: some Sequence<MarkupLayout>) {
        for content in markupLayouts {
            switch content {
            case .markup(let markup): visitMarkupContainer(markup)
            case .contentAndMedia(let contentAndMedia): visitContentAndMedia(contentAndMedia)
            case .stack(let stack): visitStack(stack)
            }
        }
    }
    
    mutating func visitStack(_ stack: Stack) {
        for contentAndMedia in stack.contentAndMedia {
            visitContentAndMedia(contentAndMedia)
        }
    }

    mutating func visitComment(_ comment: Comment) { }

    mutating func visitSection(_ section: any Section) {
        for markup in section.content { visitMarkup(markup) }
    }

    mutating func visitSectionVariants(_ variants: DocumentationDataVariants<some Section>) {
        for variant in variants.allValues.map(\.variant) {
            visitSection(variant)
        }
    }

    mutating func visitSymbol(_ symbol: Symbol) {

        visitSectionVariants(symbol.abstractSectionVariants)
        visitSectionVariants(symbol.discussionVariants)
        visitSectionVariants(symbol.topicsVariants)
        visitSectionVariants(symbol.seeAlsoVariants)
        visitSectionVariants(symbol.returnsSectionVariants)
        visitSectionVariants(symbol.deprecatedSummaryVariants)

        for parametersSection in symbol.parametersSectionVariants.allValues.map(\.variant) {
            for parameter in parametersSection.parameters {
                for markup in parameter.contents { visitMarkup(markup) }
            }
        }

        if let dictionaryKeysSection = symbol.dictionaryKeysSection {
            for dictionaryKeys in dictionaryKeysSection.dictionaryKeys {
                for markup in dictionaryKeys.contents { visitMarkup(markup) }
            }
        }

        if let httpParametersSection = symbol.httpParametersSection {
            for param in httpParametersSection.parameters {
                for markup in param.contents { visitMarkup(markup) }
            }
        }

        if let httpResponsesSection = symbol.httpResponsesSection {
            for param in httpResponsesSection.responses {
                for markup in param.contents { visitMarkup(markup) }
            }
        }

        if let httpBodySection = symbol.httpBodySection {
            for markup in httpBodySection.body.contents { visitMarkup(markup) }
            for parameter in httpBodySection.body.parameters {
                for markup in parameter.contents { visitMarkup(markup) }
            }
        }

        if let possibleValuesSection = symbol.possibleValuesSection {
            for possibleValue in possibleValuesSection.possibleValues {
                for markup in possibleValue.contents { visitMarkup(markup) }
            }
        }
    }

    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) {
        visit(summary.content)
    }
}
