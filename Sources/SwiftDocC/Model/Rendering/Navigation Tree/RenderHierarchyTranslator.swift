/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A hierarchy translator that converts a part of the topic graph into a hierarchy tree.
struct RenderHierarchyTranslator {
    var context: DocumentationContext
    var bundle: DocumentationBundle
    
    var collectedTopicReferences = Set<ResolvedTopicReference>()
    var linkReferences = [String: LinkReference]()
    
    /// Creates a new translator for the given bundle in the given context.
    /// - Parameters:
    ///   - context: The documentation context for the conversion.
    ///   - bundle: The documentation bundle for the conversion.
    init(context: DocumentationContext, bundle: DocumentationBundle) {
        self.context = context
        self.bundle = bundle
    }
    
    static let assessmentsAnchor = urlReadableFragment(TutorialAssessmentsRenderSection.title)
    let urlGenerator = NodeURLGenerator()
    
    /// Returns a complete hierarchy, starting at the given tutorials landing page and describing all
    /// contained volumes, chapters, and tutorials.
    /// - Parameters:
    ///   - reference: A reference to a tutorials-related topic.
    ///   - omittingChapters: If `true`, don't include chapters in the returned hierarchy.
    /// - Returns: A tuple of 1) a tutorials hierarchy and 2) the root reference of the tutorials hierarchy.
    mutating func visitTechnologyNode(_ reference: ResolvedTopicReference, omittingChapters: Bool = false) -> (hierarchy: RenderHierarchy, technology: ResolvedTopicReference)? {
        let paths = context.pathsTo(reference, options: [.preferTechnologyRoot])
        
        // If the node is a technology return immediately without generating breadcrumbs
        if let _ = (try? context.entity(with: reference))?.semantic as? Technology {
            let hierarchy = visitTechnology(reference, omittingChapters: omittingChapters)
            return (hierarchy: .tutorials(hierarchy), technology: reference)
        }
        
        guard let technologyPath = paths.mapFirst(where: { path -> [ResolvedTopicReference]? in
            guard let rootReference = path.first,
                let _ = try! context.entity(with: rootReference).semantic as? Technology else { return nil }
            return path
        }) else {
            // If there are no tutorials, return `nil`. We've already warned about uncurated tutorials.
            return nil
        }
        
        let technologyReference = technologyPath[0]
        var hierarchy = visitTechnology(technologyReference, omittingChapters: omittingChapters)
        
        hierarchy.paths = paths
            // Position the technology path as the canonical path for the node
            // in case it's curated multiple times under documentation symbols too.
            .sorted(by: { (lhs, rhs) -> Bool in
                return lhs == technologyPath
            })
            .map { $0.map { $0.absoluteString } }
        
        return (hierarchy: .tutorials(hierarchy), technology: technologyReference)
    }
    
    /// Returns the hierarchy under a given tutorials landing page.
    /// - Parameter technologyReference: The reference to the tutorials landing page.
    /// - Parameter omittingChapters: If `true`, don't include chapters in the returned hierarchy.
    /// - Returns: The hierarchy under the given landing page.
    mutating func visitTechnology(_ technologyReference: ResolvedTopicReference, omittingChapters: Bool = false) -> RenderTutorialsHierarchy {
        let technologyPath = urlGenerator.urlForReference(technologyReference, lowercased: true).path
        collectedTopicReferences.insert(technologyReference)
        // A technology is a root node in the bundle so passing empty breadcrumb paths
        var renderHierarchy = RenderTutorialsHierarchy(reference: RenderReferenceIdentifier(technologyReference.absoluteString), paths: [])

        if !omittingChapters {
            let children = context.children(of: technologyReference, kind: .volume)

            let renderChapters = children.compactMap { child in
                return visitVolume(child.reference, pathBreadcrumb: technologyPath)
            }.flatMap { $0 }

            renderHierarchy.modules = renderChapters
        }

        return renderHierarchy
    }
    
    /// Returns the hierarchy under a given tutorial series volume.
    /// - Parameter volumeReference: The reference to the volume.
    /// - Parameter pathBreadcrumb: The current path breadcrumb.
    /// - Returns: A list of hierarchy chapters contained in the volume, if any.
    mutating func visitVolume(_ volumeReference: ResolvedTopicReference, pathBreadcrumb: String) -> [RenderHierarchyChapter]? {
        let children = context.children(of: volumeReference, kind: .chapter)
        return children.compactMap { visitChapter($0.reference, pathBreadcrumb: pathBreadcrumb) }
    }
    
    /// Returns the hierarchy under a given chapter.
    /// - Parameter chapterReference: The reference to the chapter.
    /// - Parameter pathBreadcrumb: The current path breadcrumb.
    /// - Returns: The hierarchy under the given chapter.
    mutating func visitChapter(_ chapterReference: ResolvedTopicReference, pathBreadcrumb: String) -> RenderHierarchyChapter? {
        var renderHierarchyChapter = RenderHierarchyChapter(identifier: RenderReferenceIdentifier(chapterReference.absoluteString))
        collectedTopicReferences.insert(chapterReference)
        
        let children = context.children(of: chapterReference)
        
        renderHierarchyChapter.tutorials = children.compactMap { child in
            switch child.kind {
            case .tutorial:
                return visitTutorial(child.reference, pathBreadcrumb: pathBreadcrumb)
            case .tutorialArticle:
                return visitTutorialArticle(child.reference, pathBreadcrumb: pathBreadcrumb)
            default:
                fatalError("Unexpected child '\(child)' of chapter '\(chapterReference)', only tutorials and articles are expected.")
            }
            
        }
        return renderHierarchyChapter
    }
    
