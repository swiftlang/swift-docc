/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

func unresolvedReferenceProblem(reference: TopicReference, source: URL?, range: SourceRange?, severity: DiagnosticSeverity, uncuratedArticleMatch: URL?, underlyingErrorMessage: String) -> Problem {
    let notes = uncuratedArticleMatch.map {
        [DiagnosticNote(source: $0, range: SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 1, source: nil), message: "This article was found but is not available for linking because it's uncurated")]
    } ?? []
    
    let diagnostic = Diagnostic(source: source, severity: severity, range: range, identifier: "org.swift.docc.unresolvedTopicReference", summary: "Topic reference \(reference.description.singleQuoted) couldn't be resolved. \(underlyingErrorMessage)", notes: notes)
    return Problem(diagnostic: diagnostic, possibleSolutions: [])
}

func unresolvedResourceProblem(
    resource: ResourceReference,
    expectedType: DocumentationContext.AssetType? = nil,
    source: URL?,
    range: SourceRange?,
    severity: DiagnosticSeverity
) -> Problem {
    let summary: String
    let identifier: String
    if let expectedType = expectedType {
        identifier = "org.swift.docc.unresolvedResource.\(expectedType)"
        summary = "\(expectedType) resource \(resource.path.singleQuoted) couldn't be found"
    } else {
        identifier = "org.swift.docc.unresolvedResource"
        summary = "Resource \(resource.path.singleQuoted) couldn't be found"
    }
    
    let diagnostic = Diagnostic(
        source: source,
        severity: severity,
        range: range,
        identifier: identifier,
        summary: summary
    )
    return Problem(diagnostic: diagnostic, possibleSolutions: [])
}

/**
 Rewrites a `Semantic` tree by attempting to resolve `.unresolved(UnresolvedTopicReference)` references using a `DocumentationContext`.
 */
struct ReferenceResolver: SemanticVisitor {
    typealias Result = Semantic

    /// The context to use to resolve references.
    var context: DocumentationContext
    
    /// The bundle in which visited documents reside.
    var bundle: DocumentationBundle
    
    /// The source document being analyzed.
    var source: URL?
    
    /// Problems found while trying to resolve references.
    var problems = [Problem]()
    
    var rootReference: ResolvedTopicReference
    
    /// If the documentation is inherited, the reference of the parent symbol.
    var inheritanceParentReference: ResolvedTopicReference?
    
    init(context: DocumentationContext, bundle: DocumentationBundle, source: URL?, rootReference: ResolvedTopicReference? = nil, inheritanceParentReference: ResolvedTopicReference? = nil) {
        self.context = context
        self.bundle = bundle
        self.source = source
        self.rootReference = rootReference ?? bundle.rootReference
        self.inheritanceParentReference = inheritanceParentReference
    }
    
    mutating func resolve(_ reference: TopicReference, in parent: ResolvedTopicReference, range: SourceRange?, severity: DiagnosticSeverity) -> TopicReferenceResolutionResult {
        switch context.resolve(reference, in: parent) {
        case .success(let resolved):
            return .success(resolved)
            
        case let .failure(unresolved, errorMessage):
            // FIXME: Provide near-miss suggestion here. The user is likely to make mistakes with capitalization because of character input.
            let uncuratedArticleMatch = context.uncuratedArticles[bundle.documentationRootReference.appendingPathOfReference(unresolved)]?.source
            problems.append(unresolvedReferenceProblem(reference: reference, source: source, range: range, severity: severity, uncuratedArticleMatch: uncuratedArticleMatch, underlyingErrorMessage: errorMessage))
            return .failure(unresolved, errorMessage: errorMessage)
        }
    }
    
    /**
    Returns a ``Problem`` if the resource cannot be found; otherwise `nil`.
    */
    func resolve(resource: ResourceReference, range: SourceRange?, severity: DiagnosticSeverity) -> Problem? {
        if !context.resourceExists(with: resource) {
            return unresolvedResourceProblem(resource: resource, source: source, range: range, severity: severity)
        } else {
            return nil
        }
    }
    
    mutating func visitCode(_ code: Code) -> Semantic {
        return code
    }
    
    mutating func visitSteps(_ steps: Steps) -> Semantic {
        let newStepsContent = steps.content.map { visit($0) }
        return Steps(originalMarkup: steps.originalMarkup, content: newStepsContent)
    }
    
