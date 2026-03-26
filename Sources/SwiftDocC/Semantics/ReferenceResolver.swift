/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
private import SymbolKit

func unresolvedReferenceProblem(source: URL?, range: SourceRange?, severity: DiagnosticSeverity, errorInfo: TopicReferenceResolutionErrorInfo, fromSymbolLink: Bool) -> Problem {
    let referenceSourceRange: SourceRange? = range.map { range in
        // FIXME: Finding the range for the link's destination is better suited for Swift-Markdown
        // https://github.com/apple/swift-markdown/issues/109
        if fromSymbolLink {
            // Inset the range by 2 at the start and end to skip both "``".
            return SourceLocation(line: range.lowerBound.line, column: range.lowerBound.column+2, source: range.lowerBound.source) ..< SourceLocation(line: range.upperBound.line, column: range.upperBound.column-2, source: range.upperBound.source)
        } else {
            // FIXME: This assumes that the link uses the `<doc:my/reference>` syntax.
            // Links that use the [link text](doc:my/reference) syntax will have incorrect suggestion replacements.
            // https://github.com/swiftlang/swift-docc/issues/470
            
            // Inset the range by 5 at the start and by 1 at the end to skip "<doc:" at the start and ">" at the end.
            return SourceLocation(line: range.lowerBound.line, column: range.lowerBound.column+5, source: range.lowerBound.source) ..< SourceLocation(line: range.upperBound.line, column: range.upperBound.column-1, source: range.upperBound.source)
        }
    }
    
    var solutions: [Solution] = []
    var notes: [DiagnosticNote] = []
    if let referenceSourceRange {
        if let note = errorInfo.note, let source {
            notes.append(DiagnosticNote(source: source, range: referenceSourceRange, message: note))
        }
        
        solutions.append(contentsOf: errorInfo.solutions(referenceSourceRange: referenceSourceRange))
    }
    
    let diagnosticRange: SourceRange?
    if var rangeAdjustment = errorInfo.rangeAdjustment, let referenceSourceRange {
        rangeAdjustment.offsetWithRange(referenceSourceRange)
        assert(rangeAdjustment.lowerBound.column >= 0, """
            Unresolved topic reference range adjustment created range with negative column.
            Source: \(source?.absoluteString ?? "nil")
            Range: \(rangeAdjustment.lowerBound.description):\(rangeAdjustment.upperBound.description)
            Summary: \(errorInfo.message)
            """)
        diagnosticRange = rangeAdjustment
    } else {
        diagnosticRange = referenceSourceRange
    }
    
    let diagnostic = Diagnostic(source: source, severity: severity, range: diagnosticRange, identifier: "org.swift.docc.unresolvedTopicReference", summary: errorInfo.message, notes: notes)
    return Problem(diagnostic: diagnostic, possibleSolutions: solutions)
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
    if let expectedType {
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
    
    /// Problems found while trying to resolve references.
    var problems = [Problem]()
    
    var rootReference: ResolvedTopicReference
    
    /// If the documentation is inherited, the reference of the parent symbol.
    var inheritanceParentReference: ResolvedTopicReference?
    
    init(context: DocumentationContext, rootReference: ResolvedTopicReference? = nil, inheritanceParentReference: ResolvedTopicReference? = nil) {
        self.context = context
        self.rootReference = rootReference ?? context.inputs.rootReference
        self.inheritanceParentReference = inheritanceParentReference
    }
    
    mutating func resolve(_ reference: TopicReference, in parent: ResolvedTopicReference, range: SourceRange?, severity: DiagnosticSeverity) -> TopicReferenceResolutionResult {
        switch context.resolve(reference, in: parent) {
        case .success(let resolved):
            return .success(resolved)
            
        case let .failure(unresolved, error):
            if let articleNotInHierarchy = context.uncuratedArticles[context.inputs.documentationRootReference.appendingPathOfReference(unresolved)] {
                problems.append(makeUnfindableArticleProblem(source: range?.source, severity: severity, range: range, articleNotInHierarchy: articleNotInHierarchy, rootPageNames: context.sortedRootPageNames()))
            } else {
                problems.append(unresolvedReferenceProblem(source: range?.source, range: range, severity: severity, errorInfo: error, fromSymbolLink: false))
            }
            return .failure(unresolved, error)
        }
    }
    
    /**
    Returns a ``Problem`` if the resource cannot be found; otherwise `nil`.
    */
    func resolve(resource: ResourceReference, range: SourceRange?, severity: DiagnosticSeverity) -> Problem? {
        if !context.resourceExists(with: resource) {
            return unresolvedResourceProblem(resource: resource, source: range?.source, range: range, severity: severity)
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
            var resolvedDownload = context.resolveAsset(named: projectFiles.path, in: rootReference) {
            resolvedDownload.context = .download
            context.updateAsset(named: projectFiles.path, asset: resolvedDownload, in: rootReference)
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
        var markupResolver = MarkupReferenceResolver(context: context, rootReference: rootReference)
        let parent = inheritanceParentReference
        let context = self.context
        
        markupResolver.problemForUnresolvedReference = { unresolved, range, fromSymbolLink, underlyingErrorMessage -> Problem? in
            // Verify we have all the information about the location of the source comment
            // and the symbol that the comment is inherited from.
            if let parent, let range {
                switch context.resolve(.unresolved(unresolved), in: parent, fromSymbolLink: fromSymbolLink) {
                    case .success(let resolved):
                        // Return a warning with a suggested change that replaces the relative link with an absolute one.
                        return Problem(diagnostic: Diagnostic(source: range.source,
                            severity: .warning, range: range,
                            identifier: "org.swift.docc.UnresolvableLinkWhenInherited",
                            summary: "This documentation block is inherited by other symbols where \(unresolved.topicURL.absoluteString.singleQuoted) fails to resolve."),
                            possibleSolutions: [
                                Solution(summary: "Use an absolute link path.", replacements: [
                                    // FIXME: The resolved reference path isn't the same as the authorable link.
                                    Replacement(range: range, replacement: "<doc:\(resolved.path)>")
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
    
    mutating func visitMarkup(_ markup: any Markup) -> any Markup {
        // Wrap in a markup container and the first child of the result.
        return (visitMarkupContainer(MarkupContainer(markup)) as! MarkupContainer).elements.first!
    }

    mutating func visitTutorialTableOfContents(_ tutorialTableOfContents: TutorialTableOfContents) -> Semantic {
        let newIntro = visit(tutorialTableOfContents.intro) as! Intro
        let newVolumes = tutorialTableOfContents.volumes.map { visit($0) } as! [Volume]
        let newResources = tutorialTableOfContents.resources.map { visit($0) as! Resources }
        return TutorialTableOfContents(originalMarkup: tutorialTableOfContents.originalMarkup, name: tutorialTableOfContents.name, intro: newIntro, volumes: newVolumes, resources: newResources, redirects: tutorialTableOfContents.redirects)
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
        let newMedia = contentAndMedia.media.map { visit($0) } as! (any Media)?
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
                let diagnostic = Diagnostic(source: chapter.originalMarkup.range?.source, severity: .warning, range: newTutorialReference.originalMarkup.range, identifier: "org.swift.docc.\(Chapter.self).Duplicate\(TutorialReference.self)", summary: "Duplicate \(TutorialReference.directiveName.singleQuoted) directive refers to \(newTutorialReference.topic.description.singleQuoted)")
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
            let maybeResolved = resolve(tutorialReference.topic, in: context.inputs.tutorialsContainerReference,
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
        // If there's a call to action with a local-file reference, change its context to `download`
        if let downloadFile = article.metadata?.callToAction?.resolveFile(for: context.inputs, in: context, problems: &problems),
            var resolvedDownload = context.resolveAsset(named: downloadFile.path, in: rootReference) {
            resolvedDownload.context = .download
            context.updateAsset(named: downloadFile.path, asset: resolvedDownload, in: rootReference)
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

    private mutating func visitMarkupLayouts(_ markupLayouts: some Sequence<MarkupLayout>) -> [MarkupLayout] {
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
        case .symbol(let name):
            return node.symbol?.names.title ?? name
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
                Parameter(name: $0.name, nameRange: $0.nameRange, contents: $0.contents.map { visitMarkup($0) }, range: $0.range, isStandalone: $0.isStandalone)
            }
            return ParametersSection(parameters: parameters)
        }
        let newDeprecatedSummaryVariants = symbol.deprecatedSummaryVariants.map {
            return DeprecatedSection(content: $0.content.map { visitMarkup($0) })
        }
        let newDictionaryKeys = symbol.dictionaryKeysSection.map { dictionaryKeysSection -> DictionaryKeysSection in
            let keys = dictionaryKeysSection.dictionaryKeys.map {
                DictionaryKey(name: $0.name, contents: $0.contents.map { visitMarkup($0) }, symbol: $0.symbol, required: $0.required)
            }
            return DictionaryKeysSection(dictionaryKeys: keys)
        }
        let newHTTPEndpoint = symbol.httpEndpointSection.map { httpEndpointSection -> HTTPEndpointSection in
            return HTTPEndpointSection(endpoint: httpEndpointSection.endpoint)
        }
        let newHTTPBody = symbol.httpBodySection.map { httpBodySection -> HTTPBodySection in
            let oldBody = httpBodySection.body
            let newBodyParameters = oldBody.parameters.map {
                HTTPParameter(name: $0.name, source: $0.source, contents: $0.contents.map { visitMarkup($0) }, symbol: $0.symbol, required: $0.required)
            }
            let newBody = HTTPBody(mediaType: oldBody.mediaType, contents: oldBody.contents.map { visitMarkup($0) }, parameters: newBodyParameters, symbol: oldBody.symbol)
            return HTTPBodySection(body: newBody)
        }
        let newHTTPParameters = symbol.httpParametersSection.map { httpParametersSection -> HTTPParametersSection in
            let parameters = httpParametersSection.parameters.map {
                HTTPParameter(name: $0.name, source: $0.source, contents: $0.contents.map { visitMarkup($0) }, symbol: $0.symbol, required: $0.required)
            }
            return HTTPParametersSection(parameters: parameters)
        }
        let newHTTPResponses = symbol.httpResponsesSection.map { httpResponsesSection -> HTTPResponsesSection in
            let responses = httpResponsesSection.responses.map {
                HTTPResponse(statusCode: $0.statusCode, reason: $0.reason, mediaType: $0.mediaType, contents: $0.contents.map { visitMarkup($0) }, symbol: $0.symbol)
            }
            return HTTPResponsesSection(responses: responses)
        }
        
        let newPossibleValuesSection = symbol.possibleValuesSection.map { possibleValuesSection -> PropertyListPossibleValuesSection in
            let possibleValues = possibleValuesSection.possibleValues.map {
                PropertyListPossibleValuesSection.PossibleValue(value: $0.value, contents: $0.contents.map { visitMarkup($0) }, nameRange: $0.nameRange, range: $0.range)
            }
            return PropertyListPossibleValuesSection(possibleValues: possibleValues)
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
            requiredVariants: symbol.isRequiredVariants,
            externalIDVariants: symbol.externalIDVariants,
            accessLevelVariants: symbol.accessLevelVariants,
            availabilityVariants: symbol.availabilityVariants,
            deprecatedSummaryVariants: newDeprecatedSummaryVariants,
            mixinsVariants: symbol.mixinsVariants,
            declarationVariants: symbol.declarationVariants,
            alternateDeclarationVariants: symbol.alternateDeclarationVariants,
            alternateSignatureVariants: symbol.alternateSignatureVariants,
            defaultImplementationsVariants: symbol.defaultImplementationsVariants,
            relationshipsVariants: symbol.relationshipsVariants,
            abstractSectionVariants: newAbstractVariants,
            discussionVariants: newDiscussionVariants,
            topicsVariants: newTopicsVariants,
            seeAlsoVariants: newSeeAlsoVariants,
            returnsSectionVariants: newReturnsVariants,
            parametersSectionVariants: newParametersVariants,
            dictionaryKeysSection: newDictionaryKeys,
            possibleValuesSection: newPossibleValuesSection,
            httpEndpointSection: newHTTPEndpoint,
            httpBodySection: newHTTPBody,
            httpParametersSection: newHTTPParameters,
            httpResponsesSection: newHTTPResponses,
            redirects: symbol.redirects,
            crossImportOverlayModule: symbol.crossImportOverlayModule,
            originVariants: symbol.originVariants,
            automaticTaskGroupsVariants: symbol.automaticTaskGroupsVariants,
            overloadsVariants: symbol.overloadsVariants
        )
    }
    
    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> Semantic {
        let newContent = visit(summary.content) as! MarkupContainer
        return DeprecationSummary(originalMarkup: summary.originalMarkup, content: newContent)
    }
}

fileprivate extension URL {
    var isLikelyWebURL: Bool {
        if let scheme, scheme.hasPrefix("http") {
            return true
        }
        return false
    }
}

extension Image {
    func reference(in bundle: DocumentationBundle) -> ResourceReference? {
        guard let source else {
            return ResourceReference(bundleID: bundle.id, path: "")
        }
        
        if let url = URL(string: source), url.isLikelyWebURL {
            return nil
        } else {
            return ResourceReference(bundleID: bundle.id, path: source)
        }
    }
}

// MARK: Diagnostics

func makeUnfindableArticleProblem(
    source: URL?,
    severity: DiagnosticSeverity,
    range: SourceRange?,
    articleNotInHierarchy: DocumentationContext.SemanticResult<Article>,
    rootPageNames: [String]
) -> Problem {
    Problem(diagnostic: Diagnostic(
        source: source,
        severity: severity,
        range: range,
        identifier: "UnfindableArticle",
        summary: "Article is not findable in invalid documentation hierarchy with \(rootPageNames.count) roots",
        explanation: """
            Documentation with \(rootPageNames.count) roots (\(rootPageNames.map(\.singleQuoted).list(finalConjunction: .and))) has a disjoint and unsupported documentation hierarchy.
            Because there are multiple roots in the hierarchy, it's undefined behavior where in hierarchy this article would belong.
            As a consequence, the '\(articleNotInHierarchy.topicGraphNode.title)' article (\(articleNotInHierarchy.source.lastPathComponent)) is not findable and has no page in the output.
            """
    ))
}
