/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

/// A visitor which converts a semantic model into a render node.
///
/// The translator visits the contents of a ``DocumentationNode``'s ``Semantic`` model and creates a ``RenderNode``.
/// The translation is lossy, meaning that translating a ``RenderNode`` back to a ``Semantic`` is not possible with full fidelity.
/// For example, source markup syntax is not preserved during the translation.
public struct RenderNodeTranslator: SemanticVisitor {

    /// Resolved topic references that were seen by the visitor. These should be used to populate the references dictionary.
    var collectedTopicReferences: [ResolvedTopicReference] = []
    
    /// Unresolvable topic references outside the current bundle.
    var collectedUnresolvedTopicReferences: [UnresolvedTopicReference] = []
    
    /// Any collected constraints to symbol relationships.
    var collectedConstraints: [TopicReference: [SymbolGraph.Symbol.Swift.GenericConstraint]] = [:]
    
    /// A context containing pre-rendered content.
    let renderContext: RenderContext?
    
    /// A collection of functions that render pieces of documentation content.
    let contentRenderer: DocumentationContentRenderer
    
    /// Whether the documentation converter should include source file
    /// location metadata in any render nodes representing symbols it creates.
    ///
    /// Before setting this value to `true` please confirm that your use case doesn't
    /// include public distribution of any created render nodes as there are filesystem privacy and security
    /// concerns with distributing this data.
    var shouldEmitSymbolSourceFileURIs: Bool
    
    /// Whether the documentation converter should include access level information for symbols.
    var shouldEmitSymbolAccessLevels: Bool
    
    /// The source repository where the documentation's sources are hosted.
    var sourceRepository: SourceRepository?
    
    var symbolIdentifiersWithExpandedDocumentation: [String]? = nil
    
    public mutating func visitCode(_ code: Code) -> RenderTree? {
        let fileType = NSString(string: code.fileName).pathExtension
        guard let fileIdentifier = context.identifier(forAssetName: code.fileReference.path, in: identifier) else {
            return nil
        }
        
        let fileReference = ResourceReference(bundleIdentifier: code.fileReference.bundleIdentifier, path: fileIdentifier)
        guard let fileContents = fileContents(with: fileReference) else {
            return nil
        }
        
        let assetReference = RenderReferenceIdentifier(fileReference.path)
        
        fileReferences[fileReference.path] = FileReference(
            identifier: assetReference,
            fileName: code.fileName,
            fileType: fileType,
            syntax: fileType,
            content: fileContents.splitByNewlines
        )
        return assetReference
    }
    
    private func fileContents(with fileReference: ResourceReference) -> String? {
        // Check if the file is a local asset that can be read directly from the context
        if let fileData = try? context.resource(with: fileReference) {
            return String(data: fileData, encoding: .utf8)
        }
        // Check if the file needs to be resolved to read its content
        else if let asset = context.resolveAsset(named: fileReference.path, in: identifier) {
            return try? String(contentsOf: asset.data(bestMatching: DataTraitCollection()).url, encoding: .utf8)
        }
        // Couldn't find the file reference's content
        else {
            return nil
        }
    }
    
    public mutating func visitSteps(_ steps: Steps) -> RenderTree? {
        let stepsContent = steps.content.flatMap { child -> [RenderBlockContent] in
            return visit(child) as! [RenderBlockContent]
        }
        
        return stepsContent
    }
    
    public mutating func visitStep(_ step: Step) -> RenderTree? {
        let renderBlock = visitMarkupContainer(MarkupContainer(step.content)) as! [RenderBlockContent]
        let caption = visitMarkupContainer(MarkupContainer(step.caption)) as! [RenderBlockContent]
        
        let mediaReference = step.media.map { visit($0) } as? RenderReferenceIdentifier
        let codeReference = step.code.map { visitCode($0) } as? RenderReferenceIdentifier
        
        let previewReference = step.code?.preview.flatMap {
            createAndRegisterRenderReference(forMedia: $0.source, altText: ($0 as? ImageMedia)?.altText)
        }
        
        let result = [RenderBlockContent.step(.init(content: renderBlock, caption: caption, media: mediaReference, code: codeReference, runtimePreview: previewReference))]
        
        return result
    }
    
    public mutating func visitTutorialSection(_ tutorialSection: TutorialSection) -> RenderTree? {
        let introduction = contentLayouts(tutorialSection.introduction)
        let stepsContent: [RenderBlockContent]
        if let steps = tutorialSection.stepsContent {
            stepsContent = visit(steps) as! [RenderBlockContent]
        } else {
            stepsContent = []
        }
        
        let highlightsPerFile = LineHighlighter(context: context, tutorialSection: tutorialSection, tutorialReference: identifier).highlights
        
        // Add the highlights to the file references.
        for result in highlightsPerFile {
            fileReferences[result.file.path]?.highlights = result.highlights
        }
        
        return TutorialSectionsRenderSection.Section(title: tutorialSection.title, contentSection: introduction, stepsSection: stepsContent, anchor: urlReadableFragment(tutorialSection.title))
    }
    
    public mutating func visitTutorial(_ tutorial: Tutorial) -> RenderTree? {
        var node = RenderNode(identifier: identifier, kind: .tutorial)
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        
        if let hierarchy = hierarchyTranslator.visitTechnologyNode(identifier) {
            let technology = try! context.entity(with: hierarchy.technology).semantic as! Technology
            node.hierarchy = hierarchy.hierarchy
            node.metadata.category = technology.name
            node.metadata.categoryPathComponent = hierarchy.technology.url.lastPathComponent
        } else if !context.allowsRegisteringArticlesWithoutTechnologyRoot {
            // This tutorial is not curated, so we don't generate a render node.
            // We've warned about this during semantic analysis.
            return nil
        }
        
        node.metadata.title = tutorial.intro.title
        node.metadata.role = DocumentationContentRenderer.role(for: .tutorial).rawValue
        
        collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        
        let documentationNode = try! context.entity(with: identifier)
        node.variants = variants(for: documentationNode)
                
        var intro = visitIntro(tutorial.intro) as! IntroRenderSection
        intro.estimatedTimeInMinutes = tutorial.durationMinutes
        
        if let chapterReference = context.parents(of: identifier).first {
            intro.chapter = context.title(for: chapterReference)
        }
        // Add an Xcode requirement to the tutorial intro if one is provided.
        if let requirement = tutorial.requirements.first {
            let identifier = RenderReferenceIdentifier(requirement.title)
            let requirementReference = XcodeRequirementReference(identifier: identifier, title: requirement.title, url: requirement.destination)
            requirementReferences[identifier.identifier] = requirementReference 
            intro.xcodeRequirement = identifier
        }
        
        if let projectFiles = tutorial.projectFiles {
            intro.projectFiles = createAndRegisterRenderReference(forMedia: projectFiles, assetContext: .download)
        }
        
        node.sections.append(intro)
        
        var tutorialSections = TutorialSectionsRenderSection(sections: tutorial.sections.map { visitTutorialSection($0) as! TutorialSectionsRenderSection.Section })

        // Attach anchors to tutorial sections.
        // Find the reference associated with the section, by searching the tutorial's children for a node that has a matching title.
        // This assumes that the rendered `tasks` are in the same order as `tutorial.sections`.
        let sectionReferences = context.children(of: identifier, kind: .onPageLandmark)
        tutorialSections.tasks = tutorialSections.tasks.enumerated().map { (index, section) in
            var section = section
            section.anchor = sectionReferences[index].reference.fragment ?? ""
            return section
        }
        
        node.sections.append(tutorialSections)
        if let assessments = tutorial.assessments {
            node.sections.append(visitAssessments(assessments) as! TutorialAssessmentsRenderSection)
        }

        // We guarantee there will be at least 1 path with at least 4 nodes in that path if the tutorial is curated.
        // The way to curate tutorials is to link them from a Technology page and that generates the following hierarchy:
        // technology -> volume -> chapter -> tutorial.
        let technologyPath = context.finitePaths(to: identifier, options: [.preferTechnologyRoot])[0]
        
        if technologyPath.count >= 2 {
            let volume = technologyPath[technologyPath.count - 2]
            
            if let cta = callToAction(with: tutorial.callToActionImage, volume: volume) {
                node.sections.append(cta)
            }
        }
        
        node.references = createTopicRenderReferences()

        addReferences(fileReferences, to: &node)
        addReferences(imageReferences, to: &node)
        addReferences(videoReferences, to: &node)
        addReferences(requirementReferences, to: &node)
        addReferences(downloadReferences, to: &node)
        addReferences(linkReferences, to: &node)
        addReferences(hierarchyTranslator.linkReferences, to: &node)
        return node
    }
    
    /// Creates a CTA for tutorials and tutorial articles.
    private mutating func callToAction(with callToActionImage: ImageMedia?, volume: ResolvedTopicReference) -> CallToActionSection? {
        // Get all the tutorials and tutorial articles in the learning path, ordered.

        var surroundingTopics = [(reference: ResolvedTopicReference, kind: DocumentationNode.Kind)]()
        for node in context.breadthFirstSearch(from: volume) where node.kind == .tutorial || node.kind == .tutorialArticle {
            surroundingTopics.append((node.reference, node.kind))
        }
        
        // Find the tutorial or article that comes after the current page, if one exists.
        let nextTopicIndex = surroundingTopics.firstIndex(where: { $0.reference == identifier }).map { $0 + 1 }
        if let nextTopicIndex, nextTopicIndex < surroundingTopics.count {
            let nextTopicReference = surroundingTopics[nextTopicIndex]
            let nextTopicReferenceIdentifier = visitResolvedTopicReference(nextTopicReference.reference) as! RenderReferenceIdentifier
            let nextTopic = try! context.entity(with: nextTopicReference.reference).semantic as! Abstracted & Titled
            
            let image = callToActionImage.map { visit($0) as! RenderReferenceIdentifier }
            
            return createCallToAction(reference: nextTopicReferenceIdentifier, kind: nextTopicReference.kind, title: nextTopic.title ?? "", abstract: inlineAbstractContentInTopic(nextTopic), image: image)
        }
        
        return nil
    }
    