    mutating func visitStep(_ step: Step) -> Semantic {
        let newContent = visit(step.content) as! MarkupContainer
        let newCaption = visit(step.caption) as! MarkupContainer
        if let media = step.media, let problem = resolve(resource: media.source, range: step.originalMarkup.range, severity: .warning) {
            problems.append(problem)
        }
        if let code = step.code, let problem = resolve(resource: code.fileReference, range: step.originalMarkup.range, severity: .warning) {
            problems.append(problem)
        }
        return Step(originalMarkup: step.originalMarkup, media: step.media, code: step.code, content: newContent, caption: newCaption)
    }
        
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> Semantic {
        let newIntroduction = visitMarkupLayouts(tutorialSection.introduction)
        let newStepsContent: Steps? = tutorialSection.stepsContent.map { (visitSteps($0) as! Steps) }
        return TutorialSection(originalMarkup: tutorialSection.originalMarkup, title: tutorialSection.title, introduction: newIntroduction, stepsContent: newStepsContent, redirects: tutorialSection.redirects)
    }
    
    mutating func visitTutorial(_ tutorial: Tutorial) -> Semantic {
        let newRequirements = tutorial.requirements.map { visit($0) } as! [XcodeRequirement]
        let newIntro = visit(tutorial.intro) as! Intro
        let newSections = tutorial.sections.map { visit($0) } as! [TutorialSection]
        let newAssessments = tutorial.assessments.map { visit($0) as! Assessments } 
        let newCallToActionImage = tutorial.callToActionImage.map { visit($0) as! ImageMedia }
        
        // Change the context of the project file to `download`
        if let projectFiles = tutorial.projectFiles,
            var resolvedDownload = context.resolveAsset(named: projectFiles.path, in: bundle.rootReference) {
            resolvedDownload.context = .download
            context.updateAsset(named: projectFiles.path, asset: resolvedDownload, in: bundle.rootReference)
        }
        
        return Tutorial(originalMarkup: tutorial.originalMarkup, durationMinutes: tutorial.durationMinutes, projectFiles: tutorial.projectFiles, requirements: newRequirements, intro: newIntro, sections: newSections, assessments: newAssessments, callToActionImage: newCallToActionImage, redirects: tutorial.redirects)
    }
    
    mutating func visitIntro(_ intro: Intro) -> Semantic {
        let newImage = intro.image.map { visit($0) } as! ImageMedia?
        let newVideo = intro.video.map { visit($0) } as! VideoMedia?
        let newContent = visit(intro.content) as! MarkupContainer
        return Intro(originalMarkup: intro.originalMarkup, title: intro.title, image: newImage, video: newVideo, content: newContent)
    }
    
    mutating func visitXcodeRequirement(_ xcodeRequirement: XcodeRequirement) -> Semantic {
        return xcodeRequirement
    }
    
