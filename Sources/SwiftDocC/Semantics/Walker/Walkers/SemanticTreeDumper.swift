/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 A ``SemanticWalker`` that dumps a textual representation of a ``Semantic`` tree for debugging.
 
 - Note: This type is utilized by a public ``Semantic.dump()`` method available on all semantic nodes.
 */
struct SemanticTreeDumper: SemanticWalker {
    /// The resulting string built up during dumping.
    var result = ""
    
    /// The current path in the tree so far, used for printing edges
    /// in the dumped tree.
    private var path = [Semantic]()
    
    private mutating func dump(_ semantic: Semantic, customDescription: String? = nil) {
        if !path.isEmpty {
            result += "\n"
        }
        path.append(semantic)
        result += indentationPrefix
        result += "\(type(of: semantic))"
        if let directiveConvertible = semantic as? DirectiveConvertible,
            let range = directiveConvertible.originalMarkup.range {
            let start = range.lowerBound
            let end = range.upperBound
            result += " @\(start.line):\(start.column)-\(end.line):\(end.column)"
        }
        if let customDescription = customDescription {
            result += " \(customDescription)"
        }
        increasingDepth(semantic)
    }
    
    private var indentation: String {
        return String(repeating: " ", count: path.count * 3)
    }
    
    private func parentOfNode(at index: Int) -> Semantic? {
        let parentIndex = index - 1
        guard parentIndex >= 0, path.indices.contains(parentIndex) else {
            return nil
        }
        return path[parentIndex]
    }
    
    /**
     Add an indentation prefix for a semantic node using the current ``path``.
     - parameter semantic: The ``Semantic`` node about to be printed
     */
    private var indentationPrefix: String {
        var prefix = ""
        var suffix = ""
        for (depth, node) in path.enumerated().reversed() {
            guard let parent = parentOfNode(at: depth) else {
                continue
            }
            if let lastChild = parent.children.last, lastChild == node, depth == path.count - 1 {
                suffix.append("└─ ")
            } else if let leaf = path.last, leaf == node {
                suffix.append("├─ ")
            } else if let lastChild = parent.children.last, lastChild != node {
                prefix.append("  │")
            } else {
                prefix.append("   ")
            }
        }
        return prefix.reversed() + suffix
    }
    
    /**
     Push `node` to the current path and descend into the children, popping `node` from the path when returning.
     
     - parameter node: The parent node you're descending into.
     */
    private mutating func increasingDepth(_ node: Semantic) {
        descendIntoChildren(of: node)
        path.removeLast()
    }
    
    mutating func visitCode(_ code: Code) {
        dump(code, customDescription: "fileReference: \(code.fileReference) fileName: '\(code.fileName)' shouldResetDiff: \(code.shouldResetDiff) preview: \(String(describing: code.preview))")
    }
    
    mutating func visitSteps(_ steps: Steps) {
        dump(steps)
    }
    
    mutating func visitStep(_ step: Step) {
        dump(step)
    }
    
    mutating func visitTutorialSection(_ tutorialSection: TutorialSection) {
        dump(tutorialSection)
    }
    
    mutating func visitTutorial(_ tutorial: Tutorial) {
        let projectFiles = tutorial.projectFiles.map { $0.path } ?? "nil"
        dump(tutorial, customDescription: "projectFiles: \(projectFiles)")
    }
    
    mutating func visitIntro(_ intro: Intro) {
        dump(intro, customDescription: "title: '\(intro.title)'")
    }
    
    mutating func visitXcodeRequirement(_ requirement: XcodeRequirement) {
        let description = "title: \(requirement.title.singleQuoted) destination: \(requirement.destination.absoluteString.singleQuoted)"
        dump(requirement, customDescription: description)
    }
    
    mutating func visitAssessments(_ assessments: Assessments) {
        dump(assessments)
    }
    
    mutating func visitMultipleChoice(_ multipleChoice: MultipleChoice) {
        dump(multipleChoice, customDescription: "title: '\(multipleChoice.questionPhrasing)'")
    }
    
    mutating func visitJustification(_ justification: Justification) {
        if let reaction = justification.reaction {
            dump(justification, customDescription: "reaction: '\(reaction)'")
        } else {
            dump(justification)
        }
    }
    
    mutating func visitChoice(_ choice: Choice) {
        dump(choice, customDescription: "isCorrect: \(choice.isCorrect)")
    }
    mutating func visitMarkupContainer(_ markupContainer: MarkupContainer) {
        let description: String
        switch markupContainer.elements.count {
        case 0:
            description = "(empty)"
        case 1:
            description = "(1 element)"
        default:
            description = "(\(markupContainer.elements.count) elements)"
        }
        dump(markupContainer, customDescription: description)
    }
        
    mutating func visitTechnology(_ technology: Technology) {
        dump(technology, customDescription: "name: '\(technology.name)'")
    }
    
    mutating func visitContentAndMedia(_ contentAndMedia: ContentAndMedia) -> () {
        dump(contentAndMedia, customDescription: "mediaPosition: '\(contentAndMedia.mediaPosition.rawValue)'")
    }
    
    mutating func visitVolume(_ volume: Volume) -> () {
        dump(volume, customDescription: volume.name.map { "name: '\($0)'" })
    }
    
    mutating func visitChapter(_ chapter: Chapter) -> () {
        dump(chapter, customDescription: "name: '\(chapter.name)'")
    }
    
    mutating func visitImageMedia(_ imageMedia: ImageMedia) -> () {
        dump(imageMedia, customDescription: "source: '\(imageMedia.source)' altText: \(imageMedia.altText.map { "'\($0)'" } ?? "nil")")
    }
    
    mutating func visitVideoMedia(_ videoMedia: VideoMedia) -> () {
        dump(videoMedia, customDescription: "source: '\(videoMedia.source)' poster: '\(String(describing: videoMedia.poster))'")
    }
    
    mutating func visitTutorialReference(_ tutorialReference: TutorialReference) -> () {
        dump(tutorialReference, customDescription: "tutorial: '\(tutorialReference.topic)'")
    }

    mutating func visitResources(_ resources: Resources) {
        dump(resources)
    }
    
    mutating func visitTile(_ tile: Tile) {
        let description = "identifier: \(tile.identifier) title: \(tile.title.singleQuoted) destination: \(tile.destination?.absoluteString.singleQuoted ?? "nil")"
        dump(tile, customDescription: description)
    }
    
    mutating func visitTutorialArticle(_ article: TutorialArticle) {
        var descriptionComponents: [String] = []
        if let title = article.intro?.title {
            descriptionComponents.append("title: '\(title)'")
        }
        if let time = article.durationMinutes {
            descriptionComponents.append("time: '\(time)'")
        }
        
        if !descriptionComponents.isEmpty {
            dump(article, customDescription: descriptionComponents.joined(separator: " "))
        } else {
            dump(article)
        }
    }
    
    mutating func visitArticle(_ article: Article) {
        dump(article)
    }
    
    mutating func visitStack(_ stack: Stack) {
        dump(stack)
    }

    mutating func visitSymbol(_ symbol: Symbol) {
        dump(symbol)
    }
    
    mutating func visitDeprecationSummary(_ summary: DeprecationSummary) {
        dump(summary)
    }
}
