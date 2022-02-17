/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A tutorial to complete in order to gain knowledge of a ``Technology``.
 */
public final class Tutorial: Semantic, DirectiveConvertible, Abstracted, Titled, Timed, Redirected {
    public static let directiveName = "Tutorial"
    public let originalMarkup: BlockDirective
    
    /// The estimated time in minutes that the containing ``Tutorial`` will take.
    public let durationMinutes: Int?
    
    /// Project files to download to get started with the ``Tutorial``.
    public let projectFiles: ResourceReference?
    
    /// Informal requirements to complete the ``Tutorial``.
    public let requirements: [XcodeRequirement]
    
    /// The Intro section, representing a slide that introduces the tutorial.
    public let intro: Intro

    /// All of the sections to complete to finish the tutorial.
    public let sections: [TutorialSection]
    
    /// The linkable parts of the tutorial.
    ///
    /// Allows you to direct link to discrete sections within a tutorial.
    public var landmarks: [Landmark] {
        return sections
    }
    
    /// A section containing various questions to test the reader's knowledge.
    public let assessments: Assessments?
    
    /// An image for the final call to action, which directs the reader to the starting point to learn about this category.
    public let callToActionImage: ImageMedia?
    
    public var abstract: Paragraph? {
        return intro.content.first as? Paragraph
    }
    
    public var title: String? {
        return intro.title
    }
    
    override var children: [Semantic] {
        return [intro] +
            requirements as [Semantic] +
            sections as [Semantic] +
            (assessments.map({ [$0] }) ?? [])
    }
    
    enum Semantics {
        enum Time: DirectiveArgument {
            typealias ArgumentValue = Int
            static let argumentName = "time"
        }
        enum ProjectFiles: DirectiveArgument {
            static let argumentName = "projectFiles"
        }
    }
    
    public let redirects: [Redirect]?
    
    init(originalMarkup: BlockDirective, durationMinutes: Int?, projectFiles: ResourceReference?, requirements: [XcodeRequirement], intro: Intro, sections: [TutorialSection], assessments: Assessments?, callToActionImage: ImageMedia?, redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.durationMinutes = durationMinutes
        self.projectFiles = projectFiles
        self.requirements = requirements
        self.intro = intro
        self.sections = sections
        self.assessments = assessments
        self.callToActionImage = callToActionImage
        self.redirects = redirects
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Tutorial.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Tutorial>(severityIfFound: .warning, allowedArguments: [Semantics.Time.argumentName, Semantics.ProjectFiles.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Tutorial>(severityIfFound: .warning, allowedDirectives: [Intro.directiveName, TutorialSection.directiveName, Assessments.directiveName, XcodeRequirement.directiveName, ImageMedia.directiveName, Redirect.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalTime = Semantic.Analyses.HasArgument<Tutorial, Semantics.Time>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems)
        let optionalProjectFiles = arguments[Semantics.ProjectFiles.argumentName].map { argument in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argument.value)
        }
        
        var remainder: MarkupContainer
        let requiredIntro: Intro?
        (requiredIntro, remainder) = Semantic.Analyses.HasExactlyOne<Tutorial, Intro>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let sections: [TutorialSection]
        (sections, remainder) = Semantic.Analyses.HasAtLeastOne<Tutorial, TutorialSection>(severityIfNotFound: .warning).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        var seenSectionTitles = [String: SourceRange]()
        let sectionsWithoutDuplicates = sections.filter { section -> Bool in
            let arguments = section.originalMarkup.arguments()
            let thisTitleRange = arguments[TutorialSection.Semantics.Title.argumentName]?.valueRange
            if let previousRange = seenSectionTitles[section.title] {
                var diagnostic = Diagnostic(source: source, severity: .warning, range: thisTitleRange, identifier: "org.swift.docc.\(Tutorial.self).DuplicateSectionTitle", summary: "Duplicate title in \(TutorialSection.directiveName.singleQuoted) directive", explanation: "\(TutorialSection.directiveName.singleQuoted) directives are identified and linked using their titles and so must be unique within a \(Tutorial.directiveName.singleQuoted) directive; this directive will be dropped")
                if let source = source {
                    diagnostic.notes.append(DiagnosticNote(source: source, range: previousRange, message: "First \(TutorialSection.directiveName.singleQuoted) directive with the title '\(section.title)' written here"))
                }
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                return false
            }
            seenSectionTitles[section.title] = thisTitleRange
            return true
        }
        
        let optionalAssessments: Assessments?
        (optionalAssessments, remainder) = Semantic.Analyses.HasExactlyOne<Tutorial, Assessments>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let requirement: XcodeRequirement?
        (requirement, remainder) = Semantic.Analyses.HasAtMostOne<Tutorial, XcodeRequirement>().analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalCallToActionImage: ImageMedia?
        (optionalCallToActionImage, remainder) = Semantic.Analyses.HasExactlyOne<Technology, ImageMedia>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)

        let redirects: [Redirect]
            (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        guard let intro = requiredIntro else {
            return nil
        }
        let requirements = requirement.map { [$0] } ?? []
        
        self.init(originalMarkup: directive, durationMinutes: optionalTime, projectFiles: optionalProjectFiles, requirements: requirements, intro: intro, sections: sectionsWithoutDuplicates, assessments: optionalAssessments, callToActionImage: optionalCallToActionImage, redirects: redirects.isEmpty ? nil : redirects)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTutorial(self)
    }
}

extension Tutorial {
    static func analyze(_ node: TopicGraph.Node, completedContext context: DocumentationContext, engine: DiagnosticEngine) {
        let url = context.documentURL(for: node.reference)

        if let project = try? context.entity(with: node.reference).semantic as? Tutorial, let projectFiles = project.projectFiles {
            if context.resolveAsset(named: projectFiles.url.lastPathComponent, in: node.reference) == nil {
                // The project download file is not found.
                engine.emit(.init(
                    diagnostic: Diagnostic(source: url, severity: .warning, range: nil, identifier: "org.swift.docc.Project.ProjectFilesNotFound", 
                        summary: "\(projectFiles.path) file reference not found in \(Tutorial.directiveName.singleQuoted) directive"), 
                    possibleSolutions: [
                        Solution(summary: "Copy the referenced file into the documentation bundle directory", replacements: [])
                    ]
                ))
            }
        }
        
        let technologyParent = context.parents(of: node.reference)
            .compactMap({ context.topicGraph.nodeWithReference($0) })
            .first(where: { $0.kind == .technology || $0.kind == .chapter || $0.kind == .volume })
        guard technologyParent != nil else {
            engine.emit(.init(
                diagnostic: Diagnostic(source: url, severity: .warning, range: nil, identifier: "org.swift.docc.Unreferenced\(Tutorial.self)", summary: "The tutorial \(node.reference.path.components(separatedBy: "/").last!.singleQuoted) must be referenced from a Tutorial Table of Contents"),
                possibleSolutions: [
                    Solution(summary: "Use a \(TutorialReference.directiveName.singleQuoted) directive inside \(Technology.directiveName.singleQuoted) to reference the tutorial.", replacements: [])
                ]
            ))
            return
        }
    }
}