    private mutating func createCallToAction(reference: RenderReferenceIdentifier, kind: DocumentationNode.Kind, title: String, abstract: [RenderInlineContent], image: RenderReferenceIdentifier?) -> CallToActionSection {
        let overridingTitle: String
        let eyebrow: String
        switch kind {
        case .tutorial:
            overridingTitle = "Get started"
            eyebrow = "Tutorial"
        case .tutorialArticle:
            overridingTitle = "Read article"
            eyebrow = "Article"
        default:
            fatalError("Unexpected kind '\(kind)', only tutorials and tutorial articles may be CTA destinations.")
        }
        
        let action = RenderInlineContent.reference(identifier: reference, isActive: true, overridingTitle: overridingTitle, overridingTitleInlineContent: [.text(overridingTitle)])
        return CallToActionSection(title: title, abstract: abstract, media: image, action: action, featuredEyebrow: eyebrow)
    }
    
    private mutating func inlineAbstractContentInTopic(_ topic: Abstracted) -> [RenderInlineContent] {
        if let abstract = topic.abstract {
            return (visitMarkupContainer(MarkupContainer(abstract)) as! [RenderBlockContent]).firstParagraph
        }
        
        return []
    }
    
    public mutating func visitIntro(_ intro: Intro) -> RenderTree? {
        var section = IntroRenderSection(title: intro.title)
        section.content = visitMarkupContainer(intro.content) as! [RenderBlockContent]
        
        section.image = intro.image.map { visit($0) } as? RenderReferenceIdentifier
        section.video = intro.video.map { visit($0) } as? RenderReferenceIdentifier
        
        // Set the Intro's background image to the video's poster image.
        section.backgroundImage = intro.video?.poster.flatMap { createAndRegisterRenderReference(forMedia: $0) }
            ?? intro.image.flatMap { createAndRegisterRenderReference(forMedia: $0.source) }
        
        return section
    }
    
    /// Add a requirement reference and return its identifier.
    public mutating func visitXcodeRequirement(_ requirement: XcodeRequirement) -> RenderTree? {
        fatalError("TODO")
    }
    
    public mutating func visitAssessments(_ assessments: Assessments) -> RenderTree? {
        let renderSectionAssessments: [TutorialAssessmentsRenderSection.Assessment] = assessments.questions.map { question in
            return self.visitMultipleChoice(question) as! TutorialAssessmentsRenderSection.Assessment
        }
        
        return TutorialAssessmentsRenderSection(assessments: renderSectionAssessments, anchor: RenderHierarchyTranslator.assessmentsAnchor)
    }
    