    mutating func visitAssessments(_ assessments: Assessments) -> Semantic {
        let newQuestions = assessments.questions.map { visit($0) } as! [MultipleChoice]
        return Assessments(originalMarkup: assessments.originalMarkup, questions: newQuestions)
    }
    
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) -> Semantic {
        let newPhrasing = visit(multipleChoice.questionPhrasing) as! MarkupContainer
        let newContent = visit(multipleChoice.content) as! MarkupContainer
        let newChoices = multipleChoice.choices.map { visit($0) } as! [Choice]
        return MultipleChoice(originalMarkup: multipleChoice.originalMarkup, questionPhrasing: newPhrasing, content: newContent, image: multipleChoice.image, choices: newChoices)
    }
    
    mutating func visitJustification(_ justification: Justification) -> Semantic {
        let newContent = visit(justification.content) as! MarkupContainer
        return Justification(originalMarkup: justification.originalMarkup, content: newContent, reaction: justification.reaction)
    }
    
    mutating func visitChoice(_ choice: Choice) -> Semantic {
        let newContent = visit(choice.content) as! MarkupContainer
        let newJustification = visit(choice.justification) as! Justification
        return Choice(originalMarkup: choice.originalMarkup, isCorrect: choice.isCorrect, content: newContent, image: choice.image, justification: newJustification)
    }
    
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> Semantic {
        var markupResolver = MarkupReferenceResolver(context: context, bundle: bundle, source: source, rootReference: rootReference)
        let parent = inheritanceParentReference
        let context = self.context
        
        markupResolver.problemForUnresolvedReference = { unresolved, source, range, fromSymbolLink, underlyingErrorMessage -> Problem? in
            // Verify we have all the information about the location of the source comment
            // and the symbol that the comment is inherited from.
            if let parent = parent, let range = range,
                let symbol = try? context.entity(with: parent).symbol,
                let docLines = symbol.docComment,
                let docStartLine = docLines.lines.first?.range?.start.line,
                let docStartColumn = docLines.lines.first?.range?.start.character {
                
                switch context.resolve(.unresolved(unresolved), in: parent, fromSymbolLink: fromSymbolLink) {
                    case .success(let resolved):
                        
                        // Make the range for the suggested replacement.
                        let start = SourceLocation(line: docStartLine + range.lowerBound.line, column: docStartColumn + range.lowerBound.column, source: range.lowerBound.source)
                        let end = SourceLocation(line: docStartLine + range.upperBound.line, column: docStartColumn + range.upperBound.column, source: range.upperBound.source)
                        let replacementRange = SourceRange(uncheckedBounds: (lower: start, upper: end))
                        
                        // Return a warning with a suggested change that replaces the relative link with an absolute one.
                        return Problem(diagnostic: Diagnostic(source: source,
                            severity: .warning, range: range,
                            identifier: "org.swift.docc.UnresolvableLinkWhenInherited",
                            summary: "This documentation block is inherited by other symbols where \(unresolved.topicURL.absoluteString.singleQuoted) fails to resolve."),
                            possibleSolutions: [
                                Solution(summary: "Use an absolute link path.", replacements: [
                                    Replacement(range: replacementRange, replacement: "<doc:\(resolved.path)>")
                                ])
                            ])
                    default: break
                }
            }
            return nil
        }
        
        let newElements = markupContainer.elements.compactMap { markupResolver.visit($0) }
        problems.append(contentsOf: markupResolver.problems)
        return MarkupContainer(newElements)
    }
    
    mutating func visitMarkup(_ markup: Markup) -> Markup {
        // Wrap in a markup container and the first child of the result.
        return (visitMarkupContainer(MarkupContainer(markup)) as! MarkupContainer).elements.first!
    }
    
    mutating func visitTechnology(_ technology: Technology) -> Semantic {
        let newIntro = visit(technology.intro) as! Intro
        let newVolumes = technology.volumes.map { visit($0) } as! [Volume]
        let newResources = technology.resources.map { visit($0) as! Resources }
        return Technology(originalMarkup: technology.originalMarkup, name: technology.name, intro: newIntro, volumes: newVolumes, resources: newResources, redirects: technology.redirects)
    }
    
    mutating func visitImageMedia(_ imageMedia: ImageMedia) -> Semantic {
        if let problem = resolve(resource: imageMedia.source, range: imageMedia.originalMarkup.range, severity: .warning) {
            problems.append(problem)
        }
        return imageMedia
    }
    
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> Semantic {
        if let problem = resolve(resource: videoMedia.source, range: videoMedia.originalMarkup.range, severity: .warning) {
            problems.append(problem)
        }
        return videoMedia
    }
    
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> Semantic {
        let newContent = visit(contentAndMedia.content) as! MarkupContainer
        let newMedia = contentAndMedia.media.map { visit($0) } as! Media?
        return ContentAndMedia(originalMarkup: contentAndMedia.originalMarkup, title: contentAndMedia.title, layout: contentAndMedia.layout, eyebrow: contentAndMedia.eyebrow, content: newContent, media: newMedia, mediaPosition: contentAndMedia.mediaPosition)
    }
    
    mutating func visitVolume(_ volume: Volume) -> Semantic {
        let newContent = volume.content.map { visit($0) as! MarkupContainer }
        let image = volume.image.map { visit($0) as! ImageMedia }
        let newChapters = volume.chapters.map { visit($0) } as! [Chapter]
        return Volume(originalMarkup: volume.originalMarkup, name: volume.name, image: image, content: newContent, chapters: newChapters, redirects: volume.redirects)
    }
    
    mutating func visitChapter(_ chapter: Chapter) -> Semantic {
        let newContent = visit(chapter.content) as! MarkupContainer
        let newImage = chapter.image.map { visit($0) as! ImageMedia }
        let newTutorialReferences = chapter.topicReferences.map { visit($0) } as! [TutorialReference]
        
        var uniqueReferences = Set<TopicReference>()
        let newTutorialReferencesWithoutDupes = newTutorialReferences.filter { newTutorialReference in
            guard !uniqueReferences.contains(newTutorialReference.topic) else {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: newTutorialReference.originalMarkup.range, identifier: "org.swift.docc.\(Chapter.self).Duplicate\(TutorialReference.self)", summary: "Duplicate \(TutorialReference.directiveName.singleQuoted) directive refers to \(newTutorialReference.topic.description.singleQuoted)")
                let solutions = newTutorialReference.originalMarkup.range.map {
                    return [Solution(summary: "Remove duplicate \(TutorialReference.directiveName.singleQuoted) directive", replacements: [
                        Replacement(range: $0, replacement: "")
                    ])]
                } ?? []
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
                return false
            }
            uniqueReferences.insert(newTutorialReference.topic)
            return true
        }

        return Chapter(originalMarkup: chapter.originalMarkup, name: chapter.name, content: newContent, image: newImage, tutorialReferences: newTutorialReferencesWithoutDupes, redirects: chapter.redirects)
    }
    
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> Semantic {
        // This should always be an absolute topic URL rooted at the bundle, as there isn't necessarily one parent of a tutorial.
        // i.e. doc:/${SOME_TECHNOLOGY}/${PROJECT} or doc://${BUNDLE_ID}/${SOME_TECHNOLOGY}/${PROJECT}
        switch tutorialReference.topic {
        case .unresolved:
            let maybeResolved = resolve(tutorialReference.topic, in: bundle.technologyTutorialsRootReference,
                                        range: tutorialReference.originalMarkup.range,
                                        severity: .warning)
            return TutorialReference(originalMarkup: tutorialReference.originalMarkup, tutorial: .resolved(maybeResolved))
        case .resolved:
            return tutorialReference
        }
    }

    mutating func visitResources(_ resources: Resources) -> Semantic {
        let newContent = visitMarkupContainer(resources.content) as! MarkupContainer
        let newTiles = resources.tiles.map { visitTile($0) as! Tile }
        return Resources(originalMarkup: resources.originalMarkup, content: newContent, tiles: newTiles, redirects: resources.redirects)
    }
    
    mutating func visitTile(_ tile: Tile) -> Semantic {
        let newContent = visitMarkupContainer(tile.content) as! MarkupContainer
        return Tile(originalMarkup: tile.originalMarkup, identifier: tile.identifier, title: tile.title, destination: tile.destination, content: newContent)
    }
    
    mutating func visitTutorialArticle(_ article: TutorialArticle) -> Semantic {
        let newIntro: Intro?
        if let intro = article.intro {
            newIntro = (visitIntro(intro) as! Intro)
        } else {
            newIntro = nil
        }
        
        let newContent = visitMarkupLayouts(article.content)
        
        let newAssessments = article.assessments.map { visit($0) as! Assessments }
        
        let newCallToActionImage = article.callToActionImage.map { visit($0) as! ImageMedia }
  
        return TutorialArticle(originalMarkup: article.originalMarkup, durationMinutes: article.durationMinutes, intro: newIntro, content: newContent, assessments: newAssessments, callToActionImage: newCallToActionImage, landmarks: article.landmarks, redirects: article.redirects)
    }
    
    mutating func visitArticle(_ article: Article) -> Semantic {
        let newAbstract = article.abstractSection.map {
            AbstractSection(paragraph: visitMarkup($0.paragraph) as! Paragraph)
        }
        let newDiscussion = article.discussion.map {
            DiscussionSection(content: $0.content.map { visitMarkup($0) })
        }
        let newTopics = article.topics.map { topic -> TopicsSection in
            return TopicsSection(content: topic.content.map { visitMarkup($0) }, originalLinkRangesByGroup: topic.originalLinkRangesByGroup)
        }
        let newSeeAlso = article.seeAlso.map {
            SeeAlsoSection(content: $0.content.map { visitMarkup($0) })
        }
        let newDeprecationSummary = article.deprecationSummary.flatMap {
            visitMarkupContainer($0) as? MarkupContainer
        }

        return Article(
            title: article.title,
            abstractSection: newAbstract,
            discussion: newDiscussion,
            topics: newTopics,
            seeAlso: newSeeAlso,
            deprecationSummary: newDeprecationSummary,
            metadata: article.metadata,
            redirects: article.redirects,
            automaticTaskGroups: article.automaticTaskGroups
        )
    }

    private mutating func visitMarkupLayouts<MarkupLayouts: Sequence>(_ markupLayouts: MarkupLayouts) -> [MarkupLayout] where MarkupLayouts.Element == MarkupLayout {
        return markupLayouts.map { content in
            switch content {
            case .markup(let markup): return .markup(visitMarkupContainer(markup) as! MarkupContainer)
            case .contentAndMedia(let contentAndMedia): return .contentAndMedia(visitContentAndMedia(contentAndMedia) as! ContentAndMedia)
            case .stack(let stack): return .stack(visitStack(stack) as! Stack)
            }
        }
    }
    
    mutating func visitStack(_ stack: Stack) -> Semantic {
        let newElements = stack.contentAndMedia.map { visitContentAndMedia($0) as! ContentAndMedia }
        
        return Stack(originalMarkup: stack.originalMarkup, contentAndMedias: newElements)
    }

    /// Returns a name that's suitable to use as a title for a given node.
    ///
    /// - Note: For symbols, this isn't the full declaration since that contains keywords and other characters that makes it less suitable as a title.
    ///
    /// - Parameter node: The node to return the title for.
    /// - Returns: The "title" for `node`.
    static func title(forNode node: DocumentationNode) -> String {
        switch node.name {
        case .conceptual(let documentTitle):
            return documentTitle
        case .symbol(let declaration):
            return node.symbol?.names.title ?? declaration.tokens.map { $0.description }.joined(separator: " ")
        }
    }
    
    mutating func visitComment(_ comment: Comment) -> Semantic {
        return comment
    }
    
    mutating func visitSymbol(_ symbol: Symbol) -> Semantic {
        let newAbstractVariants = symbol.abstractSectionVariants.map {
            AbstractSection(paragraph: visitMarkup($0.paragraph) as! Paragraph)
        }
        let newDiscussionVariants = symbol.discussionVariants.map {
            DiscussionSection(content: $0.content.map { visitMarkup($0) })
        }
        let newTopicsVariants = symbol.topicsVariants.map { topic -> TopicsSection in
            return TopicsSection(content: topic.content.map { visitMarkup($0) }, originalLinkRangesByGroup: topic.originalLinkRangesByGroup)
        }
        let newSeeAlsoVariants = symbol.seeAlsoVariants.map {
            SeeAlsoSection(content: $0.content.map { visitMarkup($0) })
        }
        let newReturnsVariants = symbol.returnsSectionVariants.map {
            ReturnsSection(content: $0.content.map { visitMarkup($0) })
        }
        let newParametersVariants = symbol.parametersSectionVariants.map { parametersSection -> ParametersSection in
            let parameters = parametersSection.parameters.map {
                Parameter(name: $0.name, contents: $0.contents.map { visitMarkup($0) })
            }
            return ParametersSection(parameters: parameters)
        }
        
        // It's important to carry over aggregate data like the merged declarations
        // or the merged default implementations to the new `Symbol` instance.
        
        return Symbol(
            kindVariants: symbol.kindVariants,
            titleVariants: symbol.titleVariants,
            subHeadingVariants: symbol.subHeadingVariants,
            navigatorVariants: symbol.navigatorVariants,
            roleHeadingVariants: symbol.roleHeadingVariants,
            platformNameVariants: symbol.platformNameVariants,
            moduleReference: symbol.moduleReference,
            extendedModule: symbol.extendedModule,
            requiredVariants: symbol.isRequiredVariants,
            externalIDVariants: symbol.externalIDVariants,
            accessLevelVariants: symbol.accessLevelVariants,
            availabilityVariants: symbol.availabilityVariants,
            deprecatedSummaryVariants: symbol.deprecatedSummaryVariants,
            mixinsVariants: symbol.mixinsVariants,
            declarationVariants: symbol.declarationVariants,
            defaultImplementationsVariants: symbol.defaultImplementationsVariants,
            relationshipsVariants: symbol.relationshipsVariants,
            abstractSectionVariants: newAbstractVariants,
            discussionVariants: newDiscussionVariants,
            topicsVariants: newTopicsVariants,
            seeAlsoVariants: newSeeAlsoVariants,
            returnsSectionVariants: newReturnsVariants,
            parametersSectionVariants: newParametersVariants,
            redirectsVariants: symbol.redirectsVariants,
            crossImportOverlayModule: symbol.crossImportOverlayModule,
            originVariants: symbol.originVariants,
            automaticTaskGroupsVariants: symbol.automaticTaskGroupsVariants
        )
    }
    
    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> Semantic {
        let newContent = visit(summary.content) as! MarkupContainer
        return DeprecationSummary(originalMarkup: summary.originalMarkup, content: newContent)
    }
}

fileprivate extension URL {
    var isLikelyWebURL: Bool {
        if let scheme = scheme, scheme.hasPrefix("http") {
            return true
        }
        return false
    }
}

extension Image {
    func reference(in bundle: DocumentationBundle) -> ResourceReference? {
        guard let source = source else {
            return ResourceReference(bundleIdentifier: bundle.identifier, path: "")
        }
        
        if let url = URL(string: source), url.isLikelyWebURL {
            return nil
        } else {
            return ResourceReference(bundleIdentifier: bundle.identifier, path: source)
        }
    }
}