    /// Returns the hierarchy under a given tutorial article.
    /// - Parameter articleReference: The reference to the tutorial article.
    /// - Parameter pathBreadcrumb: The current path breadcrumb.
    /// - Returns: The hierarchy under the given tutorial article.
    mutating func visitTutorialArticle(_ articleReference: ResolvedTopicReference, pathBreadcrumb: String) -> RenderHierarchyTutorial? {
        let pathBreadcrumb = urlGenerator.urlForReference(articleReference, lowercased: true).path
        var renderHierarchyTutorial = RenderHierarchyTutorial(identifier: RenderReferenceIdentifier(articleReference.absoluteString))
        collectedTopicReferences.insert(articleReference)
        
        let children = context.children(of: articleReference, kind: .onPageLandmark)
    
        renderHierarchyTutorial.landmarks += children.compactMap { visitLandmark($0.reference, pathBreadcrumb: pathBreadcrumb) }
        
        return renderHierarchyTutorial
    }
    
    /// Returns the hierarchy under a given landmark.
    /// - Parameter landmarkReference: The reference to the landmark.
    /// - Parameter pathBreadcrumb: The current path breadcrumb.
    /// - Returns: The hierarchy under the given landmark.
    mutating func visitLandmark(_ landmarkReference: ResolvedTopicReference, pathBreadcrumb: String) -> RenderHierarchyLandmark {
        collectedTopicReferences.insert(landmarkReference)
        return RenderHierarchyLandmark(reference: RenderReferenceIdentifier(landmarkReference.absoluteString), kind: .heading)
    }
    
    /// Returns the hierarchy under a given tutorial.
    /// - Parameter tutorialReference: The reference to the tutorial.
    /// - Parameter pathBreadcrumb: The current path breadcrumb.
    /// - Returns: The hierarchy under the given tutorial.
    mutating func visitTutorial(_ tutorialReference: ResolvedTopicReference, pathBreadcrumb: String) -> RenderHierarchyTutorial? {
        let pathBreadcrumb = urlGenerator.urlForReference(tutorialReference, lowercased: true).path
        var renderHierarchyTutorial = RenderHierarchyTutorial(identifier: RenderReferenceIdentifier(tutorialReference.absoluteString))
        collectedTopicReferences.insert(tutorialReference)
        
        let children = context.children(of: tutorialReference, kind: .onPageLandmark)
        
        renderHierarchyTutorial.landmarks += children.compactMap { visitTutorialSection($0.reference, pathBreadcrumb: pathBreadcrumb) }
        
        if let tutorial = (try? context.entity(with: tutorialReference).semantic) as? Tutorial, let assessments = tutorial.assessments, !assessments.questions.isEmpty {
            // Add hardcoded assessment section.
            let assessmentReference = ResolvedTopicReference(bundleIdentifier: tutorialReference.bundleIdentifier, path: tutorialReference.path, fragment: RenderHierarchyTranslator.assessmentsAnchor, sourceLanguage: .swift)
            renderHierarchyTutorial.landmarks.append(RenderHierarchyLandmark(reference: RenderReferenceIdentifier(assessmentReference.absoluteString), kind: .assessment))
            
            let urlGenerator = PresentationURLGenerator(context: context, baseURL: bundle.baseURL)
            let assesmentLinkReference = LinkReference(
                identifier: RenderReferenceIdentifier(assessmentReference.absoluteString),
                title: "Check Your Understanding",
                url: urlGenerator.presentationURLForReference(assessmentReference).relativeString
            )
            linkReferences[assessmentReference.absoluteString] = assesmentLinkReference
        }

        return renderHierarchyTutorial
    }

    /// Returns the hierarchy under a given tutorial section.
    /// - Parameter tutorialSectionReference: The reference to the tutorial section.
    /// - Parameter pathBreadcrumb: The current path breadcrumb.
    /// - Returns: The hierarchy under the given tutorial section.
    mutating func visitTutorialSection(_ tutorialSectionReference: ResolvedTopicReference, pathBreadcrumb: String) -> RenderHierarchyLandmark {
        collectedTopicReferences.insert(tutorialSectionReference)
        return RenderHierarchyLandmark(reference: RenderReferenceIdentifier(tutorialSectionReference.absoluteString), kind: .task)
    }

    /// Returns the hierarchy under a given API symbol.
    /// - Parameter symbolReference: The reference to the API symbol.
    /// - Returns: The framework hierarchy that describes all paths where the symbol is curated.
    ///
    /// The documentation model is a graph (and not a tree) so you can curate API symbols
    /// multiple times under other API symbols, articles, or API collections. This method
    /// returns all the paths (breadcrumbs) between the framework landing page and the given symbol.
    mutating func visitSymbol(_ symbolReference: ResolvedTopicReference) -> RenderHierarchy {
        let pathReferences = context.pathsTo(symbolReference)
        pathReferences.forEach({
            collectedTopicReferences.formUnion($0)
        })
        let paths = pathReferences.map { $0.map { $0.absoluteString } }
        return .reference(RenderReferenceHierarchy(paths: paths))
    }
    
    /// Returns the hierarchy under a given article.
    /// - Parameter symbolReference: The reference to the article.
    /// - Returns: The framework hierarchy that describes all paths where the article is curated.
    mutating func visitArticle(_ symbolReference: ResolvedTopicReference) -> RenderHierarchy {
        return visitSymbol(symbolReference)
    }
}