    public mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) -> RenderTree? {
        let questionPhrasing = visit(multipleChoice.questionPhrasing) as! [RenderBlockContent]
        let content = visitMarkupContainer(multipleChoice.content) as! [RenderBlockContent]
        return TutorialAssessmentsRenderSection.Assessment(title: questionPhrasing, content: content, choices: multipleChoice.choices.map { visitChoice($0) } as! [TutorialAssessmentsRenderSection.Assessment.Choice])
    }
    
    public mutating func visitChoice(_ choice: Choice) -> RenderTree? {
        return TutorialAssessmentsRenderSection.Assessment.Choice(
            content: visitMarkupContainer(choice.content) as! [RenderBlockContent],
            isCorrect: choice.isCorrect,
            justification: (visitJustification(choice.justification) as! [RenderBlockContent]),
            reaction: choice.justification.reaction
        )
    }
    
    public mutating func visitJustification(_ justification: Justification) -> RenderTree? {
        return visitMarkupContainer(justification.content) as! [RenderBlockContent]
    }
        
    // Visits a container and expects the elements to be block level elements
    public mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) -> RenderTree? {
        var contentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: identifier)
        let content = markupContainer.elements.reduce(into: [], { result, item in result.append(contentsOf: contentCompiler.visit(item))}) as! [RenderBlockContent]
        collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        // Copy all the image references found in the markup container.
        imageReferences.merge(contentCompiler.imageReferences) { (_, new) in new }
        videoReferences.merge(contentCompiler.videoReferences) { (_, new) in new }
        linkReferences.merge(contentCompiler.linkReferences) { (_, new) in new }
        return content
    }
    
    // Visits a collection of inline markup elements.
    public mutating func visitMarkup(_ markup: [Markup]) -> RenderTree? {
        var contentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: identifier)
        let content = markup.reduce(into: [], { result, item in result.append(contentsOf: contentCompiler.visit(item))}) as! [RenderInlineContent]
        collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        // Copy all the image references.
        imageReferences.merge(contentCompiler.imageReferences) { (_, new) in new }
        videoReferences.merge(contentCompiler.videoReferences) { (_, new) in new }
        return content
    }

    // Visits a single inline markup element.
    public mutating func visitMarkup(_ markup: Markup) -> RenderTree? {
        return visitMarkup(Array(markup.children))
    }
    
    private func firstTutorial(ofTechnology technology: ResolvedTopicReference) -> (reference: ResolvedTopicReference, kind: DocumentationNode.Kind)? {
        guard let volume = (context.children(of: technology, kind: .volume)).first,
            let firstChapter = (context.children(of: volume.reference)).first,
            let firstTutorial = (context.children(of: firstChapter.reference)).first else
        {
            return nil
        }
        return firstTutorial
    }

    /// Returns a description of the total estimated duration to complete the tutorials of the given technology.
    /// - Returns: The estimated duration, or `nil` if there are no tutorials with time estimates.
    private func totalEstimatedDuration() -> String? {
        var totalDurationMinutes: Int? = nil

        for node in context.breadthFirstSearch(from: identifier) {
            guard let entity = try? context.entity(with: node.reference),
                  let durationMinutes = (entity.semantic as? Timed)?.durationMinutes
            else {
                continue
            }
            
            if totalDurationMinutes == nil {
                totalDurationMinutes = 0
            }
            totalDurationMinutes! += durationMinutes
        }

        return totalDurationMinutes.flatMap(contentRenderer.formatEstimatedDuration(minutes:))
    }

    public mutating func visitTechnology(_ technology: Technology) -> RenderTree? {
        var node = RenderNode(identifier: identifier, kind: .overview)
        
        node.metadata.title = technology.intro.title
        node.metadata.category = technology.name
        node.metadata.categoryPathComponent = identifier.url.lastPathComponent
        node.metadata.estimatedTime = totalEstimatedDuration()
        node.metadata.role = DocumentationContentRenderer.role(for: .technology).rawValue
        
        let documentationNode = try! context.entity(with: identifier)
        node.variants = variants(for: documentationNode)

        var intro = visitIntro(technology.intro) as! IntroRenderSection
        if let firstTutorial = self.firstTutorial(ofTechnology: identifier) {
            intro.action = visitLink(firstTutorial.reference.url, defaultTitle: "Get started")
        }
        node.sections.append(intro)
                
        node.sections.append(contentsOf: technology.volumes.map { visitVolume($0) as! VolumeRenderSection })
        
        if let resources = technology.resources {
            node.sections.append(visitResources(resources) as! ResourcesRenderSection)
        }
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        node.hierarchy = hierarchyTranslator
            .visitTechnologyNode(identifier, omittingChapters: true)!
            .hierarchy

        collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        
        node.references = createTopicRenderReferences()
        
        addReferences(fileReferences, to: &node)
        addReferences(imageReferences, to: &node)
        addReferences(videoReferences, to: &node)
        addReferences(linkReferences, to: &node)
        
        return node
    }
    
    private mutating func createTopicRenderReferences() -> [String: RenderReference] {
        var renderReferences: [String: RenderReference] = [:]
        let renderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        
        for reference in collectedTopicReferences {
            var renderReference: TopicRenderReference
            var dependencies: RenderReferenceDependencies
            
            if let renderContext, let prerendered = renderContext.store.content(for: reference)?.renderReference as? TopicRenderReference,
                let renderReferenceDependencies = renderContext.store.content(for: reference)?.renderReferenceDependencies {
                renderReference = prerendered
                dependencies = renderReferenceDependencies
            } else {
                dependencies = RenderReferenceDependencies()
                renderReference = renderer.renderReference(for: reference, dependencies: &dependencies)
            }
            
            for link in dependencies.linkReferences {
                linkReferences[link.identifier.identifier] = link
            }
            
            for imageReference in dependencies.imageReferences {
                imageReferences[imageReference.identifier.identifier] = imageReference
            }
            
            
            for dependencyReference in dependencies.topicReferences {
                var dependencyRenderReference: TopicRenderReference
                if let renderContext, let prerendered = renderContext.store.content(for: dependencyReference)?.renderReference as? TopicRenderReference {
                    dependencyRenderReference = prerendered
                } else {
                    var dependencies = RenderReferenceDependencies()
                    dependencyRenderReference = renderer.renderReference(for: dependencyReference, dependencies: &dependencies)
                }
                renderReferences[dependencyReference.absoluteString] = dependencyRenderReference
            }
            
            // Add any conformance constraints to the reference, if any are present.
            if let conformanceSection = renderer.conformanceSectionFor(reference, collectedConstraints: collectedConstraints) {
                renderReference.conformance = conformanceSection
            }
            
            renderReferences[reference.absoluteString] = renderReference
        }

        for unresolved in collectedUnresolvedTopicReferences {
            let renderReference = UnresolvedRenderReference(
                identifier: RenderReferenceIdentifier(unresolved.topicURL.absoluteString),
                title: unresolved.title ?? unresolved.topicURL.absoluteString
            )
            renderReferences[renderReference.identifier.identifier] = renderReference
        }
        
        return renderReferences
    }
    
    private func addReferences(_ references: [String: some RenderReference], to node: inout RenderNode) {
        node.references.merge(references) { _, new in new }
    }

    public mutating func visitVolume(_ volume: Volume) -> RenderTree? {
        var volumeSection = VolumeRenderSection(name: volume.name)
        volumeSection.image = volume.image.map { visit($0) as! RenderReferenceIdentifier }
        volumeSection.content = volume.content.map { visitMarkupContainer($0) as! [RenderBlockContent] }
        volumeSection.chapters = volume.chapters.compactMap { visitChapter($0) } as? [VolumeRenderSection.Chapter] ?? []
        return volumeSection
    }
    
    public mutating func visitImageMedia(_ imageMedia: ImageMedia) -> RenderTree? {
        return createAndRegisterRenderReference(forMedia: imageMedia.source, altText: imageMedia.altText)
    }
    
    public mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> RenderTree? {
        return createAndRegisterRenderReference(
            forMedia: videoMedia.source,
            poster: videoMedia.poster,
            altText: videoMedia.altText
        )
    }
    
    public mutating func visitChapter(_ chapter: Chapter) -> RenderTree? {
        guard !chapter.topicReferences.isEmpty else {
            // If the chapter has no tutorials, return `nil`.
            return nil
        }
        
        var renderChapter = VolumeRenderSection.Chapter(name: chapter.name)
        renderChapter.content = visitMarkupContainer(chapter.content) as! [RenderBlockContent]
        renderChapter.tutorials = chapter.topicReferences.map { visitTutorialReference($0) } as! [RenderReferenceIdentifier]
        renderChapter.image = chapter.image.map { visit($0) } as? RenderReferenceIdentifier
        
        return renderChapter
    }
    
    public mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> RenderTree? {
        var layout: ContentAndMediaSection.Layout? {
            switch contentAndMedia.layout {
            case .horizontal: return .horizontal
            case .vertical: return .vertical
            case nil: return nil
            }
        }

        let mediaReference = contentAndMedia.media.map { visit($0) } as? RenderReferenceIdentifier
        var section = ContentAndMediaSection(layout: layout, title: contentAndMedia.title, media: mediaReference, mediaPosition: contentAndMedia.mediaPosition)
        
        section.eyebrow = contentAndMedia.eyebrow
        section.content = visitMarkupContainer(contentAndMedia.content) as! [RenderBlockContent]
        
        return section
    }
        
    public mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> RenderTree? {
        switch context.resolve(tutorialReference.topic, in: bundle.rootReference) {
        case let .failure(reference, _):
            return RenderReferenceIdentifier(reference.topicURL.absoluteString)
        case let .success(resolved):
            return visitResolvedTopicReference(resolved)
        }
    }
    
    public mutating func visitResolvedTopicReference(_ resolvedTopicReference: ResolvedTopicReference) -> RenderTree {
        collectedTopicReferences.append(resolvedTopicReference)
        return RenderReferenceIdentifier(resolvedTopicReference.absoluteString)
    }
        
    public mutating func visitResources(_ resources: Resources) -> RenderTree? {
        let tiles = resources.tiles.map { visitTile($0) as! RenderTile }
        let content = visitMarkupContainer(resources.content) as! [RenderBlockContent]
        return ResourcesRenderSection(tiles: tiles, content: content)
    }

    public mutating func visitLink(_ link: URL, defaultTitle overridingTitle: String?) -> RenderInlineContent {
        let overridingTitleInlineContent: [RenderInlineContent]? = overridingTitle.map { [RenderInlineContent.text($0)] }
        
        let action: RenderInlineContent
        // We expect, at this point of the rendering, this API to be called with valid URLs, otherwise crash.
        if let resolved = context.referenceIndex[link.absoluteString] {
            action = RenderInlineContent.reference(identifier: RenderReferenceIdentifier(resolved.absoluteString),
                                                   isActive: true,
                                                   overridingTitle: overridingTitle,
                                                   overridingTitleInlineContent: overridingTitleInlineContent)
            collectedTopicReferences.append(resolved)
        } else if !ResolvedTopicReference.urlHasResolvedTopicScheme(link) {
            // This is an external link
            let externalLinkIdentifier = RenderReferenceIdentifier(forExternalLink: link.absoluteString)
            if linkReferences.keys.contains(externalLinkIdentifier.identifier) {
                // If we've already seen this link, return the existing reference with an overridden title.
                action = RenderInlineContent.reference(identifier: externalLinkIdentifier,
                                                       isActive: true,
                                                       overridingTitle: overridingTitle,
                                                       overridingTitleInlineContent: overridingTitleInlineContent)
            } else {
                // Otherwise, create and save a new link reference.
                let linkReference = LinkReference(identifier: externalLinkIdentifier,
                                                  title: overridingTitle ?? link.absoluteString,
                                                  titleInlineContent: overridingTitleInlineContent ?? [.text(link.absoluteString)],
                                                  url: link.absoluteString)
                linkReferences[externalLinkIdentifier.identifier] = linkReference
                
                action = RenderInlineContent.reference(identifier: externalLinkIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            }
        } else {
            // This is an unresolved doc: URL. We render the link inactive by converting it to plain text,
            // as it may break routing or other downstream uses of the URL.
            action = RenderInlineContent.text(link.path)
        }
        
        return action
    }
    
    public mutating func visitTile(_ tile: Tile) -> RenderTree? {
        let action = tile.destination.map { visitLink($0, defaultTitle: RenderTile.defaultCallToActionTitle(for: tile.identifier)) }
        
        var section = RenderTile(identifier: .init(tileIdentifier: tile.identifier), title: tile.title, action: action, media: nil)
        section.content = visitMarkupContainer(tile.content) as! [RenderBlockContent]
        
        return section
    }
    
    public mutating func visitArticle(_ article: Article) -> RenderTree? {
        var node = RenderNode(identifier: identifier, kind: .article)
        // Contains symbol references declared in the Topics section.
        var topicSectionContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: identifier)
        
        node.metadata.title = article.title!.plainText
        
        // Detect the article modules from its breadcrumbs.
        var modules = Set<ResolvedTopicReference>()
        for reference in context.topicGraph.reverseEdgesGraph.breadthFirstSearch(from: identifier) {
            if let moduleReference = (try? context.entity(with: reference).semantic as? Symbol)?.moduleReference {
                modules.insert(moduleReference)
            }
        }
        
        let moduleNames = modules.compactMap { reference -> String? in
            guard let node = try? context.entity(with: reference) else { return nil }
            return node.name.plainText
        }
        if !moduleNames.isEmpty {
            node.metadata.modules = moduleNames.map({
                return RenderMetadata.Module(name: $0, relatedModules: nil)
            })
        }
        
        let documentationNode = try! context.entity(with: identifier)
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        let hierarchy = hierarchyTranslator.visitArticle(identifier)
        collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        node.hierarchy = hierarchy
        
        // Emit variants only if we're not compiling an article-only catalog to prevent renderers from
        // advertising the page as "Swift", which is the language DocC assigns to pages in article only pages.
        // (github.com/swiftlang/swift-docc/issues/240).
        if let topLevelModule = context.soleRootModuleReference,
           try! context.entity(with: topLevelModule).kind.isSymbol
        {
            node.variants = variants(for: documentationNode)
        }
        
        if let abstract = article.abstractSection,
            let abstractContent = visitMarkup(abstract.content) as? [RenderInlineContent] {
            node.abstract = abstractContent
        }
        
        if let discussion = article.discussion,
            let discussionContent = visitMarkupContainer(MarkupContainer(discussion.content)) as? [RenderBlockContent] {
            var title: String?
            if let first = discussionContent.first, case RenderBlockContent.heading = first {
                title = nil
            } else if shouldCreateAutomaticArticleSubheading(for: documentationNode) {
                // For articles hardcode an overview title unless the user explicitly
                // opts-out with the `@AutomaticArticleSubheading` directive.
                title = "Overview"
            }
            node.primaryContentSections.append(ContentRenderSection(kind: .content, content: discussionContent, heading: title))
        }
        
        node.topicSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: documentationNode.availableVariantTraits,
            fallbackDefaultValue: []
        ) { trait in
            let allowedTraits = documentationNode.availableVariantTraits.traitsCompatible(with: trait)
            
            var sections = [TaskGroupRenderSection]()
            
            if let topics = article.topics, !topics.taskGroups.isEmpty {
                // Don't set an eyebrow as collections and groups don't have one; append the authored Topics section
                sections.append(
                    contentsOf: renderGroups(
                        topics,
                        allowExternalLinks: false,
                        allowedTraits: allowedTraits,
                        availableTraits: documentationNode.availableVariantTraits,
                        contentCompiler: &topicSectionContentCompiler
                    )
                )
            }
            
            // Place "top" rendering preference automatic task groups
            // after any user-defined task groups but before automatic curation.
            if !article.automaticTaskGroups.isEmpty {
                sections.append(
                    contentsOf: renderAutomaticTaskGroupsSection(
                        article.automaticTaskGroups.filter { $0.renderPositionPreference == .top },
                        contentCompiler: &topicSectionContentCompiler
                    )
                )
            }
            
            // If there are no manually curated topics, and no automatic groups, try generating automatic groups by
            // child kind.
            if (article.topics == nil || article.topics?.taskGroups.isEmpty == true) &&
                article.automaticTaskGroups.isEmpty {
                // If there are no authored child topics in docs or markdown,
                // inspect the topic graph, find this node's children, and
                // for the ones found curate them automatically in task groups.
                // Automatic groups are named after the child's kind, e.g.
                // "Methods", "Variables", etc.
                let alreadyCurated = Set(node.topicSections.flatMap { $0.identifiers })
                let groups = try! AutomaticCuration.topics(
                    for: documentationNode,
                    withTraits: allowedTraits,
                    context: context
                ).compactMap { group -> AutomaticCuration.TaskGroup? in
                    // Remove references that have been already curated.
                    let newReferences = group.references.filter { !alreadyCurated.contains($0.absoluteString) }
                    // Remove groups that have no uncurated references
                    guard !newReferences.isEmpty else { return nil }
                    
                    return (title: group.title, references: newReferences)
                }
                
                // Collect all child topic references.
                topicSectionContentCompiler.collectedTopicReferences.append(contentsOf: groups.flatMap(\.references))
                // Add the final groups to the node.
                sections.append(contentsOf: groups.map(TaskGroupRenderSection.init(taskGroup:)))
            }
            
            // Place "bottom" rendering preference automatic task groups
            // after any user-defined task groups but before automatic curation.
            if !article.automaticTaskGroups.isEmpty {
                sections.append(
                    contentsOf: renderAutomaticTaskGroupsSection(
                        article.automaticTaskGroups.filter { $0.renderPositionPreference == .bottom },
                        contentCompiler: &topicSectionContentCompiler
                    )
                )
            }
            
            return sections
        } ?? .init(defaultValue: [])
        
        node.topicSectionsStyle = topicsSectionStyle(for: documentationNode)
        
        if shouldCreateAutomaticRoleHeading(for: documentationNode) {
            
            let role = DocumentationContentRenderer.roleForArticle(article, nodeKind: documentationNode.kind)
            node.metadata.role = role.rawValue
            
            switch role {
            case .article:
                // If there are no links to other nodes from the article,
                // set the eyebrow for articles.
                node.metadata.roleHeading = "Article"
            case .collectionGroup:
                // If the article links to other nodes, set the eyebrow for
                // API Collections if any linked node is a symbol.
                //
                // If none of the linked nodes are symbols (it's a plain collection),
                // don't display anything as the eyebrow title.
                let curatesSymbols = topicSectionContentCompiler.collectedTopicReferences.contains { topicReference in
                    context.topicGraph.nodeWithReference(topicReference)?.kind.isSymbol ?? false
                }
                if curatesSymbols {
                    node.metadata.roleHeading = "API Collection"
                }
            default:
                break
            }
        }
       
        if let pageImages = documentationNode.metadata?.pageImages {
            node.metadata.images = pageImages.compactMap { pageImage -> TopicImage? in
                let renderReference = createAndRegisterRenderReference(forMedia: pageImage.source)
                return renderReference.map {
                    TopicImage(pageImagePurpose: pageImage.purpose, identifier: $0)
                }
            }
        }
        
        if let pageColor = documentationNode.metadata?.pageColor {
            node.metadata.color = TopicColor(standardColorIdentifier: pageColor.rawValue)
        }

        var metadataCustomDictionary : [String: String] = [:]
        if let customMetadatas = documentationNode.metadata?.customMetadata {
            for elem in customMetadatas {
                metadataCustomDictionary[elem.key] = elem.value
            }
        }

        node.metadata.customMetadata = metadataCustomDictionary
        node.seeAlsoSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: documentationNode.availableVariantTraits,
            fallbackDefaultValue: []
        ) { trait in
            let allowedTraits = documentationNode.availableVariantTraits.traitsCompatible(with: trait)
            
            var seeAlsoSections = [TaskGroupRenderSection]()
            
            // Authored See Also section
            if let seeAlso = article.seeAlso, !seeAlso.taskGroups.isEmpty {
                seeAlsoSections.append(
                    contentsOf: renderGroups(
                        seeAlso,
                        allowExternalLinks: true,
                        allowedTraits: allowedTraits,
                        availableTraits: documentationNode.availableVariantTraits,
                        contentCompiler: &topicSectionContentCompiler
                    )
                )
            }
            
            // Automatic See Also section
            if let seeAlso = AutomaticCuration.seeAlso(
                for: documentationNode,
                withTraits: allowedTraits,
                context: context,
                bundle: bundle,
                renderContext: renderContext,
                renderer: contentRenderer
            ) {
                topicSectionContentCompiler.collectedTopicReferences.append(contentsOf: seeAlso.references)
                seeAlsoSections.append(TaskGroupRenderSection(taskGroup: seeAlso))
            }
            
            return seeAlsoSections
        } ?? .init(defaultValue: [])

        if let callToAction = article.metadata?.callToAction {
            if let url = callToAction.url {
                let downloadIdentifier = RenderReferenceIdentifier(url.description)
                node.sampleDownload = .init(
                    action: .reference(
                        identifier: downloadIdentifier,
                        isActive: true,
                        overridingTitle: callToAction.buttonLabel(for: article.metadata?.pageKind?.kind),
                        overridingTitleInlineContent: nil))
                downloadReferences[url.description] = DownloadReference(identifier: downloadIdentifier, verbatimURL: url, checksum: nil)
            } else if let fileReference = callToAction.file,
                      let downloadIdentifier = createAndRegisterRenderReference(forMedia: fileReference, assetContext: .download)
            {
                node.sampleDownload = .init(action: .reference(
                    identifier: downloadIdentifier,
                    isActive: true,
                    overridingTitle: callToAction.buttonLabel(for: article.metadata?.pageKind?.kind),
                    overridingTitleInlineContent: nil
                ))
            }
        }

        if let availability = article.metadata?.availability, !availability.isEmpty {
            let renderAvailability = availability.compactMap({
                let currentPlatform = PlatformName(metadataPlatform: $0.platform).flatMap { name in
                    context.externalMetadata.currentPlatforms?[name.displayName]
                }
                return .init($0, current: currentPlatform)
            }).sorted(by: AvailabilityRenderOrder.compare)

            if !renderAvailability.isEmpty {
                node.metadata.platformsVariants = .init(defaultValue: renderAvailability)
            }
        }
        
        if let pageKind = article.metadata?.pageKind {
            node.metadata.role = pageKind.kind.renderRole.rawValue
            node.metadata.roleHeading = pageKind.kind.titleHeading
        }
        
        if let titleHeading = article.metadata?.titleHeading {
            node.metadata.roleHeading = titleHeading.heading
        } 
        
        collectedTopicReferences.append(contentsOf: topicSectionContentCompiler.collectedTopicReferences)
        node.references = createTopicRenderReferences()

        addReferences(imageReferences, to: &node)
        addReferences(videoReferences, to: &node)
        addReferences(linkReferences, to: &node)
        addReferences(downloadReferences, to: &node)
        // See Also can contain external links, we need to separately transfer
        // link references from the content compiler
        addReferences(topicSectionContentCompiler.linkReferences, to: &node)

        return node
    }
    
    public mutating func visitTutorialArticle(_ article: TutorialArticle) -> RenderTree? {
        var node = RenderNode(identifier: identifier, kind: .article)
        
        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        guard let hierarchy = hierarchyTranslator.visitTechnologyNode(identifier) else {
            // This tutorial article is not curated, so we don't generate a render node.
            // We've warned about this during semantic analysis.
            return nil
        }
        
        let technology = try! context.entity(with: hierarchy.technology).semantic as! Technology
        
        node.metadata.title = article.title
        
        node.metadata.category = technology.name
        node.metadata.categoryPathComponent = hierarchy.technology.url.lastPathComponent
        node.metadata.role = DocumentationContentRenderer.role(for: .tutorialArticle).rawValue
        
        // Unlike for other pages, in here we use `RenderHierarchyTranslator` to crawl the technology
        // and produce the list of modules for the render hierarchy to display in the tutorial local navigation.
        node.hierarchy = hierarchy.hierarchy
        
        let documentationNode = try! context.entity(with: identifier)
        node.variants = variants(for: documentationNode)
        
        collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        
        var intro: IntroRenderSection
        if let articleIntro = article.intro {
            intro = visitIntro(articleIntro) as! IntroRenderSection
        } else {
            // Create a default intro section so that it's not an error to skip writing one.
            intro = IntroRenderSection(title: "")
        }
        
        if let time = article.durationMinutes {
            intro.estimatedTimeInMinutes = time
        }
        
        // Guaranteed to have at least one path
        let technologyPath = context.finitePaths(to: identifier, options: [.preferTechnologyRoot])[0]
                
        node.sections.append(intro)
        
        let layouts = contentLayouts(article.content)
        
        let articleSection = TutorialArticleSection(content: layouts)
        
        node.sections.append(articleSection)
        
        if let assessments = article.assessments {
            node.sections.append(visitAssessments(assessments) as! TutorialAssessmentsRenderSection)
        }
        
        if technologyPath.count >= 2 {
            let volume = technologyPath[technologyPath.count - 2]
            
            if let cta = callToAction(with: article.callToActionImage, volume: volume) {
                node.sections.append(cta)
            }
        }
        
        node.references = createTopicRenderReferences()

        addReferences(fileReferences, to: &node)
        addReferences(imageReferences, to: &node)
        addReferences(videoReferences, to: &node)
        addReferences(requirementReferences, to: &node)
        addReferences(downloadReferences, to: &node)
        addReferences(linkReferences, to: &node)
        
        return node
    }
    
    private mutating func contentLayouts(_ markupLayouts: some Sequence<MarkupLayout>) -> [ContentLayout] {
        return markupLayouts.map { content in
            switch content {
            case .markup(let markup):
                return .fullWidth(content: visitMarkupContainer(markup) as! [RenderBlockContent])
            case .contentAndMedia(let contentAndMedia):
                return .contentAndMedia(content: visitContentAndMedia(contentAndMedia) as! ContentAndMediaSection)
            case .stack(let stack):
                return .columns(content: self.visitStack(stack) as! [ContentAndMediaSection])
            }
        }
    }
    
    public mutating func visitStack(_ stack: Stack) -> RenderTree? {
        return stack.contentAndMedia.map { self.visitContentAndMedia($0) as! ContentAndMediaSection } as [ContentAndMediaSection]
    }
    
    public mutating func visitComment(_ comment: Comment) -> RenderTree? {
        return nil
    }
    
    public mutating func visitDeprecationSummary(_ summary: DeprecationSummary) -> RenderTree? {
        return nil
    }

    /// Renders automatically generated task groups
    private mutating func renderAutomaticTaskGroupsSection(_ taskGroups: [AutomaticTaskGroupSection], contentCompiler: inout RenderContentCompiler) -> [TaskGroupRenderSection] {
        return taskGroups.map { group in
            contentCompiler.collectedTopicReferences.append(contentsOf: group.references)
            return TaskGroupRenderSection(
                title: group.title,
                abstract: nil,
                discussion: nil,
                identifiers: group.references.map(\.url.absoluteString),
                generated: true,
                anchor: urlReadableFragment(group.title)
            )
        }
    }
    
    /// Renders a list of topic groups.
    ///
    /// When rendering topic groups for a page that is available in multiple languages,
    /// you can provide the total available traits the parent page will be available in,
    /// as well as the _specific_ traits this particular render section should be created for.
    /// Any referenced pages that are included in the _available_ traits
    /// but excluded from the _allowed_ traits will be filtered out.
    ///
    /// This behavior is designed to ensure that all items in the task group will be rendered
    /// in _some_ task group of the parent page, whether in the currently provided allowed traits,
    /// or in a different subset of the page's available traits.
    /// However, if a task-group item's language isn't included in any of the available traits,
    /// it will _not_ be filtered out since otherwise it would be invisible to the reader
    /// of the documentation regardless of which of the available traits they view.
    ///
    /// - Parameters:
    ///   - topics: The topic groups to be rendered.
    ///
    ///   - allowExternalLinks: Whether or not external links should be included in the
    ///     rendered task groups.
    ///
    ///   - allowedTraits: The traits that the returned render section should filter for.
    ///
    ///     These traits should be a _subset_ of the given available traits.
    ///
    ///   - availableTraits: The traits that are available in the parent page that this render
    ///     section belongs to.
    ///
    ///     This method will only filter for allowed traits that are also explicitly available.
    ///
    ///   - contentCompiler: The current render content compiler.
    private mutating func renderGroups(
        _ topics: GroupedSection,
        allowExternalLinks: Bool,
        allowedTraits: Set<DocumentationDataVariantsTrait>,
        availableTraits: Set<DocumentationDataVariantsTrait>,
        contentCompiler: inout RenderContentCompiler
    ) -> [TaskGroupRenderSection] {
        return topics.taskGroups.compactMap { group in
            let supportedLanguages = group.directives[SupportedLanguage.directiveName]?.compactMap {
                SupportedLanguage(from: $0, source: nil, for: bundle, in: context)?.language
            }
            
            // If the task group has a set of supported languages, see if it should render for the allowed traits.
            if supportedLanguages?.matchesOneOf(traits: allowedTraits) == false {
                return nil
            }
            
            let abstractContent = group.abstract.map {
                return visitMarkup($0.content) as! [RenderInlineContent]
            }
            
            let discussion = group.discussion.map { discussion -> ContentRenderSection in
                let discussionContent = visitMarkupContainer(MarkupContainer(discussion.content)) as! [RenderBlockContent]
                return ContentRenderSection(kind: .content, content: discussionContent, heading: "Discussion")
            }
            
            /// Returns whether the topic with the given identifier is available in one of the traits in `allowedTraits`.
            func isTopicAvailableInAllowedTraits(identifier topicIdentifier: String) -> Bool {
                guard let reference = contentCompiler.collectedTopicReferences[topicIdentifier] else {
                    // If there's no reference in `contentCompiler.collectedTopicReferences`, the reference refers to
                    // a non-documentation URL (e.g., 'https://' URL), in which case it is available in all traits.
                    return true
                }
                
                guard context.isSymbol(reference: reference) else {
                    // If the reference corresponds to any kind except Symbol
                    // (e.g., Article, Tutorial, SampleCode...), allow the topic
                    // to appear independently of the source language it belongs to.
                    return true
                }
                
                let referenceSourceLanguageIDs = Set(context.sourceLanguages(for: reference).map(\.id))
                
                let availableSourceLanguageTraits = Set(availableTraits.compactMap(\.interfaceLanguage))
                if availableSourceLanguageTraits.isDisjoint(with: referenceSourceLanguageIDs) {
                    // The set of available source language traits has no members in common with the
                    // set of source languages the given reference is available in.
                    //
                    // Since we should only filter for traits that are available in the parent page,
                    // just return true. (See the documentation of this method for more details).
                    return true
                }
                
                return referenceSourceLanguageIDs.contains { sourceLanguageID in
                    allowedTraits.contains { trait in
                        trait.interfaceLanguage == sourceLanguageID
                    }
                }
            }
            
            let taskGroupRenderSection = TaskGroupRenderSection(
                title: group.heading?.plainText,
                abstract: abstractContent,
                discussion: discussion,
                identifiers: group.links.compactMap { link in
                    switch link {
                    case let link as Link:
                        if !allowExternalLinks {
                            // For links require documentation scheme
                            guard let _ = link.destination.flatMap(ValidatedURL.init(parsingAuthoredLink:))?.requiring(scheme: ResolvedTopicReference.urlScheme) else {
                                return nil
                            }
                        }
                        
                        if let referenceInlines = contentCompiler.visitLink(link) as? [RenderInlineContent],
                           let renderReference = referenceInlines.first(where: { inline in
                               switch inline {
                               case .reference(_,_,_,_):
                                   return true
                               default:
                                   return false
                               }
                           }),
                           case let RenderInlineContent.reference(
                             identifier: identifier,
                             isActive: _,
                             overridingTitle: _,
                             overridingTitleInlineContent: _
                           ) = renderReference
                        {
                            return isTopicAvailableInAllowedTraits(identifier: identifier.identifier)
                                ? identifier.identifier : nil
                        }
                    case let link as SymbolLink:
                        if let referenceInlines = contentCompiler.visitSymbolLink(link) as? [RenderInlineContent],
                           let renderReference = referenceInlines.first(where: { inline in
                               switch inline {
                               case .reference:
                                   return true
                               default:
                                   return false
                               }
                           }),
                           case let RenderInlineContent.reference(
                             identifier: identifier,
                             isActive: _,
                             overridingTitle: _,
                             overridingTitleInlineContent: _
                           ) = renderReference
                        {
                            return isTopicAvailableInAllowedTraits(identifier: identifier.identifier)
                                ? identifier.identifier : nil
                        }
                    default: break
                    }
                    return nil
                },
                anchor: group.heading.map { urlReadableFragment($0.plainText) } ?? "Topics"
            )
            
            // rdar://74617294 If a task group doesn't have any symbol or external links it shouldn't be rendered
            guard !taskGroupRenderSection.identifiers.isEmpty else {
                return nil
            }
            
            return taskGroupRenderSection
        }
    }
    
    @discardableResult
    private mutating func collectUnresolvableSymbolReference(destination: UnresolvedTopicReference, title: String) -> UnresolvedTopicReference? {
        guard let url = ValidatedURL(destination.topicURL.url) else {
            return nil
        }
        
        let reference = UnresolvedTopicReference(topicURL: url, title: title)
        collectedUnresolvedTopicReferences.append(reference)
        
        return reference
    }
    
    private func shouldCreateAutomaticRoleHeading(for node: DocumentationNode) -> Bool {
        return node.options?.automaticTitleHeadingEnabled
            ?? context.options?.automaticTitleHeadingEnabled
            ?? true
    }
    
    private func shouldCreateAutomaticArticleSubheading(for node: DocumentationNode) -> Bool {
        return node.options?.automaticArticleSubheadingEnabled
            ?? context.options?.automaticArticleSubheadingEnabled
            ?? true
    }
    
    private func topicsSectionStyle(for node: DocumentationNode) -> RenderNode.TopicsSectionStyle {
        let topicsVisualStyleOption: TopicsVisualStyle.Style
        if let topicsSectionStyleOption = node.options?.topicsVisualStyle
            ?? context.options?.topicsVisualStyle
        {
            topicsVisualStyleOption = topicsSectionStyleOption
        } else {
            topicsVisualStyleOption = .list
        }
        
        switch topicsVisualStyleOption {
        case .list:
            return .list
        case .compactGrid:
            return .compactGrid
        case .detailedGrid:
            return .detailedGrid
        case .hidden:
            return .hidden
        }
    }
    
    public mutating func visitSymbol(_ symbol: Symbol) -> RenderTree? {
        let documentationNode = try! context.entity(with: identifier)
        
        let identifier = identifier.addingSourceLanguages(documentationNode.availableSourceLanguages)
        
        var node = RenderNode(identifier: identifier, kind: .symbol)
        var contentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: identifier)
        
        /*
         FIXME: We shouldn't be doing this kind of crawling here.
         
         We should be doing a graph search to build up a breadcrumb and pass that to the translator, giving
         a definitive hierarchy before we even begin to build a RenderNode.
         */
        var ref = documentationNode.reference
        while let grandparent = context.parents(of: ref).first {
            ref = grandparent
        }
        
        let moduleName = context.moduleName(forModuleReference: symbol.moduleReference)

        if let crossImportOverlayModule = symbol.crossImportOverlayModule {
            node.metadata.modulesVariants = VariantCollection(defaultValue: [RenderMetadata.Module(name: crossImportOverlayModule.declaringModule, relatedModules: crossImportOverlayModule.bystanderModules)])

        } else if let moduleVariants = VariantCollection<[RenderMetadata.Module]?>(
            from: symbol.extendedModuleVariants,
            transform: { (_, value) in
                let relatedModules: [String]?
                // Don't add the module name of extensions made in the compiled module.
                if (value != moduleName.displayName) && (value != moduleName.symbolName) {
                    relatedModules = [value]
                } else {
                    relatedModules = nil
                }
                return [
                    RenderMetadata.Module(name: moduleName.displayName, relatedModules: relatedModules)
                ]
            }
        ) {
            node.metadata.modulesVariants = moduleVariants
        } else {
            node.metadata.modulesVariants = VariantCollection(defaultValue: [RenderMetadata.Module(name: moduleName.displayName, relatedModules: nil)])
        }

        node.metadata.extendedModuleVariants = VariantCollection<String?>(from: symbol.extendedModuleVariants)
        
        node.metadata.platformsVariants = VariantCollection<[AvailabilityRenderItem]?>(from: symbol.availabilityVariants) { _, availability in
            availability.availability
                .compactMap { availability -> AvailabilityRenderItem? in
                    // Filter items with insufficient availability data
                    guard availability.introducedVersion != nil else {
                        return nil
                    }
                    guard let name = availability.domain.map({ PlatformName(operatingSystemName: $0.rawValue) }),
                          let currentPlatform = context.externalMetadata.currentPlatforms?[name.displayName] else {
                              // No current platform provided by the context
                              return AvailabilityRenderItem(availability, current: nil)
                          }
                    
                    return AvailabilityRenderItem(availability, current: currentPlatform)
                }
                .filter({ !($0.unconditionallyUnavailable == true) })
                .sorted(by: AvailabilityRenderOrder.compare)
        } ?? .init(defaultValue:
            defaultAvailability(for: bundle, moduleName: moduleName.symbolName, currentPlatforms: context.externalMetadata.currentPlatforms)?
                .filter({ !($0.unconditionallyUnavailable == true) })
                .sorted(by: AvailabilityRenderOrder.compare)
        )

        if let availability = documentationNode.metadata?.availability, !availability.isEmpty {
            let renderAvailability = availability.compactMap({
                let currentPlatform = PlatformName(metadataPlatform: $0.platform).flatMap { name in
                    context.externalMetadata.currentPlatforms?[name.displayName]
                }
                return .init($0, current: currentPlatform)
            }).sorted(by: AvailabilityRenderOrder.compare)

            if !renderAvailability.isEmpty {
                node.metadata.platformsVariants.defaultValue = renderAvailability
            }
        }
        
        node.metadata.requiredVariants = VariantCollection<Bool>(from: symbol.isRequiredVariants) ?? .init(defaultValue: false)
        node.metadata.role = DocumentationContentRenderer.role(for: documentationNode.kind).rawValue
        node.metadata.titleVariants = VariantCollection<String?>(from: symbol.titleVariants)
        node.metadata.externalIDVariants = VariantCollection<String?>(from: symbol.externalIDVariants)
        
        if shouldCreateAutomaticRoleHeading(for: documentationNode) {
            node.metadata.roleHeadingVariants = VariantCollection<String?>(from: symbol.roleHeadingVariants)
        }

        if let titleHeading = documentationNode.metadata?.titleHeading {
            node.metadata.roleHeadingVariants = VariantCollection<String?>(defaultValue: titleHeading.heading)
        }
        
        node.metadata.symbolKindVariants = VariantCollection<String?>(from: symbol.kindVariants) { _, kindVariants in
            kindVariants.identifier.renderingIdentifier
        } ?? .init(defaultValue: nil)
        
        node.metadata.conformance = contentRenderer.conformanceSectionFor(identifier, collectedConstraints: collectedConstraints)
        node.metadata.fragmentsVariants = contentRenderer.subHeadingFragments(for: documentationNode)
        node.metadata.navigatorTitleVariants = contentRenderer.navigatorFragments(for: documentationNode)
        
        if let pageImages = documentationNode.metadata?.pageImages {
            node.metadata.images = pageImages.compactMap { pageImage -> TopicImage? in
                let renderReference = createAndRegisterRenderReference(forMedia: pageImage.source)
                return renderReference.map {
                    TopicImage(pageImagePurpose: pageImage.purpose, identifier: $0)
                }
            }
        }
        
        if let pageColor = documentationNode.metadata?.pageColor {
            node.metadata.color = TopicColor(standardColorIdentifier: pageColor.rawValue)
        }

        var metadataCustomDictionary : [String: String] = [:]
        if let customMetadatas = documentationNode.metadata?.customMetadata {
            for elem in customMetadatas {
                metadataCustomDictionary[elem.key] = elem.value
            }
        }

        node.metadata.customMetadata = metadataCustomDictionary
        node.variants = variants(for: documentationNode)
        
        collectedTopicReferences.append(identifier)
        
        let contentRenderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        node.metadata.tags = contentRenderer.tags(for: identifier)

        var hierarchyTranslator = RenderHierarchyTranslator(context: context, bundle: bundle)
        let hierarchy = hierarchyTranslator.visitSymbol(identifier)
        collectedTopicReferences.append(contentsOf: hierarchyTranslator.collectedTopicReferences)
        node.hierarchy = hierarchy
        
        // In case `inheritDocs` is disabled and there is actually origin data for the symbol, then include origin information as abstract.
        // Generate the placeholder abstract only in case there isn't an authored abstract coming from a doc extension.
        if !context.externalMetadata.inheritDocs, let origin = (documentationNode.semantic as! Symbol).origin, symbol.abstractSection == nil {
            // Create automatic abstract for inherited symbols.
            node.abstract = [.text("Inherited from "), .codeVoice(code: origin.displayName), .text(".")]
        } else {
            node.abstractVariants = VariantCollection<[RenderInlineContent]?>(
                from: symbol.abstractSectionVariants
            ) { _, abstractSection in
                // Create an abstract as usual.
                let abstract = abstractSection.content
                
                if let abstractContent = visitMarkup(abstract) as? [RenderInlineContent] {
                    return abstractContent
                } else {
                    return nil
                }
            } ?? .init(defaultValue: nil)
        }
        
        node.primaryContentSectionsVariants.append(
            contentsOf: createRenderSections(
                for: symbol,
                renderNode: &node,
                translators: [
                    DeclarationsSectionTranslator(),
                    HTTPEndpointSectionTranslator(endpointType: .production),
                    HTTPEndpointSectionTranslator(endpointType: .sandbox),
                    ParametersSectionTranslator(),
                    HTTPParametersSectionTranslator(parameterSource: .path),
                    HTTPParametersSectionTranslator(parameterSource: .query),
                    HTTPParametersSectionTranslator(parameterSource: .cookie),
                    HTTPParametersSectionTranslator(parameterSource: .header),
                    HTTPBodySectionTranslator(),
                    HTTPResponsesSectionTranslator(),
                    PlistDetailsSectionTranslator(),
                    PossibleValuesSectionTranslator(),
                    DictionaryKeysSectionTranslator(),
                    AttributesSectionTranslator(),
                    ReturnsSectionTranslator(),
                    MentionsSectionTranslator(referencingSymbol: identifier),
                    DiscussionSectionTranslator(),
                ]
            )
        )
        
        var sourceRepository = sourceRepository
        
        if shouldEmitSymbolSourceFileURIs {
            node.metadata.sourceFileURIVariants = VariantCollection<String?>(
                from: symbol.locationVariants
            ) { _, location in
                location.uri
            } ?? .init(defaultValue: nil)
            
            // If a source repository is not set, set the device's
            // filesystem as the source repository. This causes
            // the `metadata.remoteSource` property to link to the
            // file's location on disk.
            if sourceRepository == nil {
                sourceRepository = .localFilesystem()
            }
        }
        
        if let sourceRepository {
            node.metadata.remoteSourceVariants = VariantCollection<RenderMetadata.RemoteSource?>(
                from: symbol.locationVariants
            ) { _, location in
                guard let locationURL = location.url(),
                      let url = sourceRepository.format(
                        sourceFileURL: locationURL,
                        lineNumber: location.position.line + 1
                      )
                else {
                    return nil
                }
                
                return RenderMetadata.RemoteSource(
                    fileName: locationURL.lastPathComponent,
                    url: url
                )
            } ?? .init(defaultValue: nil)
        }
        
        if shouldEmitSymbolAccessLevels {
            node.metadata.symbolAccessLevelVariants = VariantCollection<String?>(from: symbol.accessLevelVariants)
        }
        
        if let externalID = symbol.externalID,
           let symbolIdentifiersWithExpandedDocumentation
        {
            node.metadata.hasNoExpandedDocumentation = !symbolIdentifiersWithExpandedDocumentation.contains(externalID)
        }
        
        node.relationshipSectionsVariants = VariantCollection<[RelationshipsRenderSection]>(
            from: documentationNode.availableVariantTraits,
            fallbackDefaultValue: []
        ) { trait in
            guard let relationships = symbol.relationshipsVariants[trait], !relationships.groups.isEmpty else {
                return []
            }
            
            var groupSections = [RelationshipsRenderSection]()
            
            let eligibleGroups = relationships.groups.sorted(by: \.sectionOrder)
            
            for group in eligibleGroups {
                // destination url → symbol title
                var destinationsMap = [TopicReference: String]()
                
                for destination in group.destinations {
                    if let constraints = relationships.constraints[destination] {
                        collectedConstraints[destination] = constraints
                    }
                    
                    switch destination {
                    case .resolved(.success(let resolved)):
                        if let node = context.documentationCache[resolved] {
                            let resolver = LinkTitleResolver(context: context, source: resolved.url)
                            let resolvedTitle = resolver.title(for: node)
                            destinationsMap[destination] = resolvedTitle?[trait]
                            
                            let dropLink = context.topicGraph.nodeWithReference(resolved)?.isEmptyExtension ?? false
                            
                            if !dropLink {
                                // Add relationship to render references
                                collectedTopicReferences.append(resolved)
                            } else if let topicUrl = ValidatedURL(resolved.url) {
                                // If the topic isn't linkable (e.g. an extended type), then we shouldn't
                                // add a resolved relationship - deconstruct the resolved reference so
                                // we can still display it, though
                                let title = resolvedTitle?[trait] ?? resolved.lastPathComponent
                                let reference = UnresolvedTopicReference(topicURL: topicUrl, title: title)
                                collectedUnresolvedTopicReferences.append(reference)
                            }
                        } else if let entity = context.externalCache[resolved] {
                            collectedTopicReferences.append(resolved)
                            destinationsMap[destination] = entity.topicRenderReference.title
                        } else {
                            fatalError("A successfully resolved reference should have either local or external content.")
                        }

                    case .unresolved(let unresolved), .resolved(.failure(let unresolved, _)):
                        // Try creating a render reference anyway
                        if let title = relationships.targetFallbacks[destination],
                           let reference = collectUnresolvableSymbolReference(destination: unresolved, title: title) {
                            destinationsMap[destination] = reference.title
                        }
                    }
                }
                
                // Links section
                var orderedDestinations = Array(destinationsMap.keys)
                orderedDestinations.sort { destination1, destination2 -> Bool in
                    return destinationsMap[destination1]! <= destinationsMap[destination2]!
                }
                let groupSection = RelationshipsRenderSection(type: group.kind.rawValue, title: group.heading.plainText, identifiers: orderedDestinations.map({ $0.url!.absoluteString }))
                groupSections.append(groupSection)
            }
            
            return groupSections
        } ?? .init(defaultValue: [])
        
        // Build up the topic section variants by iterating over all available
        // variant traits.
        //
        // We can't just iterate over the traits of the existing
        // topics section or automatic task groups, because it's important
        // for automatic curation to consider _all_ variants this node is available in.
        node.topicSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: documentationNode.availableVariantTraits,
            fallbackDefaultValue: []
        ) { trait in
            let allowedTraits = documentationNode.availableVariantTraits.traitsCompatible(with: trait)
            
            let automaticTaskGroups = symbol.automaticTaskGroupsVariants[trait] ?? []
            let topics = symbol.topicsVariants[trait]
            
            var sections = [TaskGroupRenderSection]()
            if let topics, !topics.taskGroups.isEmpty {
                // Allowed symbol traits should be all traits except the reverse of the objc/swift pairing
                sections.append(
                    contentsOf: renderGroups(
                        topics,
                        allowExternalLinks: false,
                        allowedTraits: allowedTraits,
                        availableTraits: documentationNode.availableVariantTraits,
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            // Place "top" rendering preference automatic task groups
            // after any user-defined task groups but before automatic curation.
            if !automaticTaskGroups.isEmpty {
                sections.append(
                    contentsOf: renderAutomaticTaskGroupsSection(
                        automaticTaskGroups.filter({ $0.renderPositionPreference == .top }),
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            // Children of the current symbol that have not been curated manually in a task group will all
            // be automatically curated in task groups after their symbol kind: "Properties", "Enumerations", etc.
            let groups = try! AutomaticCuration.topics(for: documentationNode, withTraits: allowedTraits, context: context)
            
            for group in groups {
                let newReferences = group.references
                contentCompiler.collectedTopicReferences.append(contentsOf: newReferences)

                // If the section has been manually curated, merge the references of both the automatic curation and the manual curation into one section (rdar://61899214).
                if let duplicateSectionIndex = sections.firstIndex(where: { $0.title == group.title }) {
                    let originalSection = sections[duplicateSectionIndex]
                    // Combining all references here without checking for duplicates should be safe,
                    // because the automatic curation of topics only returns symbols that haven't already been manually curated.
                    let combinedReferences = originalSection.identifiers + newReferences.map { $0.absoluteString }
                    sections[duplicateSectionIndex] = TaskGroupRenderSection(title: originalSection.title, abstract: originalSection.abstract, discussion: originalSection.discussion, identifiers: combinedReferences)
                } else {
                    sections.append(TaskGroupRenderSection(taskGroup: (title: group.title, references: newReferences)))
                }
            }
            
            // Place "bottom" rendering preference automatic task groups
            // after any user-defined task groups but before automatic curation.
            if !automaticTaskGroups.isEmpty {
                sections.append(
                    contentsOf: renderAutomaticTaskGroupsSection(
                        automaticTaskGroups.filter({ $0.renderPositionPreference == .bottom }),
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            return sections
        } ?? .init(defaultValue: [])
        
        node.topicSectionsStyle = topicsSectionStyle(for: documentationNode)
        
        node.defaultImplementationsSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: symbol.defaultImplementationsVariants,
            symbol.relationshipsVariants
        ) { _, defaultImplementations, relationships in
            guard !symbol.defaultImplementations.groups.isEmpty else {
                return []
            }
            
            for imp in defaultImplementations.implementations {
                let resolved: ResolvedTopicReference
                switch imp.reference {
                case .resolved(.success(let reference)):
                    resolved = reference
                case .unresolved(let unresolved), .resolved(.failure(let unresolved, _)):
                    // Try creating a render reference anyway
                    if let title = defaultImplementations.targetFallbacks[imp.reference],
                       let reference = collectUnresolvableSymbolReference(destination: unresolved, title: title),
                       let constraints = relationships.constraints[imp.reference] {
                        collectedConstraints[.unresolved(reference)] = constraints
                    }
                    continue
                }
                
                // Add implementation to render references
                collectedTopicReferences.append(resolved)
                if let constraints = relationships.constraints[imp.reference] {
                    collectedConstraints[.successfullyResolved(resolved)] = constraints
                }
            }
            
            return defaultImplementations.groups.map { group in
                TaskGroupRenderSection(
                    title: group.heading,
                    abstract: nil,
                    discussion: nil,
                    identifiers: group.references.map({ $0.url!.absoluteString }),
                    anchor: urlReadableFragment(group.heading)
                )
            }
        } ?? .init(defaultValue: [])

        node.seeAlsoSectionsVariants = VariantCollection<[TaskGroupRenderSection]>(
            from: documentationNode.availableVariantTraits,
            fallbackDefaultValue: []
        ) { trait in
            let allowedTraits = documentationNode.availableVariantTraits.traitsCompatible(with: trait)
            
            // If the symbol contains an authored See Also section from the documentation extension,
            // add it as the first section under See Also.
            var seeAlsoSections = [TaskGroupRenderSection]()
            
            if let seeAlso = symbol.seeAlsoVariants[trait] {
                seeAlsoSections.append(
                    contentsOf: renderGroups(
                        seeAlso,
                        allowExternalLinks: true,
                        allowedTraits: allowedTraits,
                        availableTraits: documentationNode.availableVariantTraits,
                        contentCompiler: &contentCompiler
                    )
                )
            }
            
            // Curate the current node's siblings as further See Also groups.
            if let seeAlso = AutomaticCuration.seeAlso(
                for: documentationNode,
                withTraits: allowedTraits,
                context: context,
                bundle: bundle,
                renderContext: renderContext,
                renderer: contentRenderer
            ), !seeAlso.references.isEmpty {
                contentCompiler.collectedTopicReferences.append(contentsOf: seeAlso.references)
                seeAlsoSections.append(
                    TaskGroupRenderSection(taskGroup: seeAlso)
                )
            }
            
            return seeAlsoSections
        } ?? .init(defaultValue: [])
        
        node.deprecationSummaryVariants = VariantCollection<[RenderBlockContent]?>(
            from: symbol.deprecatedSummaryVariants
        ) { _, deprecatedSummary in
            // If there is a deprecation summary in a documentation extension file add it to the render node
            visitMarkupContainer(MarkupContainer(deprecatedSummary.content)) as? [RenderBlockContent]
        } ?? .init(defaultValue: nil)
        
        collectedTopicReferences.append(contentsOf: contentCompiler.collectedTopicReferences)
        node.references = createTopicRenderReferences()
        
        addReferences(imageReferences, to: &node)
        addReferences(videoReferences, to: &node)
        // See Also can contain external links, we need to separately transfer
        // link references from the content compiler
        addReferences(contentCompiler.linkReferences, to: &node)
        addReferences(linkReferences, to: &node)
        
        return node
    }

    /// Creates a render reference for the given media and registers the reference to include it in the `references` dictionary.
    mutating func createAndRegisterRenderReference(forMedia media: ResourceReference?, poster: ResourceReference? = nil, altText: String? = nil, assetContext: DataAsset.Context = .display) -> RenderReferenceIdentifier? {
        guard let oldMedia = media,
              let mediaIdentifier = context.identifier(forAssetName: oldMedia.path, in: identifier) else {
            return nil
        }
        
        let media = ResourceReference(bundleIdentifier: oldMedia.bundleIdentifier, path: mediaIdentifier)
        guard let resolvedAssets = renderContext?.store.content(forAssetNamed: media.path, bundleIdentifier: identifier.bundleIdentifier)
                                ?? context.resolveAsset(named: media.path, in: identifier)
        else {
            return nil
        }
        
        let fileExtension: String = {
            let identifierFileExtension = NSString(string: media.path).pathExtension
            if !identifierFileExtension.isEmpty {
                return identifierFileExtension
            }
            return resolvedAssets.data(bestMatching: DataTraitCollection()).url.pathExtension
        }()
        
        // Check if media is a supported image.
        if DocumentationContext.isFileExtension(fileExtension, supported: .image) {
            let mediaReference = RenderReferenceIdentifier(media.path)
            
            imageReferences[media.path] = ImageReference(
                identifier: mediaReference,
                // If no alt text has been provided and this image has been registered previously, use the registered alt text.
                altText: altText ?? imageReferences[media.path]?.altText,
                imageAsset: resolvedAssets
            )
            return mediaReference
        }
        
        if DocumentationContext.isFileExtension(fileExtension, supported: .video) {
            let mediaReference = RenderReferenceIdentifier(media.path)
            let poster = poster.flatMap { createAndRegisterRenderReference(forMedia: $0) }
            videoReferences[media.path] = VideoReference(identifier: mediaReference, altText: altText, videoAsset: resolvedAssets, poster: poster)
            return mediaReference
        }
        
        if assetContext == DataAsset.Context.download {
            let mediaReference = RenderReferenceIdentifier(media.path)
            // Create a download reference if possible.
            let downloadReference: DownloadReference
            do {
                let downloadURL = resolvedAssets.variants.first!.value
                let downloadData = try context.dataProvider.contentsOfURL(downloadURL, in: bundle)
                downloadReference = DownloadReference(identifier: mediaReference,
                    renderURL: downloadURL,
                    checksum: Checksum.sha512(of: downloadData))
            } catch {
                // It seems this is the way to error out of here.
                return nil
            }

            // Add the file to the download references.
            downloadReferences[media.path] = downloadReference
            return mediaReference
        }

        return nil
    }
    
    var context: DocumentationContext
    var bundle: DocumentationBundle
    var identifier: ResolvedTopicReference
    var imageReferences: [String: ImageReference] = [:]
    var videoReferences: [String: VideoReference] = [:]
    var fileReferences: [String: FileReference] = [:]
    var linkReferences: [String: LinkReference] = [:]
    var requirementReferences: [String: XcodeRequirementReference] = [:]
    var downloadReferences: [String: DownloadReference] = [:]
    
    private var bundleAvailability: [BundleModuleIdentifier: [AvailabilityRenderItem]] = [:]
    
    /// Given module availability and the current platforms we're building against return if the module is a beta framework.
    private func isModuleBeta(moduleAvailability: DefaultAvailability.ModuleAvailability, currentPlatforms: [String: PlatformVersion]) -> Bool {
        guard let introducedVersion = moduleAvailability.introducedVersion else { return false }
        guard
            // Check if we have a symbol availability version and a target platform version
            let moduleVersion = Version(versionString: introducedVersion),
            // We require at least two components for a platform version (e.g. 10.15 or 10.15.1)
            moduleVersion.count >= 2,
            // Verify we're building against this platform
            let targetPlatformVersion = currentPlatforms[moduleAvailability.platformName.displayName],
            // Verify the target platform version is in beta
            targetPlatformVersion.beta else {
                return false
        }
        
        // Build a module availability version, defaulting the patch number to 0 if not provided (e.g. 10.15)
        let moduleVersionTriplet = VersionTriplet(moduleVersion[0], moduleVersion[1], moduleVersion.count > 2 ? moduleVersion[2] : 0)
        
        // Consider the module beta if its version is greater than or equal to the target platform
        return moduleVersionTriplet >= targetPlatformVersion.version
    }
    
    /// The default availability for modules in a given bundle and module.
    mutating func defaultAvailability(for bundle: DocumentationBundle, moduleName: String, currentPlatforms: [String: PlatformVersion]?) -> [AvailabilityRenderItem]? {
        let identifier = BundleModuleIdentifier(bundle: bundle, moduleName: moduleName)
        
        // Cached availability
        if let availability = bundleAvailability[identifier] {
            return availability
        }
        
        // Find default module availability if existing
        guard let bundleDefaultAvailability = bundle.info.defaultAvailability,
            let moduleAvailability = bundleDefaultAvailability.modules[moduleName] else {
            return nil
        }
        
        // Prepare for rendering
        let renderedAvailability = moduleAvailability
            .filter({ $0.versionInformation != .unavailable })
            .compactMap({ availability -> AvailabilityRenderItem? in
                guard let availabilityIntroducedVersion = availability.introducedVersion else { return nil }
                return AvailabilityRenderItem(
                    name: availability.platformName.displayName,
                    introduced: availabilityIntroducedVersion,
                    isBeta: currentPlatforms.map({ isModuleBeta(moduleAvailability: availability, currentPlatforms: $0) }) ?? false
                )
            })
        
        // Cache the availability to use for further symbols
        bundleAvailability[identifier] = renderedAvailability
        
        // Return the availability
        return renderedAvailability
    }
   
    mutating func createRenderSections(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        translators: [RenderSectionTranslator]
    ) -> [VariantCollection<CodableContentSection?>] {
        translators.compactMap { translator in
            translator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &self)
        }
    }
    
    private func variants(for documentationNode: DocumentationNode) -> [RenderNode.Variant] {
        let generator = PresentationURLGenerator(context: context, baseURL: bundle.baseURL)
        
        return documentationNode.availableSourceLanguages
            .sorted(by: { language1, language2 in
                // Emit Swift first, then alphabetically.
                switch (language1, language2) {
                case (.swift, _): return true
                case (_, .swift): return false
                default: return language1.id < language2.id
                }
            })
            .map { sourceLanguage in
                RenderNode.Variant(
                    traits: [.interfaceLanguage(sourceLanguage.id)],
                    paths: [
                        generator.presentationURLForReference(identifier).path
                    ]
                )
            }
    }
    
    private mutating func convertFragments(_ fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> [DeclarationRenderSection.Token] {
        return fragments.map { token -> DeclarationRenderSection.Token in
            let reference: ResolvedTopicReference?
            if let preciseIdentifier = token.preciseIdentifier,
               let resolved = self.context.localOrExternalReference(symbolID: preciseIdentifier)
            {
                reference = resolved
                
                // Add relationship to render references
                self.collectedTopicReferences.append(resolved)
            } else {
                reference = nil
            }
            
            // Add the declaration token
            return DeclarationRenderSection.Token(fragment: token, identifier: reference?.absoluteString)
        }
    }
    
    /// Generate a RenderProperty object from markup content and symbol data.
    mutating func createRenderProperty(name: String, contents: [Markup], required: Bool, symbol: SymbolGraph.Symbol?) -> RenderProperty {
        let parameterContent = self.visitMarkupContainer(
            MarkupContainer(contents)
        ) as! [RenderBlockContent]
        
        var renderedTokens: [DeclarationRenderSection.Token]? = nil
        var attributes: [RenderAttribute] = []
        var isReadOnly: Bool? = nil
        var deprecated: Bool? = nil
        var introducedVersion: String? = nil 
        var typeDetails: [TypeDetails]? = nil
        
        if let symbol {
            // Convert the dictionary key's declaration into section tokens
            if let fragments = symbol.declarationFragments {
                renderedTokens = convertFragments(fragments)
            }
                
            // Populate attributes
            if let constraint = symbol.defaultValue {
                attributes.append(RenderAttribute.default(String(constraint)))
            }
            if let constraint = symbol.minimum {
                attributes.append(RenderAttribute.minimum(String(constraint)))
            }
            if let constraint = symbol.maximum {
                attributes.append(RenderAttribute.maximum(String(constraint)))
            }
            if let constraint = symbol.minimumExclusive {
                attributes.append(RenderAttribute.minimumExclusive(String(constraint)))
            }
            if let constraint = symbol.maximumExclusive {
                attributes.append(RenderAttribute.maximumExclusive(String(constraint)))
            }
            if let constraint = symbol.allowedValues {
                attributes.append(RenderAttribute.allowedValues(constraint.map{String($0)}))
            }
            if let constraint = symbol.isReadOnly {
                isReadOnly = constraint
            }
            if let constraint = symbol.minimumLength {
                attributes.append(RenderAttribute.minimumLength(String(constraint)))
            }
            if let constraint = symbol.maximumLength {
                attributes.append(RenderAttribute.maximumLength(String(constraint)))
            }
            if let constraint = symbol.typeDetails, constraint.count > 0 {
                // Pull out the base-type details.
                typeDetails = constraint.filter { $0.baseType != nil }
                                        .map { TypeDetails(baseType: $0.baseType, arrayMode: $0.arrayMode) }
                // Pull out the allowed-type declarations.
                // If there is only 1 type declaration found, it would be redundant with declaration, so skip it.
                let typeDeclarations = constraint.compactMap { $0.fragments }
                if typeDeclarations.count > 1 {
                    let allowedTypes = typeDeclarations.map { convertFragments($0) }
                    attributes.append(RenderAttribute.allowedTypes(allowedTypes))
                }
            }
            
            // Extract the availability information
            if let availabilityItems = symbol.availability, availabilityItems.count > 0 {
                availabilityItems.forEach { item in
                    if deprecated == nil && (item.isUnconditionallyDeprecated || item.deprecatedVersion != nil) {
                        deprecated = true
                    }
                    if let intro = item.introducedVersion, introducedVersion == nil {
                        introducedVersion = "\(intro)"
                    }
                }
            }
        }
        
        return RenderProperty(
            name: name,
            type: renderedTokens ?? [],
            typeDetails: typeDetails,
            content: parameterContent,
            attributes: attributes,
            mimeType: symbol?.httpMediaType,
            required: required,
            deprecated: deprecated,
            readOnly: isReadOnly,
            introducedVersion: introducedVersion
        )
    }
    
    init(
        context: DocumentationContext,
        bundle: DocumentationBundle,
        identifier: ResolvedTopicReference,
        renderContext: RenderContext? = nil,
        emitSymbolSourceFileURIs: Bool = false,
        emitSymbolAccessLevels: Bool = false,
        sourceRepository: SourceRepository? = nil,
        symbolIdentifiersWithExpandedDocumentation: [String]? = nil
    ) {
        self.context = context
        self.bundle = bundle
        self.identifier = identifier
        self.renderContext = renderContext
        self.contentRenderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
        self.shouldEmitSymbolSourceFileURIs = emitSymbolSourceFileURIs
        self.shouldEmitSymbolAccessLevels = emitSymbolAccessLevels
        self.sourceRepository = sourceRepository
        self.symbolIdentifiersWithExpandedDocumentation = symbolIdentifiersWithExpandedDocumentation
    }
}

fileprivate typealias BundleModuleIdentifier = String

extension BundleModuleIdentifier {
    fileprivate init(bundle: DocumentationBundle, moduleName: String) {
        self = "\(bundle.identifier):\(moduleName)"
    }
}

public protocol RenderTree {}
extension Array: RenderTree where Element: RenderTree {}
extension RenderBlockContent: RenderTree {}
extension RenderReferenceIdentifier: RenderTree {}
extension RenderNode: RenderTree {}
extension IntroRenderSection: RenderTree {}
extension VolumeRenderSection: RenderTree {}
extension VolumeRenderSection.Chapter: RenderTree {}
extension ContentAndMediaSection: RenderTree {}
extension ContentAndMediaGroupSection: RenderTree {}
extension CallToActionSection: RenderTree {}
extension TutorialSectionsRenderSection: RenderTree {}
extension TutorialSectionsRenderSection.Section: RenderTree {}
extension TutorialAssessmentsRenderSection: RenderTree {}
extension TutorialAssessmentsRenderSection.Assessment: RenderTree {}
extension TutorialAssessmentsRenderSection.Assessment.Choice: RenderTree {}
extension RenderInlineContent: RenderTree {}
extension RenderTile: RenderTree {}
extension ResourcesRenderSection: RenderTree {}
extension TutorialArticleSection: RenderTree {}
extension ContentLayout: RenderTree {}

extension ContentRenderSection: RenderTree {}

private extension Sequence<SourceLanguage> {
    func matchesOneOf(traits: Set<DocumentationDataVariantsTrait>) -> Bool {
        traits.contains(where: {
            guard let languageID = $0.interfaceLanguage,
                  let traitLanguage = SourceLanguage(knownLanguageIdentifier: languageID)
            else {
                return false
            }
            return self.contains(traitLanguage)
        })
    }
}
